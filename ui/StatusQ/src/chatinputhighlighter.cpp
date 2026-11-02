#include "StatusQ/chatinputhighlighter.h"

#include "StatusQ/markdownparser.h"
#include "StatusQ/mentiontextobject.h"

#include <QAbstractTextDocumentLayout>
#include <QClipboard>
#include <QColor>
#include <QDataStream>
#include <QFontDatabase>
#include <QFontMetricsF>
#include <QGuiApplication>
#include <QMimeData>
#include <QTextBlock>
#include <QTextBlockFormat>
#include <QTextCharFormat>
#include <QTextCursor>
#include <QVariantMap>
#include <QVector>

#include <algorithm>

using namespace Qt::Literals::StringLiterals;

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
constexpr auto kChatInputMimeType = "application/x-status-chat-input"_L1;

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
// Reads the code point at `i` (advancing `units` over a surrogate pair).
constexpr char32_t codePointAt(QStringView s, qsizetype i, qsizetype& units)
{
    const QChar c = s[i];
    if (c.isHighSurrogate() && i + 1 < s.size() && s[i + 1].isLowSurrogate()) {
        units = 2;
        return QChar::surrogateToUcs4(c, s[i + 1]);
    }
    units = 1;
    return c.unicode();
}

// True if the block text at [i, ...) starts an emoji code point (never matches the U+FFFC of an
// existing image/mention object, so conversion is idempotent).
constexpr bool startsEmoji(QStringView s, qsizetype i, qsizetype& units)
{
    return Markdown::isEmojiCodePoint(codePointAt(s, i, units));
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
constexpr QPair<qsizetype, qsizetype> contentRange(const Node& node)
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

constexpr void stamp(QVector<unsigned int>& flags, qsizetype s, qsizetype e, unsigned int bits)
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
        m["start"_L1]         = cr.first;
        m["end"_L1]           = cr.second;
        m["bold"_L1]          = node.kind == NodeKind::Strong;
        m["italic"_L1]        = node.kind == NodeKind::Emphasis;
        m["strikethrough"_L1] = node.kind == NodeKind::Strikethrough;
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
            m["start"_L1] = c.start;
            m["end"_L1]   = c.end;
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
        m["start"_L1] = cr.first;
        m["end"_L1]   = cr.second;
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
        m["text"_L1]   = node.destination;
        m["start"_L1]  = node.start;
        m["length"_L1] = node.end - node.start;
        out.append(m);
    }
    for (const Node& c : node.children)
        collectLinkInfo(c, out);
}

void collectQuoteBlocks(const Node& node, QVariantList& out)
{
    if (node.kind == NodeKind::QuoteBlock) {
        QVariantMap m;
        m["start"_L1] = node.start;
        m["end"_L1]   = node.end;
        out.append(m);
    }
    for (const Node& c : node.children)
        collectQuoteBlocks(c, out);
}

// True when a caret at `pos` counts as inside `node`'s full range (delimiters included). Inline
// nodes are strictly containing (node.start < pos < node.end), so a caret just after a closer
// (e.g. "**bold**|") falls outside.
//
// A block-level QuoteBlock additionally includes the caret at `node.end` when the quote ends
// *mid-line* (its last char isn't '\n') — i.e. the final quote line with no trailing newline, whose
// end-of-content caret coincides with node.end. Otherwise the caret at the end of such a line
// (e.g. end of input for "> quote") would wrongly fall outside the quote. When node.end sits right
// after a '\n' (a following line, or the empty line after a trailing newline) it stays exclusive.
constexpr bool nodeContainsCaret(const Node& node, qsizetype pos, QStringView text)
{
    if (pos <= node.start || pos > node.end)
        return false;
    if (pos < node.end)
        return true;
    // pos == node.end: inside only for a quote block that ends mid-line.
    return node.kind == NodeKind::QuoteBlock
            && node.end > node.start
            && node.end <= text.size()
            && text[node.end - 1] != QLatin1Char('\n');
}

// Marks, in `out`, every formatting kind whose range contains `pos` (see nodeContainsCaret). Full
// recursion is safe: a child's range is a subrange of its parent's, so a caret outside a node can't
// be inside any of its children.
void collectNodesAt(const Node& node, qsizetype pos, const QString& text, QVariantMap& out)
{
    if (nodeContainsCaret(node, pos, text)) {
        switch (node.kind) {
        case NodeKind::Strong:        out["bold"_L1]          = true; break;
        case NodeKind::Emphasis:      out["italic"_L1]        = true; break;
        case NodeKind::Strikethrough: out["strikethrough"_L1] = true; break;
        case NodeKind::QuoteBlock:    out["quote"_L1]         = true; break;
        case NodeKind::CodeSpan:      out["codeSpan"_L1]      = true; break;
        case NodeKind::CodeBlock:     out["codeBlock"_L1]     = true; break;
        default: break;
        }
    }
    for (const Node& c : node.children)
        collectNodesAt(c, pos, text, out);
}

// Maps a removeFormatting() kind string to its AST node kind, into `out`. Returns false for an
// unknown kind.
bool nodeKindForFormatting(const QString& kind, NodeKind& out)
{
    if (kind == QLatin1String("bold"))          { out = NodeKind::Strong;        return true; }
    if (kind == QLatin1String("italic"))        { out = NodeKind::Emphasis;      return true; }
    if (kind == QLatin1String("strikethrough")) { out = NodeKind::Strikethrough; return true; }
    if (kind == QLatin1String("quote"))         { out = NodeKind::QuoteBlock;    return true; }
    if (kind == QLatin1String("codeSpan"))      { out = NodeKind::CodeSpan;      return true; }
    if (kind == QLatin1String("codeBlock"))     { out = NodeKind::CodeBlock;     return true; }
    return false;
}

// Returns the innermost node of `kind` whose range contains `pos` (see nodeContainsCaret — same
// containment rule as collectNodesAt, including the block end-of-line inclusivity), or nullptr.
// Recurses into children first so the deepest match wins.
const Node* findDeepestNode(const Node& node, qsizetype pos, const QString& text, NodeKind kind)
{
    for (const Node& c : node.children) {
        if (const Node* hit = findDeepestNode(c, pos, text, kind))
            return hit;
    }
    if (node.kind == kind && nodeContainsCaret(node, pos, text))
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

constexpr bool isDelimiterChar(QChar c)
{
    return c == '*'_L1 || c == '~'_L1 || c == '`'_L1;
}

// Local (no-AST) delimiter probe shared by delimitersAt / removeDelimitersAt. Returns the delimiter
// char flanking `position` and the surrounding run length (the shorter of the left/right runs), or
// {QChar(), 0} when the caret is not enclosed by a matching delimiter run.
constexpr std::pair<QChar, int> surroundingDelimiterRun(QStringView text, int position)
{
    if (position <= 0 || position >= text.length())
        return {QChar(), 0};

    const QChar ch = text.at(position - 1);
    if (!isDelimiterChar(ch) || text.at(position) != ch)
        return {QChar(), 0};

    int left = 0;
    for (int i = position - 1; i >= 0 && text.at(i) == ch; --i)
        ++left;
    int right = 0;
    for (int i = position; i < text.length() && text.at(i) == ch; ++i)
        ++right;

    return {ch, std::min(left, right)};
}

// Single source of truth mapping a delimiter run of `ch`×`count` to formatting flags. When `out` is
// non-null it sets the flags there; returns whether any flag applies (used to gate removal so a lone
// "~" — which denotes nothing — is left alone).
constexpr bool applyDelimiterFlags(QChar ch, int count, QVariantMap* out)
{
    bool any = false;
    const auto set = [&](QLatin1String key) {
        any = true;
        if (out)
            (*out)[key] = true;
    };
    if (count > 0) {
        if (ch == '*'_L1) {
            if (count % 2 == 1) set("italic"_L1); // 1, 3, ... include a single "*"
            if (count >= 2)     set("bold"_L1);   // a "**" pair
        } else if (ch == '~'_L1) {
            if (count >= 2)     set("strikethrough"_L1); // "~~"
        } else if (ch == '`'_L1) {
            if (count >= 3)     set("codeBlock"_L1); // "```"
            else                set("codeSpan"_L1);  // "`" or "``"
        }
    }
    return any;
}

// Number of `ch` delimiter chars to strip from each side of the caret to remove `kind`, or 0 when
// `kind` is not present in the run (same presence rules as applyDelimiterFlags). Emphasis is the only
// stacking case, so `kind` disambiguates it: from "***" italic strips one "*" (leaving "**" bold),
// bold strips two (leaving "*" italic). The non-stacking kinds strip the whole run.
constexpr int delimiterRemovalCount(QChar ch, int count, const QString& kind)
{
    if (count <= 0)
        return 0;
    if (kind == QLatin1String("italic"))        return (ch == '*'_L1 && count % 2 == 1) ? 1 : 0;
    if (kind == QLatin1String("bold"))          return (ch == '*'_L1 && count >= 2)     ? 2 : 0;
    if (kind == QLatin1String("strikethrough")) return (ch == '~'_L1 && count >= 2)     ? count : 0;
    if (kind == QLatin1String("codeSpan"))      return (ch == '`'_L1 && count < 3)      ? count : 0;
    if (kind == QLatin1String("codeBlock"))     return (ch == '`'_L1 && count >= 3)     ? count : 0;
    return 0;
}

// The delimiter string wrapped around content to add `kind`, or empty for an unknown / non-delimiter
// kind (e.g. "quote", handled separately as a per-line prefix).
QString delimiterStringForKind(QStringView kind)
{
    if (kind == QLatin1String("bold"))          return "**"_L1;
    if (kind == QLatin1String("italic"))        return "*"_L1;
    if (kind == QLatin1String("strikethrough")) return "~~"_L1;
    if (kind == QLatin1String("codeSpan"))      return "`"_L1;
    if (kind == QLatin1String("codeBlock"))     return "```"_L1;
    return {};
}

// Whether every line the selection [selStart, selEnd) at least partially covers begins with "> ".
// Lines are split on '\n'; a line's content range excludes the newline. Returns false when no line
// is covered.
constexpr bool selectionLinesAllQuoted(QStringView text, int selStart, int selEnd)
{
    const int len = text.length();
    bool any = false;
    int lineStart = 0;
    for (int i = 0; i <= len; ++i) {
        if (i < len && text.at(i) != '\n'_L1)
            continue;

        const int lineEnd = i; // content end (the newline, or end of text)
        const bool touched = (selStart == selEnd)
            ? (selStart >= lineStart && selStart <= lineEnd)   // caret: the line it sits on
            : (selStart < lineEnd && selEnd > lineStart);      // selection: any content overlap
        if (touched) {
            any = true;
            const bool quoted = (lineEnd - lineStart) >= 2
                                && text.at(lineStart) == '>'_L1 && text.at(lineStart + 1) == ' '_L1;
            if (!quoted)
                return false;
        }
        lineStart = i + 1;
    }
    return any;
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
        {TextRole,   "text"_ba},
        {StartRole,  "start"_ba},
        {LengthRole, "length"_ba},
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
        {PositionRole, "position"_ba},
        {NameRole,     "name"_ba},
        {PubKeyRole,   "pubKey"_ba},
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
    , m_spellChecker(new SpellChecker(this))
    , m_linksModel(new ChatInputLinksModel(this))
    , m_mentionsModel(new ChatInputMentionsModel(this))
{
    connect(m_spellChecker, &SpellChecker::issuesChanged, this, [this] {
        if (!document())
            return;
        // Batch layout work, but deliver contentsChanged only after layout is
        // restored so Qt Quick's overlays never query an incomplete layout.
        QTextCursor cursor(document());
        cursor.beginEditBlock();
        const bool layoutEnabled = document()->isLayoutEnabled();
        document()->setLayoutEnabled(false);
        rehighlight();
        document()->setLayoutEnabled(layoutEnabled);
        cursor.endEditBlock();
    }, Qt::QueuedConnection);
}

QVariantMap ChatInputHighlighter::replaceSpellingSuggestion(const QString& replacement,
                                                            int selectionStart, int selectionEnd)
{
    const QVariantMap unchanged{{"selectionStart"_L1, selectionStart},
                                {"selectionEnd"_L1, selectionEnd}};
    if (!document() || !m_spellChecker->suggestions().contains(replacement))
        return unchanged;
    const int start = m_spellChecker->suggestionStart();
    const QString word = m_spellChecker->suggestionWord();
    const auto issue = m_spellChecker->issueAt(start);
    if (issue.isEmpty() || issue.value("word"_L1).toString() != word
        || document()->toPlainText().mid(start, word.size()) != word)
        return unchanged;

    QTextCursor selection(document());
    selection.setPosition(selectionStart);
    selection.setPosition(selectionEnd, QTextCursor::KeepAnchor);
    QTextCursor cursor(document());
    cursor.beginEditBlock();
    cursor.setPosition(start);
    cursor.setPosition(start + word.size(), QTextCursor::KeepAnchor);
    cursor.insertText(replacement);
    cursor.endEditBlock();
    m_spellChecker->acceptReplacement(start, replacement.size());
    return {{"selectionStart"_L1, selection.selectionStart()},
            {"selectionEnd"_L1, selection.selectionEnd()}};
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
        } else {
            accum += ch;
        }
    }
    flushAccum();

    auto* mime = new QMimeData();
    mime->setData(kChatInputMimeType, data);
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
    // Insertion begins at the selection start (or the caret). Remember whether that spot is inside a
    // quote block so continuation lines of a multi-line paste can be kept in the quote (see below).
    const int insertPos = (selectionStart != selectionEnd) ? selectionStart : cursorPosition;
    const bool inQuote = isInQuoteBlock(insertPos);

    QTextCursor cursor(document());
    if (selectionStart != selectionEnd) {
        cursor.setPosition(selectionStart);
        cursor.setPosition(selectionEnd, QTextCursor::KeepAnchor);
    } else {
        cursor.setPosition(cursorPosition);
    }

    cursor.beginEditBlock();
    if (mime->hasFormat(kChatInputMimeType)) {
        QByteArray data = mime->data(kChatInputMimeType);
        QDataStream stream(&data, QIODevice::ReadOnly);
        stream.setVersion(QDataStream::Qt_6_0);

        while (!stream.atEnd()) {
            quint8 type = 0;
            stream >> type;
            if (type == 0) {
                QString text;
                stream >> text;
                cursor.insertText(text);
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
                // Pasting into a quote block: keep this continuation line in the quote by
                // prefixing it right away, so following tokens append after the "> ".
                if (inQuote)
                    cursor.insertText("> "_L1);
            }
        }
    } else if (mime->hasText()) {
        // Pasting into a quote block: keep every continuation line in the quote by turning each
        // line break into "\n> ". The first line has no leading break, so it merges into the
        // already-present "> " prefix. Done inline (not as a post-pass) so the final insert ends
        // at the end of the pasted content — this keeps the caret there on the initial paste and
        // after undo→redo. Pre-existing "> " lines get double-prefixed ("> > "), which is fine.
        QString text = mime->text();
        if (inQuote)
            text.replace(QLatin1Char('\n'), "\n> "_L1);
        cursor.insertText(text);
    }
    cursor.endEditBlock();
}

bool ChatInputHighlighter::isSingleUrl(const QString& text) const
{
    const QString trimmed = text.trimmed();
    if (trimmed.isEmpty())
        return false;
    // A genuine bare URL never contains brackets/parens or whitespace (the autolink rule stops at
    // them), while an explicit "[label](url)" string does — reject those so they are not mistaken
    // for a single URL and wrapped again.
    for (const QChar c : trimmed) {
        if (c.isSpace() || c == QLatin1Char('[') || c == QLatin1Char(']')
                || c == QLatin1Char('(') || c == QLatin1Char(')')
                || c == QLatin1Char('{') || c == QLatin1Char('}'))
            return false;
    }
    const QVariantList links = parseLinks(trimmed);
    if (links.size() != 1)
        return false;
    const QVariantMap link = links.first().toMap();
    return link.value("start"_L1).toInt() == 0
           && link.value("length"_L1).toInt() == trimmed.size();
}

bool ChatInputHighlighter::isPlainTextRange(int start, int end) const
{
    if (!document() || start >= end)
        return false;

    QTextCursor cursor(document());
    cursor.setPosition(start);
    cursor.setPosition(end, QTextCursor::KeepAnchor);
    const QString sel = cursor.selectedText();
    // U+2029 (ParagraphSeparator) marks a block/newline break; U+FFFC (ObjectReplacementCharacter)
    // marks a mention pill or an inline emoji image. Either disqualifies the range from being a
    // clean, single-line plain-text label.
    return !sel.contains(QChar::ParagraphSeparator)
            && !sel.contains(QChar::ObjectReplacementCharacter);
}

void ChatInputHighlighter::wrapSelectionInLink(int start, int end, const QString& url)
{
    if (!document() || start >= end)
        return;

    // Put the selection *on the cursor* and replace it with "[" + label + "](url)" in a single
    // insert. Because it is one selection-aware operation (not brackets inserted around the text),
    // a single Ctrl+Z restores the original text with the caret back at the end of the selection —
    // rather than two undo steps that collapse the caret to the document start. The range is
    // guaranteed plain text by the caller (isPlainTextRange), so the label is safe to re-insert.
    QTextCursor cursor(document());
    cursor.setPosition(start);
    cursor.setPosition(end, QTextCursor::KeepAnchor);
    const QString label = cursor.selectedText();
    cursor.insertText(QStringLiteral("[%1](%2)").arg(label, url));
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
   
    const auto insertPlain = [&](const QString& s) {
        const QStringList lines = s.split(QLatin1Char('\n'));
        for (int i = 0; i < lines.size(); ++i) {
            if (i > 0)
                cursor.insertBlock();
            if (!lines[i].isEmpty())
                cursor.insertText(lines[i]);
        }
    };

    int pos = 0;
    for (const TextMentionSpan& span : std::as_const(spans)) {
        if (span.start > pos)
            insertPlain(text.mid(pos, span.start - pos));

        QString name = names.value(span.pubKey).toString();
        if (name.isEmpty())
            name = span.pubKey == "0x00001"_L1 ? "everyone"_L1
                                               : span.pubKey;

        QTextCharFormat fmt;
        fmt.setObjectType(MentionTextObject::MentionType);
        fmt.setProperty(MentionTextObject::NameProperty, "@"_L1 + name);
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
    m_documentTextDirty = true;
    if (doc) {
        QTextDocument* textDoc = doc->textDocument();
        // Invalidate before QSyntaxHighlighter receives the change: the document
        // revision is not yet updated during synchronous contentsChange delivery.
        connect(textDoc, &QTextDocument::contentsChange,
                this, [this](int, int charsRemoved, int charsAdded) {
                    if (charsRemoved > 0 || charsAdded > 0) {
                        m_documentTextDirty = true;
                        QMetaObject::invokeMethod(this, "rehighlight",
                                                  Qt::QueuedConnection);
                    }
                });
        setDocument(textDoc);
        m_redoAvailable = textDoc->isRedoAvailable();
        connect(textDoc, &QTextDocument::redoAvailable, this,
                [this](bool available) { m_redoAvailable = available; });
        // availableRedoSteps excludes the next redo command.
        connect(textDoc, &QTextDocument::contentsChanged, this,
                [this, textDoc, undoSteps = textDoc->availableUndoSteps(),
                 redoSteps = textDoc->availableRedoSteps() + int(textDoc->isRedoAvailable())]() mutable {
                    const int undo = textDoc->availableUndoSteps();
                    const int redo = textDoc->availableRedoSteps() + int(textDoc->isRedoAvailable());
                    // New edits announce redo invalidation before contentsChanged;
                    // replay announces availability after delivering the restored text.
                    const bool replay = undo < undoSteps
                        || (m_redoAvailable && redo < redoSteps
                            && undo + redo == undoSteps + redoSteps);
                    undoSteps = undo;
                    redoSteps = redo;
                    if (replay) {
                        m_spellChecker->setText(textDoc->toPlainText());
                        m_spellChecker->recheck();
                    }
                });
        // Reserve layout space for mention objects (the pill itself is drawn by a
        // QML overlay); the handler is owned by this highlighter.
        textDoc->documentLayout()->registerHandler(
            MentionTextObject::MentionType, new MentionTextObject(this));
    } else {
        setDocument(nullptr);
    }
    m_spellChecker->setText(doc ? doc->textDocument()->toPlainText() : QString());
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

QColor ChatInputHighlighter::textColor() const
{
    return m_textColor;
}

void ChatInputHighlighter::setTextColor(QColor color)
{
    if (m_textColor == color)
        return;
    m_textColor = color;
    rehighlight();
    emit textColorChanged();
}

QColor ChatInputHighlighter::spellCheckUnderlineColor() const
{
    return m_spellCheckUnderlineColor;
}

void ChatInputHighlighter::setSpellCheckUnderlineColor(const QColor& color)
{
    if (m_spellCheckUnderlineColor == color)
        return;
    m_spellCheckUnderlineColor = color;
    rehighlight();
    emit spellCheckUnderlineColorChanged();
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

void ChatInputHighlighter::replaceText(int start, int end, const QString& text)
{
    if (!document())
        return;
    const int last = document()->characterCount() - 1;
    const int from = qBound(0, qMin(start, end), last);
    const int to = qBound(0, qMax(start, end), last);
    QTextCursor cursor(document());
    cursor.setPosition(from);
    cursor.setPosition(to, QTextCursor::KeepAnchor);
    cursor.beginEditBlock();
    if (cursor.hasSelection())
        cursor.removeSelectedText();
    cursor.insertText(text);
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
           && block.text() == "> "_L1;
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

    // Rehighlighting visits every block. Flattening the whole document for each
    // visit becomes quadratic for messages with many paragraphs.
    if (m_documentTextDirty) {
        m_documentText = document()->toPlainText();
        m_documentTextDirty = false;
    }
    const QString& fullText = m_documentText;
    m_spellChecker->setText(fullText);

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

        // Enlarge whole grapheme clusters: a cluster is emoji when it holds any emoji code point,
        // so keycaps (base 0-9 # *) and subdivision flags are sized as one unit rather than split.
        int runStart = -1; // start of the current run of consecutive emoji clusters, or -1
        Markdown::forEachGraphemeCluster(text, [&](QStringView cluster, int start, int) {
            if (Markdown::clusterHasEmoji(cluster)) {
                if (runStart < 0)
                    runStart = start;
            } else if (runStart >= 0) {
                setFormat(runStart, start - runStart, emojiFormat);
                runStart = -1;
            }
            return true;
        });
        if (runStart >= 0)
            setFormat(runStart, text.size() - runStart, emojiFormat);
    }

    // Merge with the already-composed markdown format, never replacing its properties.
    const auto issues = m_spellChecker->issues();
    const auto first = std::lower_bound(issues.cbegin(), issues.cend(), blockStart,
                                        [](const QVariant& value, int position) {
                                            return value.toMap().value("start"_L1).toInt() < position;
                                        });
    for (auto it = first; it != issues.cend(); ++it) {
        const auto issue = it->toMap();
        const int start = issue.value("start"_L1).toInt() - blockStart;
        if (start >= blockLen)
            break;
        const int end = qMin(blockLen, issue.value("start"_L1).toInt() + issue.value("length"_L1).toInt() - blockStart);
        for (int position = start; position < end; ++position) {
            auto spellingFormat = format(position);
#if QT_VERSION >= QT_VERSION_CHECK(6, 12, 0)
            spellingFormat.setUnderlineStyle(QTextCharFormat::SpellCheckUnderline);
#else
            // Before Qt 6.12, Qt Quick only renders single glyph-run underlines.
            spellingFormat.setUnderlineStyle(QTextCharFormat::SingleUnderline);
            // Its color-range merge ignores underline-only formats.
            if (!spellingFormat.hasProperty(QTextFormat::ForegroundBrush))
                spellingFormat.setForeground(m_textColor);
#endif
            spellingFormat.setUnderlineColor(m_spellCheckUnderlineColor);
            setFormat(position, 1, spellingFormat);
        }
    }
}

void ChatInputHighlighter::applyQuoteBlockFormats(const QSet<int>& quoteLineStarts)
{
    QTextDocument* doc = document();
    if (!doc || doc->isRedoAvailable())
        return;

    const qreal prefixWidth =
        QFontMetricsF(doc->defaultFont()).horizontalAdvance("> "_L1);

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
        // The parser reports every U+FFFC as a mention; only demote real mention objects.
        if (mc.charFormat().objectType() != MentionTextObject::MentionType)
            continue;
        const QString name =
            mc.charFormat().property(MentionTextObject::NameProperty).toString();
        mc.insertText(name);
    }
    cursor.endEditBlock();
}

QVariantMap ChatInputHighlighter::emphasisAt(int position) const
{
    const unsigned int bits = (position >= 0 && position < static_cast<int>(m_flags.size()))
                              ? m_flags[position] : 0u;
    return {
        {"bold"_L1,          bool(bits & kBold)},
        {"italic"_L1,        bool(bits & kItalic)},
        {"strikethrough"_L1, bool(bits & kStrikeThrough)},
    };
}

QVariantMap ChatInputHighlighter::nodeAt(int position) const
{
    QVariantMap out = {
        {"bold"_L1,          false},
        {"italic"_L1,        false},
        {"strikethrough"_L1, false},
        {"quote"_L1,         false},
        {"codeSpan"_L1,      false},
        {"codeBlock"_L1,     false},
    };
    // Use the AST cached by highlightBlock — never reparse on a caret query. m_astText is the text
    // that AST was built from, so it stays in sync with m_ast.
    if (m_astValid)
        collectNodesAt(m_ast, position, m_astText, out);
    return out;
}

void ChatInputHighlighter::removeFormatting(int position, const QString& kind)
{
    if (!document())
        return;

    NodeKind targetKind;
    if (!nodeKindForFormatting(kind, targetKind))
        return;

    // A one-shot action (not a hot caret query): use astForQuery() so the tree always matches the
    // current text, reparsing only when the cache is stale. m_astText is kept in sync with it.
    const Node& ast = astForQuery();
    const Node* node = findDeepestNode(ast, position, m_astText, targetKind);
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

QVariantMap ChatInputHighlighter::replaceFormatting(int position, const QString& fromKind,
                                                    const QString& toKind)
{
    // Swaps the delimiters of the `fromKind` element around `position` for `toKind`'s (e.g. a code
    // span's single backticks → a code block's triple backticks), keeping the content, as one edit
    // block. Returns the resulting content selection (empty ⇒ a caret) so the editor can restore it.
    QVariantMap result = {{"selectionStart"_L1, position},
                          {"selectionEnd"_L1,   position}};

    const QString toDelim = delimiterStringForKind(toKind);
    NodeKind targetKind;
    if (!document() || toDelim.isEmpty() || !nodeKindForFormatting(fromKind, targetKind))
        return result;

    // The two delimiter ranges to replace, plus the content range between them (reported back).
    QVector<QPair<int, int>> delims;
    int openerLen = 0;
    int contentStart = position;
    int contentEnd = position;

    const Node& ast = astForQuery();
    if (const Node* node = findDeepestNode(ast, position, m_astText, targetKind)) {
        // Inline code node: its opener/closer are its non-quote Delimiter children.
        for (const Node& c : node->children) {
            if (c.kind == NodeKind::Delimiter && !c.literal.startsWith(QLatin1Char('>')))
                delims.append({static_cast<int>(c.start), static_cast<int>(c.end)});
        }
        if (delims.size() < 2)
            return result;
        std::sort(delims.begin(), delims.end());
        openerLen    = delims.first().second - delims.first().first;
        contentStart = delims.first().second; // end of opener
        contentEnd   = delims.last().first;   // start of closer
    } else {
        // No AST node (e.g. an empty "`|`" span just added): swap the delimiter run flanking the
        // caret. delimiterRemovalCount gives how many chars `fromKind` occupies on each side.
        const auto [ch, count] = surroundingDelimiterRun(document()->toPlainText(), position);
        openerLen = delimiterRemovalCount(ch, count, fromKind);
        if (openerLen <= 0)
            return result;
        delims.append({position - openerLen, position});
        delims.append({position, position + openerLen});
        contentStart = contentEnd = position; // empty content, caret between
    }

    // Content shifts by the opener's length change; the closer sits past the content, so replacing
    // it doesn't move the reported selection.
    const int shift = toDelim.length() - openerLen;

    // Replace highest-offset range first so the earlier one stays valid; single undo step.
    std::sort(delims.begin(), delims.end(),
              [](const auto& a, const auto& b) { return a.first > b.first; });
    QTextCursor cursor(document());
    cursor.setPosition(qBound(0, position, document()->characterCount() - 1));
    cursor.beginEditBlock();
    for (const auto& r : std::as_const(delims)) {
        cursor.setPosition(r.first);
        cursor.setPosition(r.second, QTextCursor::KeepAnchor);
        cursor.insertText(toDelim); // replaces the selected delimiter run
    }
    cursor.endEditBlock();

    result["selectionStart"_L1] = contentStart + shift;
    result["selectionEnd"_L1]   = contentEnd + shift;
    return result;
}

QVariantMap ChatInputHighlighter::delimitersAt(int position) const
{
    QVariantMap out = {
        {"bold"_L1,          false},
        {"italic"_L1,        false},
        {"strikethrough"_L1, false},
        {"codeSpan"_L1,      false},
        {"codeBlock"_L1,     false},
    };
    if (!document())
        return out;

    const auto [ch, count] = surroundingDelimiterRun(document()->toPlainText(), position);
    applyDelimiterFlags(ch, count, &out);
    return out;
}

QVariantMap ChatInputHighlighter::delimitersAtSelection(int selectionStart, int selectionEnd) const
{
    QVariantMap out = {
        {"bold"_L1,          false},
        {"italic"_L1,        false},
        {"strikethrough"_L1, false},
        {"codeSpan"_L1,      false},
        {"codeBlock"_L1,     false},
        {"quote"_L1,         false}, // no surrounding delimiter denotes a quote
    };
    if (!document())
        return out;

    const QString text = document()->toPlainText();
    const int len = text.length();
    if (selectionStart > selectionEnd)
        std::swap(selectionStart, selectionEnd);
    selectionStart = qBound(0, selectionStart, len);
    selectionEnd = qBound(0, selectionEnd, len);

    // Quote is decided by the selected lines, not the delimiters, so compute it before any return.
    out["quote"_L1] = selectionLinesAllQuoted(text, selectionStart, selectionEnd);

    // Expand the context past every delimiter char flanking the selection, on both ends.
    int start = selectionStart;
    while (start > 0 && isDelimiterChar(text.at(start - 1)))
        --start;
    int end = selectionEnd;
    while (end < len && isDelimiterChar(text.at(end)))
        ++end;
    if (start >= end)
        return out;

    // The delimiter block flanking each end of the expanded context (interior delimiters, e.g. the
    // backticks inside "*A`B`C*", are not part of either block and don't count).
    int contentStart = start;
    while (contentStart < end && isDelimiterChar(text.at(contentStart)))
        ++contentStart;
    int contentEnd = end;
    while (contentEnd > start && isDelimiterChar(text.at(contentEnd - 1)))
        --contentEnd;
    // All-delimiter region (no content between): split it so the same chars aren't matched twice.
    if (contentStart >= contentEnd)
        contentStart = contentEnd = (start + end) / 2;

    QString leftBlock  = text.mid(start, contentStart - start);
    QString rightBlock = text.mid(contentEnd, end - contentEnd);

    // Consume the delimiter tokens in priority order: each token present (as adjacent chars) in
    // BOTH blocks sets its flag and is blanked out (replaced by neutral spaces, not removed) in each
    // block, so what remains can still match a shorter token. Blanking rather than removing keeps
    // positions fixed, so delimiters left on either side of a consumed token don't become adjacent
    // and form a spurious token (e.g. "~**~" ⇒ bold only, not bold+strikethrough). Longer/compound
    // tokens come first ("**" before "*", "```" before "`") so a bold pair isn't mistaken for two
    // italics, nor a code fence for a code span. Position of a token within a block is irrelevant,
    // so crossed layers ("~~**A~~**") are both reported.
    auto consume = [&](const QString& token, const QString& flag) {
        const int li = leftBlock.indexOf(token);
        const int ri = rightBlock.indexOf(token);
        if (li >= 0 && ri >= 0) {
            out[flag] = true;
            leftBlock.replace(li, token.size(), QString(token.size(), QLatin1Char(' ')));
            rightBlock.replace(ri, token.size(), QString(token.size(), QLatin1Char(' ')));
        }
    };
    consume("**"_L1,  "bold"_L1);
    consume("*"_L1,   "italic"_L1);
    consume("```"_L1, "codeBlock"_L1);
    consume("`"_L1,   "codeSpan"_L1);
    consume("~~"_L1,  "strikethrough"_L1);
    return out;
}

void ChatInputHighlighter::removeDelimitersAtSelection(int selectionStart, int selectionEnd,
                                                       const QString& kind)
{
    if (!document())
        return;

    const QString text = document()->toPlainText();
    const int len = text.length();
    if (selectionStart > selectionEnd)
        std::swap(selectionStart, selectionEnd);
    selectionStart = qBound(0, selectionStart, len);
    selectionEnd = qBound(0, selectionEnd, len);

    // Ranges to delete, gathered then removed highest-first in one edit block (single undo step).
    QVector<QPair<int, int>> ranges;

    if (kind == QLatin1String("quote")) {
        // Strip the "> " prefix from every line the selection at least partially covers (mirrors
        // the quote rule of delimitersAtSelection / selectionLinesAllQuoted).
        int lineStart = 0;
        for (int i = 0; i <= len; ++i) {
            if (i < len && text.at(i) != QLatin1Char('\n'))
                continue;
            const int lineEnd = i;
            const bool touched = (selectionStart == selectionEnd)
                ? (selectionStart >= lineStart && selectionStart <= lineEnd)
                : (selectionStart < lineEnd && selectionEnd > lineStart);
            if (touched && (lineEnd - lineStart) >= 2
                && text.at(lineStart) == QLatin1Char('>') && text.at(lineStart + 1) == QLatin1Char(' '))
                ranges.append({lineStart, lineStart + 2});
            lineStart = i + 1;
        }
    } else {
        // Mirror delimitersAtSelection: expand the flanking delimiter blocks, then walk the tokens
        // in the same priority order, blanking each one found on both ends (so positions stay put
        // and separated delimiters don't merge). But when the token for `kind` is reached, instead
        // of blanking, remove exactly those matched delimiters from the document.
        int start = selectionStart;
        while (start > 0 && isDelimiterChar(text.at(start - 1)))
            --start;
        int end = selectionEnd;
        while (end < len && isDelimiterChar(text.at(end)))
            ++end;
        if (start >= end)
            return;

        int contentStart = start;
        while (contentStart < end && isDelimiterChar(text.at(contentStart)))
            ++contentStart;
        int contentEnd = end;
        while (contentEnd > start && isDelimiterChar(text.at(contentEnd - 1)))
            --contentEnd;
        if (contentStart >= contentEnd)
            contentStart = contentEnd = (start + end) / 2;

        QString leftBlock  = text.mid(start, contentStart - start);
        QString rightBlock = text.mid(contentEnd, end - contentEnd);

        struct Token { QString str; QString kind; };
        const Token tokens[] = {
            { "**"_L1,  "bold"_L1 },
            { "*"_L1,   "italic"_L1 },
            { "```"_L1, "codeBlock"_L1 },
            { "`"_L1,   "codeSpan"_L1 },
            { "~~"_L1,  "strikethrough"_L1 },
        };
        for (const Token& t : tokens) {
            const int li = leftBlock.indexOf(t.str);
            const int ri = rightBlock.indexOf(t.str);
            const bool onBoth = li >= 0 && ri >= 0;
            if (t.kind == kind) {
                if (!onBoth)
                    return; // the kind's delimiters aren't around the selection — nothing to remove
                const int n = static_cast<int>(t.str.size());
                ranges.append({start + li, start + li + n});
                ranges.append({contentEnd + ri, contentEnd + ri + n});
                break;
            }
            if (onBoth) {
                leftBlock.replace(li, t.str.size(), QString(t.str.size(), ' '_L1));
                rightBlock.replace(ri, t.str.size(), QString(t.str.size(), ' '_L1));
            }
        }
    }

    if (ranges.isEmpty())
        return;

    std::sort(ranges.begin(), ranges.end(),
              [](const auto& a, const auto& b) { return a.first > b.first; });

    QTextCursor cursor(document());
    cursor.setPosition(qBound(0, selectionStart, document()->characterCount() - 1));
    cursor.beginEditBlock();
    for (const auto& r : std::as_const(ranges)) {
        cursor.setPosition(r.first);
        cursor.setPosition(r.second, QTextCursor::KeepAnchor);
        cursor.removeSelectedText();
    }
    cursor.endEditBlock();
}

QVariantMap ChatInputHighlighter::addFormatting(int selectionStart, int selectionEnd,
                                                const QString& kind)
{
    const QString text = document() ? document()->toPlainText() : QString();
    const int len = text.length();
    if (selectionStart > selectionEnd)
        std::swap(selectionStart, selectionEnd);
    selectionStart = qBound(0, selectionStart, len);
    selectionEnd = qBound(0, selectionEnd, len);

    // Returned selection: where the editor should place the caret/selection afterwards. Defaults to
    // the (unchanged) input, so a no-op leaves the selection put.
    int newStart = selectionStart;
    int newEnd = selectionEnd;

    if (!document())
        return {{"selectionStart"_L1, newStart}, {"selectionEnd"_L1, newEnd}};

    QTextCursor cursor(document());
    // Anchor the block at the caret so undo restores the cursor there: an edit block records the
    // cursor's position at beginEditBlock() time as its undo reposition target (a fresh cursor sits
    // at 0, which is why undo otherwise jumps to the start).
    cursor.setPosition(qBound(0, selectionStart, document()->characterCount() - 1));

    if (kind == QLatin1String("quote")) {
        // Add a "> " prefix to every line the selection at least partially covers (an empty
        // selection is the single line the caret sits on).
        QVector<int> lineStarts;
        int lineStart = 0;
        for (int i = 0; i <= len; ++i) {
            if (i < len && text.at(i) != QLatin1Char('\n'))
                continue;
            const int lineEnd = i;
            const bool touched = (selectionStart == selectionEnd)
                ? (selectionStart >= lineStart && selectionStart <= lineEnd)
                : (selectionStart < lineEnd && selectionEnd > lineStart);
            if (touched)
                lineStarts.append(lineStart);
            lineStart = i + 1;
        }
        if (!lineStarts.isEmpty()) {
            // Each inserted prefix at or before an endpoint shifts it right by 2 (keeps the same
            // content selected).
            for (int p : std::as_const(lineStarts)) {
                if (p <= selectionStart) newStart += 2;
                if (p <= selectionEnd)   newEnd += 2;
            }
            std::sort(lineStarts.begin(), lineStarts.end(), std::greater<int>()); // insert high→low
            cursor.beginEditBlock();
            for (int p : std::as_const(lineStarts)) {
                cursor.setPosition(p);
                cursor.insertText("> "_L1);
            }
            cursor.endEditBlock();
        }
    } else {
        const QString delim = delimiterStringForKind(kind);
        if (!delim.isEmpty()) {
            cursor.beginEditBlock();
            // Insert the closer first (higher offset) so selectionStart stays valid.
            cursor.setPosition(selectionEnd);
            cursor.insertText(delim);
            cursor.setPosition(selectionStart);
            cursor.insertText(delim);
            cursor.endEditBlock();
            // The wrapped content now sits between the delimiters, shifted by the opener's length.
            newStart = selectionStart + delim.length();
            newEnd = selectionEnd + delim.length();
        }
    }

    return {{"selectionStart"_L1, newStart}, {"selectionEnd"_L1, newEnd}};
}

void ChatInputHighlighter::removeDelimitersAt(int position, const QString& kind)
{
    if (!document())
        return;

    const auto [ch, count] = surroundingDelimiterRun(document()->toPlainText(), position);
    // How many delimiter chars `kind` accounts for on each side (0 ⇒ not present ⇒ no-op).
    const int remove = delimiterRemovalCount(ch, count, kind);
    if (remove <= 0)
        return;

    QTextCursor cursor(document());
    // Anchor near the caret so undo keeps the cursor by the restored run instead of jumping to the
    // document start (the caret sits between the two adjacent deletions, so — unlike removeFormatting
    // — it can't be pinned to the exact original spot).
    cursor.setPosition(qBound(0, position, document()->characterCount() - 1));
    cursor.beginEditBlock();
    // Delete the trailing run first (higher offsets) so the leading range stays valid.
    cursor.setPosition(position);
    cursor.setPosition(position + remove, QTextCursor::KeepAnchor);
    cursor.removeSelectedText();
    cursor.setPosition(position - remove);
    cursor.setPosition(position, QTextCursor::KeepAnchor);
    cursor.removeSelectedText();
    cursor.endEditBlock();
}
