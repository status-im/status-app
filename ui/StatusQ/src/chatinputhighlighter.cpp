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

namespace {

// Final render bits stamped per character and consumed by buildFormat().
constexpr unsigned int kBold          = 1u << 0;
constexpr unsigned int kItalic        = 1u << 1;
constexpr unsigned int kStrikeThrough = 1u << 2;
constexpr unsigned int kDelimiter     = 1u << 3; // emphasis/fence markers: dark gray
constexpr unsigned int kCode          = 1u << 4; // single-backtick: monospace + background
constexpr unsigned int kCodeFence     = 1u << 5; // triple-backtick content: monospace
constexpr unsigned int kLink          = 1u << 6; // URL: blue foreground
constexpr unsigned int kQuote         = 1u << 7; // block-quote line: dark blue

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
        for (const Node& c : node.children)
            flatten(c, acc | kLink, flags);
        break;
    case NodeKind::CodeSpan:
        // Markers and content are monospace + background (kCode). The content inherits
        // any outer emphasis (nested code can be bold/italic/struck through); the
        // backtick markers keep only their own kCode style — no inherited emphasis.
        for (const Node& c : node.children)
            stamp(flags, c.start, c.end,
                  c.kind == NodeKind::Delimiter
                      ? kCode
                      : kCode | (acc & kEmphasisMask));
        break;
    case NodeKind::CodeBlock:
        for (const Node& c : node.children)
            stamp(flags, c.start, c.end,
                  c.kind == NodeKind::Delimiter
                      ? kDelimiter
                      : kCodeFence | (acc & kEmphasisMask));
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

    QTextCursor cursor(document());
    if (selectionStart != selectionEnd) {
        cursor.setPosition(selectionStart);
        cursor.setPosition(selectionEnd, QTextCursor::KeepAnchor);
        cursor.removeSelectedText();
    } else {
        cursor.setPosition(cursorPosition);
    }

    if (mime->hasFormat(QString::fromLatin1(kChatInputMimeType))) {
        QByteArray data = mime->data(QString::fromLatin1(kChatInputMimeType));
        QDataStream stream(&data, QIODevice::ReadOnly);
        stream.setVersion(QDataStream::Qt_6_0);

        cursor.beginEditBlock();
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
                cursor.insertBlock();
            }
        }
        cursor.endEditBlock();
    } else if (mime->hasText()) {
        cursor.insertText(mime->text());
    }
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

bool ChatInputHighlighter::enlargeEmojis() const
{
    return m_enlargeEmojis;
}

void ChatInputHighlighter::setEnlargeEmojis(bool enabled)
{
    if (m_enlargeEmojis == enabled) return;
    m_enlargeEmojis = enabled;
    m_cachedText.clear();
    rehighlight();
    emit enlargeEmojisChanged();
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
        fmt.setForeground(QColor(Qt::darkGray));
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
    if (bits & kLink)          fmt.setForeground(QColor(Qt::blue));
    else if (bits & kQuote)    fmt.setForeground(QColor(Qt::darkBlue));
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

    // Enlarge emojis to fill the line. They render smaller than the line height, so we
    // bump their font size to the line height — the line already has slack over the font
    // size, so this fills the line without making it taller. (See isEmojiCodePoint.)
    if (m_enlargeEmojis) {
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
