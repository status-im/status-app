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
    if (html.isEmpty())
        return html; // keep empty lines empty (no <b></b> wrapper)
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

// Line-oriented segmentation: one source line → one output line. Delimiters render empty
// but still count as a line; code/quote blocks divide the content into separate blocks.
// Every empty input line is preserved, except the single newline that terminates a code
// block's own line (the parser leaves it outside the block) — that one is absorbed.
struct BlockAcc {
    QVariantList blocks;            // emitted blocks
    QStringList  lines;             // finalized text lines pending as a text block
    QString      cur;              // html of the line currently being built
    bool         curStarted = false; // line has seen a delimiter/content (a real line)
    bool         afterCode  = false; // last emitted block was code (absorb its line end)
};

void flushTextBlock(BlockAcc& a)
{
    if (a.lines.isEmpty())
        return;
    a.blocks.append(QVariantMap{{QStringLiteral("type"), QStringLiteral("text")},
                                {QStringLiteral("html"), a.lines.join(QStringLiteral("<br/>"))}});
    a.lines.clear();
}

void finalizeLine(BlockAcc& a)
{
    // The single newline ending a code block's own line is absorbed (no empty line).
    if (a.afterCode && a.cur.isEmpty()) {
        a.afterCode = false;
        a.curStarted = false;
        return;
    }
    // Emphasis is already applied per inline piece (see walk), so append `cur` as-is.
    a.lines.append(a.cur);
    a.cur.clear();
    a.curStarted = false;
    a.afterCode = false;
}

void walk(const QVector<Node>& nodes, unsigned emph, BlockAcc& a,
          const QHash<int, QPair<QString, QString>>& mentions)
{
    for (const Node& c : nodes) {
        switch (c.kind) {
        case NodeKind::Text: {
            const QStringList parts = c.literal.split(QLatin1Char('\n'));
            for (int i = 0; i < parts.size(); ++i) {
                if (i > 0)
                    finalizeLine(a); // a newline ends the current line
                if (!parts[i].isEmpty()) {
                    // Wrap each piece in the active emphasis so content before/after an
                    // emphasis-with-block keeps the outer emphasis (not the inner one).
                    a.cur += wrapEmphasis(escape(parts[i]), emph);
                    a.curStarted = true;
                }
            }
            break;
        }
        case NodeKind::Delimiter:
            a.curStarted = true; // marks a real (possibly empty) line; renders nothing
            break;

        case NodeKind::CodeBlock: {
            if (!a.cur.isEmpty())
                finalizeLine(a); // content before the block is its own line
            flushTextBlock(a);
            QString code = collectRawText(c);
            while (code.startsWith(QLatin1Char('\n'))) code.remove(0, 1);
            while (code.endsWith(QLatin1Char('\n')))   code.chop(1);
            a.blocks.append(QVariantMap{{QStringLiteral("type"), QStringLiteral("code")},
                                        {QStringLiteral("code"), code},
                                        {QStringLiteral("bold"), bool(emph & kBold)},
                                        {QStringLiteral("italic"), bool(emph & kItalic)},
                                        {QStringLiteral("strikethrough"), bool(emph & kStrike)}});
            a.cur.clear();
            a.curStarted = false;
            a.afterCode = true;
            break;
        }
        case NodeKind::QuoteBlock: {
            if (!a.cur.isEmpty())
                finalizeLine(a);
            flushTextBlock(a);
            BlockAcc inner;
            walk(c.children, emph, inner, mentions);
            if (inner.curStarted)
                finalizeLine(inner);
            flushTextBlock(inner);
            a.blocks.append(QVariantMap{{QStringLiteral("type"), QStringLiteral("quote")},
                                        {QStringLiteral("blocks"), inner.blocks}});
            a.cur.clear();
            a.curStarted = false;
            a.afterCode = false;
            break;
        }
        case NodeKind::Strong:
        case NodeKind::Emphasis:
        case NodeKind::Strikethrough:
            if (containsBlock(c)) {
                // Walk inline (shared accumulator) so a line straddling the emphasis
                // boundary assembles correctly, carrying the emphasis on the pieces.
                walk(c.children, emph | emphasisBitFor(c.kind), a, mentions);
            } else {
                // inline emphasis (no block) — wrap in any active outer emphasis too
                a.cur += wrapEmphasis(renderNode(c, mentions), emph);
                a.curStarted = true;
            }
            break;

        default: // CodeSpan, Link, Mention — inline leaves
            a.cur += wrapEmphasis(renderNode(c, mentions), emph);
            a.curStarted = true;
            break;
        }
    }
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
    // The document is Document > Paragraph > content; walk the paragraph's children.
    const QVector<Node>* content = &root.children;
    if (root.kind == NodeKind::Document && root.children.size() == 1
            && root.children.first().kind == NodeKind::Paragraph)
        content = &root.children.first().children;

    BlockAcc a;
    walk(*content, 0, a, mentions);
    if (a.curStarted)
        finalizeLine(a); // a trailing real line (incl. an empty delimiter/quoted line)
    flushTextBlock(a);
    return a.blocks;
}

} // namespace Markdown
