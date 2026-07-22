#include "StatusQ/chatinputhighlighter.h"

#include "StatusQ/markdownparser.h"
#include "StatusQ/mentiontextobject.h"

#include <QAbstractTextDocumentLayout>
#include <QClipboard>
#include <QColor>
#include <QDataStream>
#include <QFile>
#include <QFontDatabase>
#include <QFontMetricsF>
#include <QGuiApplication>
#include <QMimeData>
#include <QTextBlock>
#include <QTextBlockFormat>
#include <QTextBoundaryFinder>
#include <QTextCharFormat>
#include <QTextCursor>
#include <QTextImageFormat>
#include <QUrl>
#include <QVariantMap>
#include <QVector>

#include <algorithm>

namespace {

// Final render bits stamped per character and consumed by buildFormat().
constexpr unsigned int kBold          = 1u << 0;
constexpr unsigned int kItalic        = 1u << 1;
constexpr unsigned int kStrikeThrough = 1u << 2;
constexpr unsigned int kDelimiter     = 1u << 3; // emphasis/fence markers: dark gray
constexpr unsigned int kCode          = 1u << 4; // single-backtick: monospace + background
constexpr unsigned int kCodeFence     = 1u << 5; // triple-backtick content: monospace
constexpr unsigned int kLink          = 1u << 6; // URL: blue foreground
constexpr unsigned int kQuote         = 1u << 7; // block-quote line: default text color

// Emphasis bits that an outer span propagates into nested code/quote content.
constexpr unsigned int kEmphasisMask  = kBold | kItalic | kStrikeThrough;

// Clipboard MIME carrying the internal, mention-preserving representation of a selection.
constexpr char kChatInputMimeType[] = "application/x-status-chat-input";

using Markdown::Node;
using Markdown::NodeKind;

Markdown::Options optionsFor(bool unclosedFence)
{
    Markdown::Options o;
    o.formatUnclosedCodeFence = unclosedFence;
    o.detectLinks = true;
    return o;
}

// ── image-based emoji helpers ────────────────────────────────────────────────

// Custom char-format property holding an emoji image object's original Unicode text, used to
// recover the real emoji for extraction/copy and to toggle back to font rendering. Well clear
// of the mention properties (UserProperty + 1..3).
constexpr int kEmojiUnicodeProperty = QTextFormat::UserProperty + 20;
// A unique id per inserted emoji image. Qt merges adjacent fragments with identical char formats;
// without a distinct id, two identical emoji next to each other collapse into one fragment and only
// the first image is painted. (Same trick as MentionTextObject::UniqueIdProperty.)
constexpr int kEmojiUniqueIdProperty = QTextFormat::UserProperty + 21;

// True when `fmt` is one of our inline emoji image objects.
bool isEmojiImage(const QTextCharFormat& fmt)
{
    return fmt.isImageFormat() && fmt.hasProperty(kEmojiUnicodeProperty);
}

// Reads the code point at `i` (advancing `units` over a surrogate pair).
char32_t codePointAt(const QString& s, qsizetype i, qsizetype& units)
{
    const QChar c = s[i];
    if (c.isHighSurrogate() && i + 1 < s.size() && s[i + 1].isLowSurrogate()) {
        units = 2;
        return QChar::surrogateToUcs4(c, s[i + 1]);
    }
    units = 1;
    return c.unicode();
}

// Local path a url resolves to for an existence check, covering the two StatusQ deployments:
// filesystem (file://) and bundled resources (qrc:/).
QString localPathForUrl(const QString& url)
{
    const QUrl u(url);
    if (u.scheme() == QLatin1String("qrc"))
        return QLatin1Char(':') + u.path();
    if (u.isLocalFile())
        return u.toLocalFile();
    return url;
}

// Maps a single emoji (one grapheme cluster) to its bundled Twemoji SVG url under `base`, following
// twemoji.js' grabTheRightIcon/toCodePoint rule: keep all code points if the run contains U+200D
// (ZWJ), otherwise strip U+FE0F; join code points as lowercase hex with '-'. Returns "" when no
// svg exists for it (graceful fallback: the emoji stays as text / font rendering).
QString twemojiSvgUrl(const QString& base, const QString& emoji)
{
    if (base.isEmpty())
        return {};

    const bool hasZwj = emoji.contains(QChar(0x200D));
    QString name;
    for (qsizetype i = 0; i < emoji.size();) {
        qsizetype units = 1;
        const char32_t cp = codePointAt(emoji, i, units);
        i += units;
        if (!hasZwj && cp == 0xFE0F)
            continue;
        if (!name.isEmpty())
            name += QLatin1Char('-');
        name += QString::number(cp, 16);
    }
    if (name.isEmpty())
        return {};
    const QString url = base + name + QStringLiteral(".svg");
    if (!QFile::exists(localPathForUrl(url)))
        return {};
    return url;
}

// True if the block text at [i, ...) starts an emoji code point (never matches the U+FFFC of an
// existing image/mention object, so conversion is idempotent).
bool startsEmoji(const QString& s, qsizetype i, qsizetype& units)
{
    return Markdown::isEmojiCodePoint(codePointAt(s, i, units));
}

// Inline image format for one emoji: the Twemoji svg sized to the line height, carrying the original
// Unicode for extraction/copy and a unique id so adjacent identical emoji stay separate fragments.
QTextImageFormat emojiImageFormat(const QString& emoji, const QString& url, int lineHeight,
                                  int uniqueId)
{
    QTextImageFormat fmt;
    fmt.setName(url);
    fmt.setWidth(lineHeight);
    fmt.setHeight(lineHeight);
    fmt.setVerticalAlignment(QTextCharFormat::AlignBottom);
    fmt.setProperty(kEmojiUnicodeProperty, emoji);
    fmt.setProperty(kEmojiUniqueIdProperty, uniqueId);
    return fmt;
}

// A textual mention detected in a parsed string: [start,end) over "@0x…" and its pub key.
struct TextMentionSpan { int start; int end; QString pubKey; };

void collectMentionSpans(const Node& n, QVector<TextMentionSpan>& out)
{
    if (n.kind == NodeKind::Mention && !n.destination.isEmpty())
        out.append({int(n.start), int(n.end), n.destination});
    for (const Node& c : n.children)
        collectMentionSpans(c, out);
}

// Content range of a container node = the span between its opener/closer
// delimiter children (or the full node range when a delimiter is absent).
QPair<qsizetype, qsizetype> contentRange(const Node& node)
{
    qsizetype s = node.start;
    qsizetype e = node.end;
    if (!node.children.isEmpty() && node.children.first().kind == NodeKind::Delimiter)
        s = node.children.first().end;
    if (!node.children.isEmpty() && node.children.last().kind == NodeKind::Delimiter)
        e = node.children.last().start;
    return {s, e};
}

// ── AST → per-character render bits ─────────────────────────────────────────────

void stamp(QVector<unsigned int>& flags, qsizetype s, qsizetype e, unsigned int bits)
{
    const qsizetype lo = qMax(qsizetype(0), s);
    const qsizetype hi = qMin(qsizetype(flags.size()), e);
    for (qsizetype k = lo; k < hi; ++k)
        flags[k] = bits;
}

void flatten(const Node& node, unsigned int acc, QVector<unsigned int>& flags)
{
    switch (node.kind) {
    case NodeKind::Document:
    case NodeKind::Paragraph:
        for (const Node& c : node.children)
            flatten(c, acc, flags);
        break;
    case NodeKind::QuoteBlock:
        stamp(flags, node.start, node.end, kQuote);
        for (const Node& c : node.children)
            flatten(c, acc | kQuote, flags);
        break;
    case NodeKind::Strong:
        for (const Node& c : node.children)
            flatten(c, acc | kBold, flags);
        break;
    case NodeKind::Emphasis:
        for (const Node& c : node.children)
            flatten(c, acc | kItalic, flags);
        break;
    case NodeKind::Strikethrough:
        for (const Node& c : node.children)
            flatten(c, acc | kStrikeThrough, flags);
        break;
    case NodeKind::Link:
    case NodeKind::WalletLink:
        // Wallet addresses / ENS names are colored like URL links in the composer.
        for (const Node& c : node.children)
            flatten(c, acc | kLink, flags);
        break;
    case NodeKind::CodeSpan:
        // Markers and content are monospace + background (kCode). The content inherits
        // any outer emphasis (nested code can be bold/italic/struck through); both markers
        // and content inherit kQuote so nested code inside a quote is dimmed too.
        for (const Node& c : node.children)
            stamp(flags, c.start, c.end,
                  c.kind == NodeKind::Delimiter
                      ? kCode | (acc & kQuote)
                      : kCode | (acc & (kEmphasisMask | kQuote)));
        break;
    case NodeKind::CodeBlock:
        // Fence markers stay kDelimiter (already delimiter-colored); the content inherits
        // outer emphasis and kQuote (dimmed inside a quote).
        for (const Node& c : node.children)
            stamp(flags, c.start, c.end,
                  c.kind == NodeKind::Delimiter
                      ? kDelimiter
                      : kCodeFence | (acc & (kEmphasisMask | kQuote)));
        break;
    case NodeKind::Text:
        stamp(flags, node.start, node.end, acc);
        break;
    case NodeKind::Delimiter:
        stamp(flags, node.start, node.end, kDelimiter);
        break;
    case NodeKind::Mention:
        // The object char is never given a char format (the pill is a QML overlay);
        // the per-block setFormat loop additionally skips its position.
        break;
    }
}

// Collects document positions of mentions (Mention leaves) that fall inside a code
// span/block; those should be demoted to plain text.
void collectMentionsInCode(const Node& node, bool inCode, QVector<int>& out)
{
    const bool childInCode = inCode
            || node.kind == NodeKind::CodeSpan
            || node.kind == NodeKind::CodeBlock;
    if (node.kind == NodeKind::Mention && inCode)
        out.append(static_cast<int>(node.start));
    for (const Node& c : node.children)
        collectMentionsInCode(c, childInCode, out);
}

// Scans the document's fragments for mention objects and refreshes the model
// (one row per mention position, carrying name/pubKey from the char format).
void refreshMentions(QTextDocument* doc, ChatInputMentionsModel* model)
{
    QVector<ChatInputMentionsModel::MentionItem> items;
    for (QTextBlock b = doc->begin(); b != doc->end(); b = b.next()) {
        for (auto it = b.begin(); !it.atEnd(); ++it) {
            const QTextFragment frag = it.fragment();
            if (!frag.isValid())
                continue;
            const QTextCharFormat fmt = frag.charFormat();
            if (fmt.objectType() != MentionTextObject::MentionType)
                continue;
            const QString name   = fmt.property(MentionTextObject::NameProperty).toString();
            const QString pubKey = fmt.property(MentionTextObject::PubKeyProperty).toString();
            for (int k = 0; k < frag.length(); ++k)
                items.append({static_cast<int>(frag.position()) + k, name, pubKey});
        }
    }
    model->setMentions(items);
}

// Re-stamps every quote group's "> " prefixes back to kQuote, so an outer
// emphasis span that straddles a prefix doesn't render it gray/bold.
void reProtectQuotePrefixes(const QString& text, const Node& node,
                            QVector<unsigned int>& flags)
{
    if (node.kind == NodeKind::QuoteBlock) {
        qsizetype i = node.start;
        while (i < node.end) {
            stamp(flags, i, i + 2, kQuote);
            while (i < node.end && text[i] != QLatin1Char('\n')) ++i;
            if (i < node.end) ++i;
        }
    }
    for (const Node& c : node.children)
        reProtectQuotePrefixes(text, c, flags);
}

void collectLinks(const Node& node, QVector<ChatInputLinksModel::LinkItem>& out)
{
    if (node.kind == NodeKind::Link)
        out.append({static_cast<int>(node.start),
                    static_cast<int>(node.end - node.start), node.destination});
    for (const Node& c : node.children)
        collectLinks(c, out);
}

// Document positions of each quote line's block start (plain-text offsets ==
// document positions). Used to apply per-block hanging indents.
QSet<int> collectQuoteLineStarts(const Node& node, const QString& text)
{
    QSet<int> out;
    if (node.kind == NodeKind::QuoteBlock) {
        qsizetype p = node.start;
        while (p < node.end) {
            out.insert(static_cast<int>(p));
            const qsizetype nl = text.indexOf(QLatin1Char('\n'), p);
            if (nl < 0 || nl >= node.end)
                break;
            p = nl + 1;
        }
    }
    for (const Node& c : node.children)
        out.unite(collectQuoteLineStarts(c, text));
    return out;
}

// ── AST queries backing the Q_INVOKABLE test API ────────────────────────────────

void collectFormats(const Node& node, QVariantList& out)
{
    if (node.kind == NodeKind::Strong || node.kind == NodeKind::Emphasis
            || node.kind == NodeKind::Strikethrough) {
        const auto cr = contentRange(node);
        QVariantMap m;
        m[QStringLiteral("start")]         = cr.first;
        m[QStringLiteral("end")]           = cr.second;
        m[QStringLiteral("bold")]          = node.kind == NodeKind::Strong;
        m[QStringLiteral("italic")]        = node.kind == NodeKind::Emphasis;
        m[QStringLiteral("strikethrough")] = node.kind == NodeKind::Strikethrough;
        out.append(m);
    }
    for (const Node& c : node.children)
        collectFormats(c, out);
}

void collectDelimiters(const Node& node, QVariantList& out)
{
    const bool emphasisOrCode =
            node.kind == NodeKind::Strong || node.kind == NodeKind::Emphasis
            || node.kind == NodeKind::Strikethrough || node.kind == NodeKind::CodeSpan
            || node.kind == NodeKind::CodeBlock;
    if (emphasisOrCode) {
        for (const Node& c : node.children) {
            if (c.kind != NodeKind::Delimiter)
                continue;
            QVariantMap m;
            m[QStringLiteral("start")] = c.start;
            m[QStringLiteral("end")]   = c.end;
            out.append(m);
        }
    }
    for (const Node& c : node.children)
        collectDelimiters(c, out);
}

void collectCodeSpans(const Node& node, QVariantList& out)
{
    if (node.kind == NodeKind::CodeSpan || node.kind == NodeKind::CodeBlock) {
        const auto cr = contentRange(node);
        QVariantMap m;
        m[QStringLiteral("start")] = cr.first;
        m[QStringLiteral("end")]   = cr.second;
        out.append(m);
    }
    for (const Node& c : node.children)
        collectCodeSpans(c, out);
}

// True when `position` falls inside a code span or code block. Descends only into the
// child whose [start, end) contains the position; code nodes are opaque (once inside one
// the answer is yes, no need to look deeper).
bool positionInCode(const Node& node, int position)
{
    if ((node.kind == NodeKind::CodeSpan || node.kind == NodeKind::CodeBlock)
            && position >= node.start && position < node.end)
        return true;

    for (const Node& c : node.children)
        if (position >= c.start && position < c.end)
            return positionInCode(c, position);
    return false;
}

void collectLinkInfo(const Node& node, QVariantList& out)
{
    if (node.kind == NodeKind::Link) {
        QVariantMap m;
        m[QStringLiteral("text")]   = node.destination;
        m[QStringLiteral("start")]  = node.start;
        m[QStringLiteral("length")] = node.end - node.start;
        out.append(m);
    }
    for (const Node& c : node.children)
        collectLinkInfo(c, out);
}

void collectQuoteBlocks(const Node& node, QVariantList& out)
{
    if (node.kind == NodeKind::QuoteBlock) {
        QVariantMap m;
        m[QStringLiteral("start")] = node.start;
        m[QStringLiteral("end")]   = node.end;
        out.append(m);
    }
    for (const Node& c : node.children)
        collectQuoteBlocks(c, out);
}

unsigned int emphasisBitsAt(const Node& node, qsizetype pos)
{
    unsigned int bits = 0u;
    if (node.kind == NodeKind::Strong || node.kind == NodeKind::Emphasis
            || node.kind == NodeKind::Strikethrough) {
        const auto cr = contentRange(node);
        if (pos >= cr.first && pos < cr.second) {
            if (node.kind == NodeKind::Strong)        bits |= kBold;
            else if (node.kind == NodeKind::Emphasis) bits |= kItalic;
            else                                      bits |= kStrikeThrough;
        }
    }
    for (const Node& c : node.children)
        bits |= emphasisBitsAt(c, pos);
    return bits;
}

// Marks, in `out`, every formatting kind whose full range (delimiters included) strictly contains
// `pos` (node.start < pos < node.end). Full recursion is safe: a child's range is a subrange of its
// parent's, so a caret outside a node can't be strictly inside any of its children.
void collectNodesAt(const Node& node, qsizetype pos, QVariantMap& out)
{
    if (pos > node.start && pos < node.end) {
        switch (node.kind) {
        case NodeKind::Strong:        out[QStringLiteral("bold")]          = true; break;
        case NodeKind::Emphasis:      out[QStringLiteral("italic")]        = true; break;
        case NodeKind::Strikethrough: out[QStringLiteral("strikethrough")] = true; break;
        case NodeKind::QuoteBlock:    out[QStringLiteral("quote")]         = true; break;
        case NodeKind::CodeSpan:      out[QStringLiteral("codeSpan")]      = true; break;
        case NodeKind::CodeBlock:     out[QStringLiteral("codeBlock")]     = true; break;
        default: break;
        }
    }
    for (const Node& c : node.children)
        collectNodesAt(c, pos, out);
}

// Maps a removeFormatting() kind string to the AST node kinds it targets. "code" matches both a
// code span and a code block. Returns an empty set for an unknown kind.
QVector<NodeKind> nodeKindsForFormatting(const QString& kind)
{
    if (kind == QLatin1String("bold"))          return {NodeKind::Strong};
    if (kind == QLatin1String("italic"))        return {NodeKind::Emphasis};
    if (kind == QLatin1String("strikethrough")) return {NodeKind::Strikethrough};
    if (kind == QLatin1String("quote"))         return {NodeKind::QuoteBlock};
    if (kind == QLatin1String("code"))          return {NodeKind::CodeSpan, NodeKind::CodeBlock};
    return {};
}

// Returns the innermost node whose kind is in `kinds` and whose full range strictly contains `pos`
// (start < pos < end), or nullptr. Recurses into children first so the deepest match wins.
const Node* findDeepestNode(const Node& node, qsizetype pos, const QVector<NodeKind>& kinds)
{
    for (const Node& c : node.children) {
        if (const Node* hit = findDeepestNode(c, pos, kinds))
            return hit;
    }
    if (pos > node.start && pos < node.end && kinds.contains(node.kind))
        return &node;
    return nullptr;
}

// Appends the ranges of every "> " quote-prefix Delimiter in the subtree. Emphasis spanning several
// quote lines nests the later prefixes under an inline node, so they must be gathered recursively —
// not just from the QuoteBlock's direct children. Prefixes are the only delimiters starting with '>'.
void collectQuotePrefixes(const Node& node, QVector<QPair<qsizetype, qsizetype>>& out)
{
    if (node.kind == NodeKind::Delimiter && node.literal.startsWith(QLatin1Char('>')))
        out.append({node.start, node.end});
    for (const Node& c : node.children)
        collectQuotePrefixes(c, out);
}

} // namespace

// ── ChatInputLinksModel ───────────────────────────────────────────────────────

ChatInputLinksModel::ChatInputLinksModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int ChatInputLinksModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return static_cast<int>(m_links.size());
}

QVariant ChatInputLinksModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(m_links.size()))
        return {};
    const LinkItem& item = m_links[index.row()];
    switch (role) {
    case TextRole:   return item.text;
    case StartRole:  return item.start;
    case LengthRole: return item.length;
    }
    return {};
}

QHash<int, QByteArray> ChatInputLinksModel::roleNames() const
{
    return {
        {TextRole,   "text"},
        {StartRole,  "start"},
        {LengthRole, "length"},
    };
}

void ChatInputLinksModel::setLinks(const QVector<LinkItem>& links)
{
    beginResetModel();
    m_links = links;
    endResetModel();
}

// ── ChatInputMentionsModel ────────────────────────────────────────────────────

ChatInputMentionsModel::ChatInputMentionsModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int ChatInputMentionsModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return static_cast<int>(m_mentions.size());
}

QVariant ChatInputMentionsModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(m_mentions.size()))
        return {};
    const MentionItem& item = m_mentions[index.row()];
    switch (role) {
    case PositionRole: return item.position;
    case NameRole:     return item.name;
    case PubKeyRole:   return item.pubKey;
    }
    return {};
}

QHash<int, QByteArray> ChatInputMentionsModel::roleNames() const
{
    return {
        {PositionRole, "position"},
        {NameRole,     "name"},
        {PubKeyRole,   "pubKey"},
    };
}

void ChatInputMentionsModel::setMentions(const QVector<MentionItem>& mentions)
{
    beginResetModel();
    m_mentions = mentions;
    endResetModel();
}

// ── ChatInputHighlighter ──────────────────────────────────────────────────────

ChatInputHighlighter::ChatInputHighlighter(QObject* parent)
    : QSyntaxHighlighter(parent)
    , m_linksModel(new ChatInputLinksModel(this))
    , m_mentionsModel(new ChatInputMentionsModel(this))
{
}

QAbstractListModel* ChatInputHighlighter::linksModel() const
{
    return m_linksModel;
}

QAbstractListModel* ChatInputHighlighter::mentionsModel() const
{
    return m_mentionsModel;
}

void ChatInputHighlighter::insertMention(int position, const QString& name,
                                         const QString& pubKey)
{
    if (!document())
        return;

    QTextCharFormat fmt;
    fmt.setObjectType(MentionTextObject::MentionType);
    fmt.setProperty(MentionTextObject::NameProperty, name);
    fmt.setProperty(MentionTextObject::PubKeyProperty, pubKey);
    fmt.setProperty(MentionTextObject::UniqueIdProperty, ++m_mentionCounter);
    fmt.setVerticalAlignment(QTextCharFormat::AlignBottom);

    QTextCursor cursor(document());
    cursor.setPosition(qBound(0, position, document()->characterCount() - 1));
    cursor.insertText(QString(QChar::ObjectReplacementCharacter), fmt);
}

void ChatInputHighlighter::copySelectionToClipboard(int start, int end) const
{
    if (!document() || start >= end)
        return;

    QByteArray data;
    QDataStream stream(&data, QIODevice::WriteOnly);
    stream.setVersion(QDataStream::Qt_6_0);
    QString plainText;
    QString accum;

    // Emit any pending run of plain characters (tag 0) into both representations.
    const auto flushAccum = [&]() {
        if (!accum.isEmpty()) {
            stream << quint8(0) << accum;
            plainText += accum;
            accum.clear();
        }
    };

    QTextCursor cursor(document());
    for (int pos = start; pos < end; ++pos) {
        cursor.setPosition(pos);
        cursor.setPosition(pos + 1, QTextCursor::KeepAnchor);
        const QString ch = cursor.selectedText();
        const QTextCharFormat fmt = cursor.charFormat();

        if (ch == QString(QChar::ParagraphSeparator)) {
            flushAccum();
            stream << quint8(2);
            plainText += QLatin1Char('\n');
        } else if (fmt.objectType() == MentionTextObject::MentionType) {
            flushAccum();
            const QString name   = fmt.property(MentionTextObject::NameProperty).toString();
            const QString pubKey = fmt.property(MentionTextObject::PubKeyProperty).toString();
            stream << quint8(1) << name << pubKey;
            plainText += name; // mentions collapse to their name for external paste
        } else if (isEmojiImage(fmt)) {
            // Emoji images copy as their Unicode text (a plain text run): external paste gets the
            // emoji, internal paste re-inserts text that the reactive step re-imagifies.
            accum += fmt.property(kEmojiUnicodeProperty).toString();
        } else {
            accum += ch;
        }
    }
    flushAccum();

    auto* mime = new QMimeData();
    mime->setData(QString::fromLatin1(kChatInputMimeType), data);
    mime->setText(plainText);
    QGuiApplication::clipboard()->setMimeData(mime);
}

void ChatInputHighlighter::pasteFromClipboard(int selectionStart, int selectionEnd,
                                              int cursorPosition)
{
    if (!document())
        return;

    const QMimeData* mime = QGuiApplication::clipboard()->mimeData();
    if (!mime)
        return;

    // Replacing the selection and inserting the pasted content must be one undo step, so keep the
    // whole thing in a single edit block. Leave the selection *on the cursor* (instead of removing
    // it up front) so the first insert replaces it as one selection-aware operation — this makes a
    // single Ctrl+Z restore the replaced text with the caret back at its end, rather than two undo
    // steps that collapse the caret to the document start.
    QTextCursor cursor(document());
    if (selectionStart != selectionEnd) {
        cursor.setPosition(selectionStart);
        cursor.setPosition(selectionEnd, QTextCursor::KeepAnchor);
    } else {
        cursor.setPosition(cursorPosition);
    }

    cursor.beginEditBlock();
    if (mime->hasFormat(QString::fromLatin1(kChatInputMimeType))) {
        QByteArray data = mime->data(QString::fromLatin1(kChatInputMimeType));
        QDataStream stream(&data, QIODevice::ReadOnly);
        stream.setVersion(QDataStream::Qt_6_0);

        while (!stream.atEnd()) {
            quint8 type = 0;
            stream >> type;
            if (type == 0) {
                QString text;
                stream >> text;
                insertEmojiAwareText(cursor, text); // emoji → image inline; replaces any selection
            } else if (type == 1) {
                QString name, pubKey;
                stream >> name >> pubKey;
                QTextCharFormat fmt;
                fmt.setObjectType(MentionTextObject::MentionType);
                fmt.setProperty(MentionTextObject::NameProperty, name);
                fmt.setProperty(MentionTextObject::PubKeyProperty, pubKey);
                fmt.setProperty(MentionTextObject::UniqueIdProperty, ++m_mentionCounter);
                fmt.setVerticalAlignment(QTextCharFormat::AlignBottom);
                cursor.insertText(QString(QChar::ObjectReplacementCharacter), fmt);
            } else if (type == 2) {
                // insertBlock() doesn't clear a selection; drop it explicitly if a leading
                // paragraph separator is the first inserted token.
                if (cursor.hasSelection())
                    cursor.removeSelectedText();
                cursor.insertBlock();
            }
        }
    } else if (mime->hasText()) {
        insertEmojiAwareText(cursor, mime->text());
    }
    cursor.endEditBlock();
}

QString ChatInputHighlighter::textWithMentions() const
{
    if (!document())
        return {};

    QString out;
    QTextCursor cursor(document());
    // characterCount() includes the document's final block terminator; iterate the real chars.
    const int last = document()->characterCount() - 1;
    for (int pos = 0; pos < last; ++pos) {
        cursor.setPosition(pos);
        cursor.setPosition(pos + 1, QTextCursor::KeepAnchor);
        const QString ch = cursor.selectedText();
        const QTextCharFormat fmt = cursor.charFormat();

        if (ch == QString(QChar::ParagraphSeparator))
            out += QLatin1Char('\n');
        else if (fmt.objectType() == MentionTextObject::MentionType)
            out += QLatin1Char('@') + fmt.property(MentionTextObject::PubKeyProperty).toString();
        else if (isEmojiImage(fmt))
            out += fmt.property(kEmojiUnicodeProperty).toString();
        else
            out += ch;
    }
    return out;
}

void ChatInputHighlighter::setTextWithMentions(const QString& text, const QVariantMap& names)
{
    if (!document())
        return;

    QVector<TextMentionSpan> spans;
    collectMentionSpans(Markdown::parse(text, optionsFor(m_formatUnclosedCodeFence)), spans);
    std::sort(spans.begin(), spans.end(),
              [](const TextMentionSpan& a, const TextMentionSpan& b) { return a.start < b.start; });

    QTextCursor cursor(document());
    cursor.beginEditBlock();
    cursor.select(QTextCursor::Document);
    cursor.removeSelectedText();

    // Inserts plain text, turning '\n' into new blocks (the editor's block-per-line model) and
    // emoji directly into images when imageEmojis is on (so a loaded draft doesn't flicker).
    const auto insertPlain = [&](const QString& s) {
        const QStringList lines = s.split(QLatin1Char('\n'));
        for (int i = 0; i < lines.size(); ++i) {
            if (i > 0)
                cursor.insertBlock();
            if (!lines[i].isEmpty())
                insertEmojiAwareText(cursor, lines[i]);
        }
    };

    int pos = 0;
    for (const TextMentionSpan& span : std::as_const(spans)) {
        if (span.start > pos)
            insertPlain(text.mid(pos, span.start - pos));

        QString name = names.value(span.pubKey).toString();
        if (name.isEmpty())
            name = span.pubKey == QStringLiteral("0x00001") ? QStringLiteral("everyone")
                                                            : span.pubKey;

        QTextCharFormat fmt;
        fmt.setObjectType(MentionTextObject::MentionType);
        fmt.setProperty(MentionTextObject::NameProperty, QStringLiteral("@") + name);
        fmt.setProperty(MentionTextObject::PubKeyProperty, span.pubKey);
        fmt.setProperty(MentionTextObject::UniqueIdProperty, ++m_mentionCounter);
        fmt.setVerticalAlignment(QTextCharFormat::AlignBottom);
        cursor.insertText(QString(QChar::ObjectReplacementCharacter), fmt);
        pos = span.end;
    }
    if (pos < text.size())
        insertPlain(text.mid(pos));

    cursor.endEditBlock();
}

QQuickTextDocument* ChatInputHighlighter::quickTextDocument() const
{
    return m_quickTextDocument;
}

void ChatInputHighlighter::setQuickTextDocument(QQuickTextDocument* doc)
{
    if (m_quickTextDocument == doc)
        return;
    if (m_quickTextDocument && m_quickTextDocument->textDocument())
        disconnect(m_quickTextDocument->textDocument(), nullptr, this, nullptr);
    m_quickTextDocument = doc;
    if (doc) {
        QTextDocument* textDoc = doc->textDocument();
        setDocument(textDoc);
        // Reserve layout space for mention objects (the pill itself is drawn by a
        // QML overlay); the handler is owned by this highlighter.
        textDoc->documentLayout()->registerHandler(
            MentionTextObject::MentionType, new MentionTextObject(this));
        connect(textDoc, &QTextDocument::contentsChange,
                this, [this](int, int charsRemoved, int charsAdded) {
                    if (charsRemoved > 0 || charsAdded > 0)
                        QMetaObject::invokeMethod(this, "rehighlight",
                                                  Qt::QueuedConnection);
                });
    } else {
        setDocument(nullptr);
    }
    emit quickTextDocumentChanged();
}

QColor ChatInputHighlighter::codeBackground() const
{
    return m_codeBackground;
}

void ChatInputHighlighter::setCodeBackground(QColor color)
{
    if (m_codeBackground == color)
        return;
    m_codeBackground = color;
    m_cachedText.clear();
    rehighlight();
    emit codeBackgroundChanged();
}

QColor ChatInputHighlighter::delimiterColor() const
{
    return m_delimiterColor;
}
void ChatInputHighlighter::setDelimiterColor(QColor color)
{
    if (m_delimiterColor == color)
        return;
    m_delimiterColor = color;
    m_cachedText.clear();
    rehighlight();
    emit delimiterColorChanged();
}

QColor ChatInputHighlighter::linkColor() const
{
    return m_linkColor;
}
void ChatInputHighlighter::setLinkColor(QColor color)
{
    if (m_linkColor == color)
        return;
    m_linkColor = color;
    m_cachedText.clear();
    rehighlight();
    emit linkColorChanged();
}

QColor ChatInputHighlighter::quoteTextColor() const
{
    return m_quoteTextColor;
}
void ChatInputHighlighter::setQuoteTextColor(QColor color)
{
    if (m_quoteTextColor == color)
        return;
    m_quoteTextColor = color;
    m_cachedText.clear();
    rehighlight();
    emit quoteTextColorChanged();
}

bool ChatInputHighlighter::formatUnclosedCodeFence() const
{
    return m_formatUnclosedCodeFence;
}

void ChatInputHighlighter::setFormatUnclosedCodeFence(bool enabled)
{
    if (m_formatUnclosedCodeFence == enabled) return;
    m_formatUnclosedCodeFence = enabled;
    m_cachedText.clear();
    m_astValid = false; // the option changes how the text parses
    rehighlight();
    emit formatUnclosedCodeFenceChanged();
}

bool ChatInputHighlighter::fullLineHeightEmojis() const
{
    return m_fullLineHeightEmojis;
}

void ChatInputHighlighter::setFullLineHeightEmojis(bool enabled)
{
    if (m_fullLineHeightEmojis == enabled) return;
    m_fullLineHeightEmojis = enabled;
    m_cachedText.clear();
    rehighlight();
    emit fullLineHeightEmojisChanged();
}

bool ChatInputHighlighter::imageEmojis() const
{
    return m_imageEmojis;
}

void ChatInputHighlighter::setImageEmojis(bool enabled)
{
    if (m_imageEmojis == enabled) return;
    m_imageEmojis = enabled;
    if (document()) {
        // Convert the current content immediately (own undo step); typed emoji thereafter are
        // converted reactively from highlightBlock.
        if (enabled)
            convertEmojisToImages(/*joinUndo=*/false);
        else
            convertImagesToEmojis();
    }
    m_cachedText.clear();
    rehighlight();
    emit imageEmojisChanged();
}

QString ChatInputHighlighter::twemojiBaseUrl() const
{
    return m_twemojiBaseUrl;
}

void ChatInputHighlighter::setTwemojiBaseUrl(const QString& url)
{
    if (m_twemojiBaseUrl == url) return;
    m_twemojiBaseUrl = url;
    // Re-run the conversion so already-typed emoji pick up a base set after content exists.
    if (m_imageEmojis && document()) {
        convertEmojisToImages(/*joinUndo=*/false);
        m_cachedText.clear();
        rehighlight();
    }
    emit twemojiBaseUrlChanged();
}

bool ChatInputHighlighter::hasRawEmojis() const
{
    const QTextDocument* doc = document();
    if (!doc)
        return false;
    for (QTextBlock b = doc->begin(); b != doc->end(); b = b.next()) {
        const QString t = b.text();
        for (qsizetype i = 0; i < t.size();) {
            qsizetype units = 1;
            if (startsEmoji(t, i, units))
                return true;
            i += units;
        }
    }
    return false;
}

void ChatInputHighlighter::convertEmojisToImages(bool joinUndo)
{
    QTextDocument* doc = document();
    if (!doc || doc->isRedoAvailable())
        return;

    const int lineHeight = qMax(1, qRound(QFontMetricsF(doc->defaultFont()).height()));

    // Collect every emoji (grapheme cluster) as a document range with its Twemoji url. Emoji runs
    // are segmented per-cluster so ZWJ sequences map to their combined svg and adjacent distinct
    // emoji each get their own image. U+FFFC of existing objects never matches (isEmojiCodePoint),
    // so this is idempotent.
    struct Run { int start; int end; QString text; QString url; };
    QVector<Run> runs;
    for (QTextBlock b = doc->begin(); b != doc->end(); b = b.next()) {
        const QString t = b.text();
        const int base = b.position();
        qsizetype i = 0;
        while (i < t.size()) {
            qsizetype units = 1;
            if (!startsEmoji(t, i, units)) {
                i += units;
                continue;
            }
            const qsizetype runStart = i;
            i += units;
            while (i < t.size()) {
                qsizetype u2 = 1;
                if (!startsEmoji(t, i, u2))
                    break;
                i += u2;
            }
            const QString run = t.mid(runStart, i - runStart);
            QTextBoundaryFinder bf(QTextBoundaryFinder::Grapheme, run);
            int cs = 0;
            for (int ce = bf.toNextBoundary(); ce >= 0; ce = bf.toNextBoundary()) {
                if (ce > cs) {
                    const QString cluster = run.mid(cs, ce - cs);
                    const QString url = twemojiSvgUrl(m_twemojiBaseUrl, cluster);
                    if (!url.isEmpty())
                        runs.append({ int(base + runStart + cs), int(base + runStart + ce),
                                      cluster, url });
                }
                cs = ce;
            }
        }
    }
    if (runs.isEmpty())
        return;

    QTextCursor cursor(doc);
    if (joinUndo)
        cursor.joinPreviousEditBlock();
    else
        cursor.beginEditBlock();
    // Right-to-left so earlier positions stay valid as runs are replaced.
    for (int idx = runs.size() - 1; idx >= 0; --idx) {
        const Run& r = runs[idx];
        QTextCursor rc(doc);
        rc.setPosition(r.start);
        rc.setPosition(r.end, QTextCursor::KeepAnchor);
        rc.removeSelectedText();
        rc.insertImage(emojiImageFormat(r.text, r.url, lineHeight, ++m_emojiCounter));
    }
    cursor.endEditBlock();
    m_emojiImageLineHeight = lineHeight;
}

bool ChatInputHighlighter::insertEmojiObject(QTextCursor& cursor, const QString& emoji)
{
    if (!m_imageEmojis || !document())
        return false;
    const QString url = twemojiSvgUrl(m_twemojiBaseUrl, emoji);
    if (url.isEmpty())
        return false;
    const int lineHeight = qMax(1, qRound(QFontMetricsF(document()->defaultFont()).height()));
    cursor.insertImage(emojiImageFormat(emoji, url, lineHeight, ++m_emojiCounter));
    m_emojiImageLineHeight = lineHeight;
    return true;
}

void ChatInputHighlighter::insertEmojiAwareText(QTextCursor& cursor, const QString& text)
{
    if (!m_imageEmojis) {
        cursor.insertText(text); // font mode: plain, selection-aware insert
        return;
    }

    // insertImage() (unlike insertText) doesn't replace a selection, so drop it up front — an
    // emoji-first insert would otherwise leave the replaced text behind.
    if (cursor.hasSelection())
        cursor.removeSelectedText();

    qsizetype i = 0;
    while (i < text.size()) {
        qsizetype units = 1;
        if (!startsEmoji(text, i, units)) {
            // Run of non-emoji text — inserted verbatim (preserving any '\n' handling).
            const qsizetype s = i;
            i += units;
            while (i < text.size()) {
                qsizetype u2 = 1;
                if (startsEmoji(text, i, u2))
                    break;
                i += u2;
            }
            cursor.insertText(text.mid(s, i - s));
            continue;
        }
        // Run of emoji code points — segment per grapheme cluster; image each (text fallback).
        const qsizetype runStart = i;
        i += units;
        while (i < text.size()) {
            qsizetype u2 = 1;
            if (!startsEmoji(text, i, u2))
                break;
            i += u2;
        }
        const QString run = text.mid(runStart, i - runStart);
        QTextBoundaryFinder bf(QTextBoundaryFinder::Grapheme, run);
        int cs = 0;
        for (int ce = bf.toNextBoundary(); ce >= 0; ce = bf.toNextBoundary()) {
            if (ce > cs) {
                const QString cluster = run.mid(cs, ce - cs);
                if (!insertEmojiObject(cursor, cluster))
                    cursor.insertText(cluster);
            }
            cs = ce;
        }
    }
}

void ChatInputHighlighter::insertTextWithEmojis(int position, const QString& text)
{
    if (!document())
        return;
    QTextCursor cursor(document());
    cursor.setPosition(qBound(0, position, document()->characterCount() - 1));
    cursor.beginEditBlock();
    insertEmojiAwareText(cursor, text);
    cursor.endEditBlock();
}

int ChatInputHighlighter::emojiImageCount() const
{
    const QTextDocument* doc = document();
    if (!doc)
        return 0;
    int count = 0;
    for (QTextBlock b = doc->begin(); b != doc->end(); b = b.next())
        for (auto it = b.begin(); !it.atEnd(); ++it) {
            const QTextFragment frag = it.fragment();
            if (frag.isValid() && isEmojiImage(frag.charFormat()))
                ++count; // one fragment == one separately-rendered emoji image
        }
    return count;
}

void ChatInputHighlighter::convertImagesToEmojis()
{
    QTextDocument* doc = document();
    if (!doc)
        return;

    struct Img { int pos; QString text; };
    QVector<Img> imgs;
    for (QTextBlock b = doc->begin(); b != doc->end(); b = b.next()) {
        for (auto it = b.begin(); !it.atEnd(); ++it) {
            const QTextFragment frag = it.fragment();
            if (!frag.isValid() || !isEmojiImage(frag.charFormat()))
                continue;
            for (int p = frag.position(); p < frag.position() + frag.length(); ++p)
                imgs.append({ p, frag.charFormat().property(kEmojiUnicodeProperty).toString() });
        }
    }
    if (imgs.isEmpty())
        return;

    QTextCursor cursor(doc);
    cursor.beginEditBlock();
    std::sort(imgs.begin(), imgs.end(), [](const Img& a, const Img& b) { return a.pos > b.pos; });
    for (const Img& im : std::as_const(imgs)) {
        QTextCursor rc(doc);
        rc.setPosition(im.pos);
        rc.setPosition(im.pos + 1, QTextCursor::KeepAnchor);
        rc.insertText(im.text, QTextCharFormat()); // replace the image ORC with plain emoji text
    }
    cursor.endEditBlock();
    m_emojiImageLineHeight = 0;
}

void ChatInputHighlighter::resizeEmojiImages()
{
    QTextDocument* doc = document();
    if (!doc || doc->isRedoAvailable())
        return;

    const int lineHeight = qMax(1, qRound(QFontMetricsF(doc->defaultFont()).height()));
    if (lineHeight == m_emojiImageLineHeight)
        return;

    struct Img { int pos; QTextImageFormat fmt; };
    QVector<Img> imgs;
    for (QTextBlock b = doc->begin(); b != doc->end(); b = b.next()) {
        for (auto it = b.begin(); !it.atEnd(); ++it) {
            const QTextFragment frag = it.fragment();
            if (!frag.isValid() || !isEmojiImage(frag.charFormat()))
                continue;
            QTextImageFormat img = frag.charFormat().toImageFormat();
            img.setWidth(lineHeight);
            img.setHeight(lineHeight);
            for (int p = frag.position(); p < frag.position() + frag.length(); ++p)
                imgs.append({ p, img });
        }
    }
    m_emojiImageLineHeight = lineHeight;
    if (imgs.isEmpty())
        return;

    QTextCursor cursor(doc);
    cursor.beginEditBlock();
    for (const Img& im : std::as_const(imgs)) {
        QTextCursor rc(doc);
        rc.setPosition(im.pos);
        rc.setPosition(im.pos + 1, QTextCursor::KeepAnchor);
        rc.setCharFormat(im.fmt);
    }
    cursor.endEditBlock();
}

bool ChatInputHighlighter::inUnclosedCodeFence(int position) const
{
    if (!document()) return false;
    const qsizetype unclosedStart = Markdown::findUnclosedCodeFence(document()->toPlainText());
    return unclosedStart >= 0 && static_cast<qsizetype>(position) >= unclosedStart;
}

QTextCharFormat ChatInputHighlighter::buildFormat(unsigned int bits) const
{
    QTextCharFormat fmt;
    if (bits & kDelimiter) {
        fmt.setForeground(m_delimiterColor);
        return fmt;
    }
    if (bits & kCodeFence) {
        fmt.setFontFamilies(QFontDatabase::systemFont(QFontDatabase::FixedFont).families());
    } else if (bits & kCode) {
        fmt.setFontFamilies(QFontDatabase::systemFont(QFontDatabase::FixedFont).families());
        if (m_codeBackground.alpha() > 0)
            fmt.setBackground(m_codeBackground);
    }
    // Emphasis applies on top of code formatting (nested code inherits it).
    if (bits & kBold)          fmt.setFontWeight(QFont::Bold);
    if (bits & kItalic)        fmt.setFontItalic(true);
    if (bits & kStrikeThrough) fmt.setFontStrikeOut(true);
    if (bits & kLink)          fmt.setForeground(m_linkColor);
    else if ((bits & kQuote) && m_quoteTextColor.isValid())
        fmt.setForeground(m_quoteTextColor); // dim quote content (incl. nested code)
    return fmt;
}

QVariantList ChatInputHighlighter::parseFormats(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_formatUnclosedCodeFence));
    collectFormats(doc, result);
    return result;
}

QVariantList ChatInputHighlighter::parseDelimiters(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_formatUnclosedCodeFence));
    collectDelimiters(doc, result);
    return result;
}

QVariantList ChatInputHighlighter::parseCodeSpans(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_formatUnclosedCodeFence));
    collectCodeSpans(doc, result);
    return result;
}

QVariantList ChatInputHighlighter::parseLinks(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_formatUnclosedCodeFence));
    collectLinkInfo(doc, result);
    return result;
}

QVariantList ChatInputHighlighter::parseQuoteBlocks(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_formatUnclosedCodeFence));
    collectQuoteBlocks(doc, result);
    return result;
}

QSet<int> ChatInputHighlighter::quoteLineStarts() const
{
    if (!document())
        return {};
    const QString text = document()->toPlainText();
    return collectQuoteLineStarts(
        Markdown::parse(text, optionsFor(m_formatUnclosedCodeFence)), text);
}

bool ChatInputHighlighter::isInQuoteBlock(int position) const
{
    if (!document())
        return false;
    const QTextBlock block = document()->findBlock(position);
    return block.isValid()
            && quoteLineStarts().contains(static_cast<int>(block.position()));
}

bool ChatInputHighlighter::isQuoteContentStart(int position) const
{
    if (!document())
        return false;
    const QTextBlock block = document()->findBlock(position);
    return block.isValid()
            && quoteLineStarts().contains(static_cast<int>(block.position()))
            && position == block.position() + 2;
}

bool ChatInputHighlighter::isEmptyQuoteBlock(int position) const
{
    if (!document())
        return false;
    const QTextBlock block = document()->findBlock(position);
    return block.isValid()
            && quoteLineStarts().contains(static_cast<int>(block.position()))
            && block.text() == QStringLiteral("> ");
}

bool ChatInputHighlighter::isLineEndBeforeQuoteBlock(int position) const
{
    if (!document())
        return false;
    const QTextBlock block = document()->findBlock(position);
    if (!block.isValid() || position != block.position() + block.length() - 1)
        return false;
    const QTextBlock next = block.next();
    return next.isValid()
            && quoteLineStarts().contains(static_cast<int>(next.position()));
}

bool ChatInputHighlighter::isBlockEmpty(int position) const
{
    if (!document())
        return false;
    const QTextBlock block = document()->findBlock(position);
    return block.isValid() && block.text().isEmpty();
}

int ChatInputHighlighter::endOfPreviousBlock(int position) const
{
    if (!document())
        return position;
    const QTextBlock block = document()->findBlock(position);
    if (!block.isValid())
        return position;
    const QTextBlock prev = block.previous();
    if (!prev.isValid())
        return position;
    return static_cast<int>(prev.position() + prev.length() - 1);
}

int ChatInputHighlighter::snapToQuoteContent(int position) const
{
    if (!document())
        return position;
    const QTextBlock block = document()->findBlock(position);
    if (!block.isValid()
            || !quoteLineStarts().contains(static_cast<int>(block.position())))
        return position;
    if (position - block.position() < 2)
        return static_cast<int>(block.position() + 2);
    return position;
}

const Markdown::Node& ChatInputHighlighter::astForQuery() const
{
    const QString cur = document() ? document()->toPlainText() : QString();
    if (!m_astValid || m_astText != cur) {
        m_ast = Markdown::parse(cur, optionsFor(m_formatUnclosedCodeFence));
        m_astText = cur;
        m_astValid = true;
    }
    return m_ast;
}

bool ChatInputHighlighter::isInsideCode(int position) const
{
    return positionInCode(astForQuery(), position);
}

void ChatInputHighlighter::highlightBlock(const QString& text)
{
    if (!document())
        return;

    const QString fullText = document()->toPlainText();

    if (fullText != m_cachedText) {
        m_cachedText = fullText;
        m_flags.assign(fullText.length(), 0u);

        const Node doc = Markdown::parse(
            fullText, optionsFor(m_formatUnclosedCodeFence));

        m_ast = doc;          // cache the tree for position queries (isInsideCode)
        m_astText = fullText;
        m_astValid = true;

        flatten(doc, 0u, m_flags);
        reProtectQuotePrefixes(fullText, doc, m_flags);

        QVector<ChatInputLinksModel::LinkItem> modelItems;
        collectLinks(doc, modelItems);
        m_linksModel->setLinks(modelItems);

        refreshMentions(document(), m_mentionsModel);

        applyQuoteBlockFormats(collectQuoteLineStarts(doc, fullText));

        // A mention that ended up inside a code span/block is demoted to plain text.
        // Done out-of-band (it mutates the document) to avoid editing mid-highlight.
        QVector<int> mentionsInCode;
        collectMentionsInCode(doc, false, mentionsInCode);
        if (!mentionsInCode.isEmpty())
            QMetaObject::invokeMethod(this, [this] { demoteMentionsInCode(); },
                                      Qt::QueuedConnection);
    }

    // Image emojis: reactively convert newly-typed emoji to inline images, or rescale existing
    // ones after a font-size change. Kept out of the text-change guard above so a font change
    // (rehighlight with unchanged text) still resizes; the flag dedupes the per-block passes into
    // one queued edit. Runs out-of-band since it mutates the document.
    if (m_imageEmojis && document() && !m_emojiUpdateQueued) {
        const int lh = qMax(1, qRound(QFontMetricsF(document()->defaultFont()).height()));
        if (hasRawEmojis() || lh != m_emojiImageLineHeight) {
            m_emojiUpdateQueued = true;
            QMetaObject::invokeMethod(this, [this] {
                m_emojiUpdateQueued = false;
                if (!m_imageEmojis)
                    return;
                if (hasRawEmojis())
                    convertEmojisToImages(/*joinUndo=*/true);
                else
                    resizeEmojiImages();
            }, Qt::QueuedConnection);
        }
    }

    const int       blockStart = currentBlock().position();
    const qsizetype blockLen   = text.length();

    // Effective render bits for a block-relative index; object-replacement chars
    // (mentions) are never formatted — the pill is a QML overlay.
    auto flagAt = [&](qsizetype k) -> unsigned int {
        if (k >= blockLen || text[k] == QChar::ObjectReplacementCharacter)
            return 0u;
        const qsizetype docPos = blockStart + k;
        return (docPos < m_flags.size()) ? m_flags[docPos] : 0u;
    };

    qsizetype i = 0;
    while (i < blockLen) {
        const unsigned int f = flagAt(i);
        qsizetype j = i + 1;
        while (j < blockLen && flagAt(j) == f)
            ++j;
        if (f)
            setFormat(static_cast<int>(i), static_cast<int>(j - i), buildFormat(f));
        i = j;
    }

    // Size emojis to fill the line height. They render smaller than the line height, so we
    // bump their font size to the line height — the line already has slack over the font
    // size, so this fills the line without making it taller. (See isEmojiCodePoint.)
    if (m_fullLineHeightEmojis) {
        const QFont base = document()->defaultFont();
        const qreal lineHeight = QFontMetricsF(base).height();
        QTextCharFormat emojiFormat; // size-only, so it merges with any existing format
        if (base.pixelSize() > 0)
            emojiFormat.setProperty(QTextFormat::FontPixelSize, qRound(lineHeight));
        else
            emojiFormat.setProperty(QTextFormat::FontPointSize, base.pointSizeF() * 1.2);

        auto codePointAt = [&](qsizetype k, qsizetype& units) -> char32_t {
            const QChar c = text[k];
            if (c.isHighSurrogate() && k + 1 < blockLen && text[k + 1].isLowSurrogate()) {
                units = 2;
                return QChar::surrogateToUcs4(c, text[k + 1]);
            }
            units = 1;
            return c.unicode();
        };

        qsizetype k = 0;
        while (k < blockLen) {
            qsizetype units = 1;
            if (Markdown::isEmojiCodePoint(codePointAt(k, units))) {
                const qsizetype start = k;
                k += units;
                while (k < blockLen && Markdown::isEmojiCodePoint(codePointAt(k, units)))
                    k += units;
                setFormat(static_cast<int>(start), static_cast<int>(k - start), emojiFormat);
            } else {
                k += units;
            }
        }
    }
}

void ChatInputHighlighter::applyQuoteBlockFormats(const QSet<int>& quoteLineStarts)
{
    QTextDocument* doc = document();
    if (!doc || doc->isRedoAvailable())
        return;

    const qreal prefixWidth =
        QFontMetricsF(doc->defaultFont()).horizontalAdvance(QStringLiteral("> "));

    // Merged into the user's edit so undo/redo treats it as one step; safe to run
    // synchronously here — highlightBlock executes inside QSyntaxHighlighter's
    // inReformatBlocks guard, so the format-only change won't re-enter highlighting.
    QTextCursor cursor(doc);
    cursor.joinPreviousEditBlock();
    for (QTextBlock b = doc->begin(); b != doc->end(); b = b.next()) {
        const bool  isQuote = quoteLineStarts.contains(b.position());
        const qreal left    = isQuote ?  prefixWidth : 0.0;
        const qreal indent  = isQuote ? -prefixWidth : 0.0;
        const QTextBlockFormat bf = b.blockFormat();

        if (bf.leftMargin() == left && bf.textIndent() == indent)
            continue; // already correct — avoids needless edits

        QTextBlockFormat fmt;
        fmt.setLeftMargin(left);
        fmt.setTextIndent(indent);
        cursor.setPosition(b.position());
        cursor.mergeBlockFormat(fmt);
    }
    cursor.endEditBlock();
}

void ChatInputHighlighter::demoteMentionsInCode()
{
    QTextDocument* doc = document();
    if (!doc || doc->isRedoAvailable())
        return;

    const QString fullText = doc->toPlainText();
    const Node doc_ = Markdown::parse(fullText, optionsFor(m_formatUnclosedCodeFence));
    QVector<int> positions;
    collectMentionsInCode(doc_, false, positions);
    if (positions.isEmpty())
        return;

    QTextCursor cursor(doc);
    cursor.joinPreviousEditBlock();
    // Reverse order so earlier positions stay valid as text is replaced.
    for (int idx = positions.size() - 1; idx >= 0; --idx) {
        QTextCursor mc(doc);
        mc.setPosition(positions[idx]);
        mc.setPosition(positions[idx] + 1, QTextCursor::KeepAnchor);
        // The parser reports every U+FFFC (incl. emoji image objects) as a mention; only demote
        // real mentions — otherwise an emoji image inside code would be blanked out.
        if (mc.charFormat().objectType() != MentionTextObject::MentionType)
            continue;
        const QString name =
            mc.charFormat().property(MentionTextObject::NameProperty).toString();
        mc.insertText(name);
    }
    cursor.endEditBlock();
}

QVariantMap ChatInputHighlighter::emphasisAtInsertion(int position) const
{
    static const QVariantMap allFalse = {
        {QStringLiteral("bold"),          false},
        {QStringLiteral("italic"),        false},
        {QStringLiteral("strikethrough"), false},
    };

    if (!document())
        return allFalse;

    QString fullText = document()->toPlainText();
    if (position < 0 || position > static_cast<int>(fullText.length()))
        return allFalse;

    fullText.insert(position, QLatin1Char('a'));

    const Node doc = Markdown::parse(
        fullText, optionsFor(m_formatUnclosedCodeFence));
    const unsigned int bits = emphasisBitsAt(doc, position);

    return {
        {QStringLiteral("bold"),          bool(bits & kBold)},
        {QStringLiteral("italic"),        bool(bits & kItalic)},
        {QStringLiteral("strikethrough"), bool(bits & kStrikeThrough)},
    };
}

QVariantMap ChatInputHighlighter::emphasisAt(int position) const
{
    const unsigned int bits = (position >= 0 && position < static_cast<int>(m_flags.size()))
                              ? m_flags[position] : 0u;
    return {
        {QStringLiteral("bold"),          bool(bits & kBold)},
        {QStringLiteral("italic"),        bool(bits & kItalic)},
        {QStringLiteral("strikethrough"), bool(bits & kStrikeThrough)},
    };
}

QVariantMap ChatInputHighlighter::nodeAt(int position) const
{
    QVariantMap out = {
        {QStringLiteral("bold"),          false},
        {QStringLiteral("italic"),        false},
        {QStringLiteral("strikethrough"), false},
        {QStringLiteral("quote"),         false},
        {QStringLiteral("codeSpan"),      false},
        {QStringLiteral("codeBlock"),     false},
    };
    // Use the AST cached by highlightBlock — never reparse on a caret query.
    if (m_astValid)
        collectNodesAt(m_ast, position, out);
    return out;
}

void ChatInputHighlighter::removeFormatting(int position, const QString& kind)
{
    if (!document())
        return;

    const QVector<NodeKind> kinds = nodeKindsForFormatting(kind);
    if (kinds.isEmpty())
        return;

    // A one-shot action (not a hot caret query): use astForQuery() so the tree always matches the
    // current text, reparsing only when the cache is stale.
    const Node* node = findDeepestNode(astForQuery(), position, kinds);
    if (!node)
        return; // caret not strictly inside such a node — nothing to remove

    QVector<QPair<qsizetype, qsizetype>> ranges;
    if (node->kind == NodeKind::QuoteBlock) {
        // A quote block owns every "> " prefix in its range, including those an inline span pushed
        // deeper into the tree — gather them all.
        collectQuotePrefixes(*node, ranges);
    } else {
        // An inline node's delimiters are its own opener/closer (direct Delimiter children); nested
        // nodes keep their formatting. A quoted code block also holds the enclosing "> " prefixes as
        // children — those belong to the quote, not the code, so they must be kept.
        for (const Node& c : node->children) {
            if (c.kind == NodeKind::Delimiter && !c.literal.startsWith(QLatin1Char('>')))
                ranges.append({c.start, c.end});
        }
    }
    if (ranges.isEmpty())
        return;

    // Delete highest offset first so earlier ranges stay valid; one edit block ⇒ single undo step.
    std::sort(ranges.begin(), ranges.end(),
              [](const auto& a, const auto& b) { return a.first > b.first; });

    QTextCursor cursor(document());
    // Anchor the block at the caret so undo restores the cursor there: an edit block records the
    // cursor's position at beginEditBlock() time as its undo reposition target (a fresh cursor sits
    // at 0, which is why undo otherwise jumps to the start).
    cursor.setPosition(qBound(0, position, document()->characterCount() - 1));
    cursor.beginEditBlock();
    for (const auto& r : std::as_const(ranges)) {
        cursor.setPosition(static_cast<int>(r.first));
        cursor.setPosition(static_cast<int>(r.second), QTextCursor::KeepAnchor);
        cursor.removeSelectedText();
    }
    cursor.endEditBlock();
}
