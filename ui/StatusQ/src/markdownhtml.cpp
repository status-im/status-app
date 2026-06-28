#include "StatusQ/markdownhtml.h"

#include <QVariantMap>

namespace {

using Markdown::Node;
using Markdown::NodeKind;

QString escape(const QString& s)
{
    QString out;
    out.reserve(s.size());
    for (const QChar c : s) {
        if (c == QLatin1Char('&'))      out += QStringLiteral("&amp;");
        else if (c == QLatin1Char('<')) out += QStringLiteral("&lt;");
        else if (c == QLatin1Char('>')) out += QStringLiteral("&gt;");
        else if (c == QLatin1Char('"')) out += QStringLiteral("&quot;");
        else                            out += c;
    }
    return out;
}

// Inline text: escape and turn newlines into <br/> (used outside code).
QString escapeInline(const QString& s)
{
    QString out = escape(s);
    out.replace(QLatin1Char('\n'), QStringLiteral("<br/>"));
    return out;
}

// Concatenates the raw (escaped, newlines preserved) text of every Text descendant,
// skipping delimiters — used for code spans/blocks where content is not re-formatted.
QString collectCodeText(const Node& node)
{
    if (node.kind == NodeKind::Text)
        return escape(node.literal);
    if (node.kind == NodeKind::Delimiter)
        return {};

    QString out;
    for (const Node& c : node.children)
        out += collectCodeText(c);
    return out;
}

QString renderChildren(const Node& node,
                       const QHash<int, QPair<QString, QString>>& mentions);

QString renderNode(const Node& node,
                   const QHash<int, QPair<QString, QString>>& mentions)
{
    switch (node.kind) {
    case NodeKind::Delimiter:
        return {}; // formatting characters are never rendered

    case NodeKind::Text:
        return escapeInline(node.literal);

    case NodeKind::Strong:
        return QStringLiteral("<b>%1</b>").arg(renderChildren(node, mentions));
    case NodeKind::Emphasis:
        return QStringLiteral("<i>%1</i>").arg(renderChildren(node, mentions));
    case NodeKind::Strikethrough:
        return QStringLiteral("<s>%1</s>").arg(renderChildren(node, mentions));

    case NodeKind::CodeSpan:
        return QStringLiteral("<code style=\"background-color:#e8e8e8;\">%1</code>")
                .arg(collectCodeText(node));
    case NodeKind::CodeBlock:
        // Block element ⇒ its own paragraph (starts on a new line).
        return QStringLiteral("<pre>%1</pre>").arg(collectCodeText(node));

    case NodeKind::QuoteBlock:
        return QStringLiteral("<blockquote>%1</blockquote>")
                .arg(renderChildren(node, mentions));

    case NodeKind::Link:
        return QStringLiteral("<a href=\"%1\">%2</a>")
                .arg(escape(node.destination), renderChildren(node, mentions));

    case NodeKind::Mention: {
        const auto it = mentions.constFind(static_cast<int>(node.start));
        const QString name = it != mentions.cend() ? it->first  : QStringLiteral("@mention");
        const QString href = it != mentions.cend() ? it->second : QString();
        return QStringLiteral("<a href=\"%1\" style=\"background-color:#e3f2fd;\">%2</a>")
                .arg(escape(href), escape(name));
    }

    case NodeKind::Document:
    case NodeKind::Paragraph:
        return renderChildren(node, mentions);
    }
    return {};
}

QString renderChildren(const Node& node,
                       const QHash<int, QPair<QString, QString>>& mentions)
{
    QString out;
    for (const Node& c : node.children)
        out += renderNode(c, mentions);
    return out;
}

// Raw (unescaped, newlines preserved) text of every Text descendant, delimiters skipped
// — the literal content of a code block, trimmed of surrounding blank lines.
QString collectRawText(const Node& node)
{
    if (node.kind == NodeKind::Text)
        return node.literal;
    if (node.kind == NodeKind::Delimiter)
        return {};

    QString out;
    for (const Node& c : node.children)
        out += collectRawText(c);
    return out;
}

// Outer emphasis carried into a split block, so the surrounding text and the block's
// own content keep the formatting they were wrapped in.
enum EmphasisBits { kBold = 1 << 0, kItalic = 1 << 1, kStrike = 1 << 2 };

unsigned emphasisBitFor(NodeKind kind)
{
    switch (kind) {
    case NodeKind::Strong:        return kBold;
    case NodeKind::Emphasis:      return kItalic;
    case NodeKind::Strikethrough: return kStrike;
    default:                      return 0;
    }
}

QString wrapEmphasis(const QString& html, unsigned bits)
{
    QString out = html;
    if (bits & kStrike) out = QStringLiteral("<s>%1</s>").arg(out);
    if (bits & kItalic) out = QStringLiteral("<i>%1</i>").arg(out);
    if (bits & kBold)   out = QStringLiteral("<b>%1</b>").arg(out);
    return out;
}

// True when the subtree contains a code or quote block (i.e. a split point) somewhere.
bool containsBlock(const Node& node)
{
    if (node.kind == NodeKind::CodeBlock || node.kind == NodeKind::QuoteBlock)
        return true;
    for (const Node& c : node.children)
        if (containsBlock(c))
            return true;
    return false;
}

// Splits a list of sibling nodes into decorated blocks (text / code / quote). Recurses
// into quote blocks (so nested code becomes its own sub-block) and into emphasis nodes
// that wrap a block (so the block is split out while the surrounding text and the
// block's content keep the outer formatting, carried via `emph`).
QVariantList segment(const QVector<Node>& children,
                     const QHash<int, QPair<QString, QString>>& mentions,
                     unsigned emph)
{
    QVariantList blocks;
    QVector<Node> textRun;

    auto flushText = [&] {
        if (textRun.isEmpty())
            return;
        QString html;
        for (const Node& n : textRun)
            html += renderNode(n, mentions);
        textRun.clear();

        QString probe = html;
        probe.remove(QStringLiteral("<br/>"));
        if (probe.trimmed().isEmpty())
            return; // drop whitespace-only runs (e.g. blank lines around blocks)

        blocks.append(QVariantMap{{QStringLiteral("type"), QStringLiteral("text")},
                                  {QStringLiteral("html"), wrapEmphasis(html, emph)}});
    };

    for (const Node& c : children) {
        if (c.kind == NodeKind::CodeBlock) {
            flushText();
            QString code = collectRawText(c);
            while (code.startsWith(QLatin1Char('\n'))) code.remove(0, 1);
            while (code.endsWith(QLatin1Char('\n')))   code.chop(1);
            blocks.append(QVariantMap{{QStringLiteral("type"), QStringLiteral("code")},
                                      {QStringLiteral("code"), code},
                                      {QStringLiteral("bold"), bool(emph & kBold)},
                                      {QStringLiteral("italic"), bool(emph & kItalic)},
                                      {QStringLiteral("strikethrough"), bool(emph & kStrike)}});
        } else if (c.kind == NodeKind::QuoteBlock) {
            flushText();
            blocks.append(QVariantMap{{QStringLiteral("type"), QStringLiteral("quote")},
                                      {QStringLiteral("blocks"), segment(c.children, mentions, emph)}});
        } else if (emphasisBitFor(c.kind) && containsBlock(c)) {
            // Emphasis wrapping a block: descend so the block is split out, keeping the
            // outer + this emphasis on the pieces.
            flushText();
            blocks += segment(c.children, mentions, emph | emphasisBitFor(c.kind));
        } else {
            textRun.append(c); // inline (incl. emphasis without a block)
        }
    }
    flushText();
    return blocks;
}

} // namespace

namespace Markdown {

QString toHtml(const Node& root, const QHash<int, QPair<QString, QString>>& mentions)
{
    return renderNode(root, mentions);
}

QVariantList toBlocks(const Node& root,
                      const QHash<int, QPair<QString, QString>>& mentions)
{
    // The document is Document > Paragraph > content; segment the paragraph's children.
    const QVector<Node>* content = &root.children;
    if (root.kind == NodeKind::Document && root.children.size() == 1
            && root.children.first().kind == NodeKind::Paragraph)
        content = &root.children.first().children;
    return segment(*content, mentions, 0);
}

} // namespace Markdown
