#include "StatusQ/chatinputhighlighter.h"

#include "StatusQ/markdownparser.h"

#include <QColor>
#include <QFontDatabase>
#include <QTextCharFormat>
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

using Markdown::Node;
using Markdown::NodeKind;

Markdown::Options optionsFor(bool multiline, bool unclosedFence)
{
    Markdown::Options o;
    o.multilineEmphasis = multiline;
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
        // monospace + background over markers and content alike
        stamp(flags, node.start, node.end, kCode);
        break;
    case NodeKind::CodeBlock:
        for (const Node& c : node.children)
            stamp(flags, c.start, c.end,
                  c.kind == NodeKind::Delimiter ? kDelimiter : kCodeFence);
        break;
    case NodeKind::Text:
        stamp(flags, node.start, node.end, acc);
        break;
    case NodeKind::Delimiter:
        stamp(flags, node.start, node.end, kDelimiter);
        break;
    }
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

// ── ChatInputHighlighter ──────────────────────────────────────────────────────

ChatInputHighlighter::ChatInputHighlighter(QObject* parent)
    : QSyntaxHighlighter(parent)
    , m_linksModel(new ChatInputLinksModel(this))
{
}

QAbstractListModel* ChatInputHighlighter::linksModel() const
{
    return m_linksModel;
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
        setDocument(doc->textDocument());
        connect(doc->textDocument(), &QTextDocument::contentsChange,
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

bool ChatInputHighlighter::multilineEmphasis() const
{
    return m_multilineEmphasis;
}

void ChatInputHighlighter::setMultilineEmphasis(bool enabled)
{
    if (m_multilineEmphasis == enabled)
        return;
    m_multilineEmphasis = enabled;
    m_cachedText.clear();
    rehighlight();
    emit multilineEmphasisChanged();
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
    rehighlight();
    emit formatUnclosedCodeFenceChanged();
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
        return fmt;
    }
    if (bits & kCode) {
        fmt.setFontFamilies(QFontDatabase::systemFont(QFontDatabase::FixedFont).families());
        if (m_codeBackground.alpha() > 0)
            fmt.setBackground(m_codeBackground);
        return fmt;
    }
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
        text, optionsFor(m_multilineEmphasis, m_formatUnclosedCodeFence));
    collectFormats(doc, result);
    return result;
}

QVariantList ChatInputHighlighter::parseDelimiters(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_multilineEmphasis, m_formatUnclosedCodeFence));
    collectDelimiters(doc, result);
    return result;
}

QVariantList ChatInputHighlighter::parseCodeSpans(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_multilineEmphasis, m_formatUnclosedCodeFence));
    collectCodeSpans(doc, result);
    return result;
}

QVariantList ChatInputHighlighter::parseLinks(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_multilineEmphasis, m_formatUnclosedCodeFence));
    collectLinkInfo(doc, result);
    return result;
}

QVariantList ChatInputHighlighter::parseQuoteBlocks(const QString& text) const
{
    QVariantList result;
    const Node doc = Markdown::parse(
        text, optionsFor(m_multilineEmphasis, m_formatUnclosedCodeFence));
    collectQuoteBlocks(doc, result);
    return result;
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
            fullText, optionsFor(m_multilineEmphasis, m_formatUnclosedCodeFence));

        flatten(doc, 0u, m_flags);
        reProtectQuotePrefixes(fullText, doc, m_flags);

        QVector<ChatInputLinksModel::LinkItem> modelItems;
        collectLinks(doc, modelItems);
        m_linksModel->setLinks(modelItems);
    }

    const int       blockStart = currentBlock().position();
    const qsizetype blockLen   = text.length();

    qsizetype i = 0;
    while (i < blockLen) {
        const qsizetype    docPos = blockStart + i;
        const unsigned int f = (docPos < m_flags.size()) ? m_flags[docPos] : 0u;
        qsizetype j = i + 1;
        while (j < blockLen) {
            const unsigned int nf = ((blockStart + j) < m_flags.size())
                                    ? m_flags[blockStart + j] : 0u;
            if (nf != f) break;
            ++j;
        }
        if (f)
            setFormat(static_cast<int>(i), static_cast<int>(j - i), buildFormat(f));
        i = j;
    }
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
        fullText, optionsFor(m_multilineEmphasis, m_formatUnclosedCodeFence));
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
