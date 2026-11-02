#include "StatusQ/markdownhtml.h"

#include <QHash>
#include <QVariantMap>

using namespace Qt::Literals::StringLiterals;

namespace {

using Markdown::Node;
using Markdown::NodeKind;
using Markdown::kSendViaChatPrefix;

QString escape(QStringView s)
{
    QString out;
    out.reserve(s.size());
    for (const QChar c : s) {
        if (c == QLatin1Char('&'))      out += "&amp;"_L1;
        else if (c == QLatin1Char('<')) out += "&lt;"_L1;
        else if (c == QLatin1Char('>')) out += "&gt;"_L1;
        else if (c == QLatin1Char('"')) out += "&quot;"_L1;
        else                            out += c;
    }
    return out;
}

// Inline text: escape and turn newlines into <br/> (used outside code).
QString escapeInline(QStringView s)
{
    QString out = escape(s);
    out.replace(QLatin1Char('\n'), "<br/>"_L1);
    return out;
}

// A font-size span for one emoji run (font-based rendering).
QString emojiFontSpan(QStringView emoji, int emojiPx)
{
    return QStringLiteral("<span style=\"font-size:%1px\">%2</span>").arg(emojiPx).arg(emoji);
}

// Passes each maximal run of consecutive emoji clusters in `s` (already HTML-escaped) through
// `wrapRun` and leaves everything else untouched. Safe on escaped text: entities and <br/> are
// ASCII, never in the emoji ranges.
template <typename WrapRun>
QString wrapEmojiRuns(const QString& s, WrapRun wrapRun)
{
    QString out;
    out.reserve(s.size());
    int runStart = -1; // start of the current maximal run of consecutive emoji clusters, or -1
    const auto flushRun = [&](int end) {
        out += wrapRun(s.mid(runStart, end - runStart));
        runStart = -1;
    };
    Markdown::forEachGraphemeCluster(s, [&](QStringView cluster, int start, int /*end*/) {
        if (Markdown::clusterHasEmoji(cluster)) {
            if (runStart < 0)
                runStart = start;
        } else {
            if (runStart >= 0)
                flushRun(start);
            out.append(cluster);
        }
        return true;
    });
    if (runStart >= 0)
        flushRun(s.size());
    return out;
}

// Renders each run of emoji in `s` wrapped in a font-size span, so the rich-text view enlarges
// them ~to the line height. `emojiPx <= 0` leaves the string unchanged.
QString emojiWrap(const QString& s, int emojiPx)
{
    if (emojiPx <= 0 || !Markdown::clusterHasEmoji(s))
        return s;

    return wrapEmojiRuns(s, [emojiPx](const QString& run) {
        return emojiFontSpan(run, emojiPx);
    });
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
                       const QHash<int, QPair<QString, QString>>& mentions, int emojiPx);

// Inline code markup; `content` is already escaped.
QString codeSpanHtml(QStringView content)
{
    return QStringLiteral("<code>%1</code>").arg(content);
}

QString renderNode(const Node& node,
                   const QHash<int, QPair<QString, QString>>& mentions, int emojiPx)
{
    switch (node.kind) {
    case NodeKind::Delimiter:
        return {}; // formatting characters are never rendered

    case NodeKind::Text:
        return emojiWrap(escapeInline(node.literal), emojiPx);

    case NodeKind::Strong:
        return QStringLiteral("<b>%1</b>").arg(renderChildren(node, mentions, emojiPx));
    case NodeKind::Emphasis:
        return QStringLiteral("<i>%1</i>").arg(renderChildren(node, mentions, emojiPx));
    case NodeKind::Strikethrough:
        return QStringLiteral("<s>%1</s>").arg(renderChildren(node, mentions, emojiPx));

    case NodeKind::CodeSpan:
        return codeSpanHtml(collectCodeText(node));
    case NodeKind::CodeBlock:
        // Block element ⇒ its own paragraph (starts on a new line).
        return QStringLiteral("<pre>%1</pre>")
                .arg(collectCodeText(node));

    case NodeKind::QuoteBlock:
        return QStringLiteral("<blockquote>%1</blockquote>")
                .arg(renderChildren(node, mentions, emojiPx));

    case NodeKind::Link:
        return QStringLiteral("<a href=\"%1\">%2</a>")
                .arg(escape(node.destination), renderChildren(node, mentions, emojiPx));

    case NodeKind::WalletLink:
        return QStringLiteral("<a href=\"%1%2\">%3</a>")
                .arg(kSendViaChatPrefix, escape(node.destination),
                     renderChildren(node, mentions, emojiPx));

    case NodeKind::Mention: {
        const auto it = mentions.constFind(static_cast<int>(node.start));
        const QString name = it != mentions.cend() ? it->first  : "@mention"_L1;
        const QString href = it != mentions.cend() ? it->second : QString();
        // Background is applied by the consumer via an `a.mention { … }` CSS rule.
        return QStringLiteral("<a href=\"%1\" class=\"mention\">%2</a>")
                .arg(escape(href), escape(name));
    }

    case NodeKind::Document:
    case NodeKind::Paragraph:
        return renderChildren(node, mentions, emojiPx);
    }
    return {};
}

QString renderChildren(const Node& node,
                       const QHash<int, QPair<QString, QString>>& mentions, int emojiPx)
{
    QString out;
    for (const Node& c : node.children)
        out += renderNode(c, mentions, emojiPx);
    return out;
}

QString renderSingleLine(const Node& node,
                         const QHash<int, QPair<QString, QString>>& mentions, int emojiPx);

QString renderSingleLineChildren(const Node& node,
                                 const QHash<int, QPair<QString, QString>>& mentions, int emojiPx)
{
    QString out;
    for (const Node& c : node.children)
        out += renderSingleLine(c, mentions, emojiPx);
    return out;
}

// One-line rendering: newlines collapse to spaces, code fences render like inline code spans,
// and quote blocks become "> "-prefixed classed spans (colored by the consumer's span.quote
// rule). Inline formatting, links and mentions match renderNode. Used for compact previews.
QString renderSingleLine(const Node& node,
                         const QHash<int, QPair<QString, QString>>& mentions, int emojiPx)
{
    switch (node.kind) {
    case NodeKind::Delimiter:
        return {};

    case NodeKind::Text: {
        QString t = escape(node.literal);
        t.replace(QLatin1Char('\n'), QLatin1Char(' '));
        return emojiWrap(t, emojiPx);
    }

    case NodeKind::Strong:
        return QStringLiteral("<b>%1</b>").arg(renderSingleLineChildren(node, mentions, emojiPx));
    case NodeKind::Emphasis:
        return QStringLiteral("<i>%1</i>").arg(renderSingleLineChildren(node, mentions, emojiPx));
    case NodeKind::Strikethrough:
        return QStringLiteral("<s>%1</s>").arg(renderSingleLineChildren(node, mentions, emojiPx));

    case NodeKind::CodeSpan:
    case NodeKind::CodeBlock: {
        // A fenced code block is rendered like an inline code span on one line.
        QString c = collectCodeText(node);
        c.replace(QLatin1Char('\n'), QLatin1Char(' '));
        return codeSpanHtml(c.trimmed());
    }

    case NodeKind::QuoteBlock:
        return QStringLiteral("<span class=\"quote\">&gt; %1</span>")
                .arg(renderSingleLineChildren(node, mentions, emojiPx));

    case NodeKind::Link:
        return QStringLiteral("<a href=\"%1\">%2</a>")
                .arg(escape(node.destination), renderSingleLineChildren(node, mentions, emojiPx));

    case NodeKind::WalletLink:
        return QStringLiteral("<a href=\"%1%2\">%3</a>")
                .arg(kSendViaChatPrefix, escape(node.destination),
                     renderSingleLineChildren(node, mentions, emojiPx));

    case NodeKind::Mention: {
        const auto it = mentions.constFind(static_cast<int>(node.start));
        const QString name = it != mentions.cend() ? it->first  : "@mention"_L1;
        const QString href = it != mentions.cend() ? it->second : QString();
        return QStringLiteral("<a href=\"%1\" class=\"mention\">%2</a>")
                .arg(escape(href), escape(name));
    }

    case NodeKind::Document:
    case NodeKind::Paragraph:
        return renderSingleLineChildren(node, mentions, emojiPx);
    }
    return {};
}

// ── Styled-text rendering ─────────────────────────────────────────────────────
// Text.StyledText understands only a small tag subset and no stylesheet at all (no <span>,
// no class, no CSS), so backgrounds and font families are out of reach: a code span and a
// quote block can only be coloured, and a mention is a coloured link rather than a pill.
// Line breaks are kept as <br/>, so the document keeps its shape (unlike renderSingleLine).

// Wraps `content` in a <font color> element; an empty colour or content is left alone.
QString fontColorElement(const QString& color, const QString& content)
{
    if (color.isEmpty() || content.isEmpty())
        return content;
    return QStringLiteral("<font color=\"%1\">%2</font>").arg(color, content);
}

// StyledText's only size step: 1.2x the base size, which is about the line height of our
// text font (see the emojiPx spans renderNode emits for the rich-text path).
QString emojiSizeElement(const QString& run)
{
    return QStringLiteral("<font size=\"+1\">%1</font>").arg(run);
}

// Inline text for StyledText: escaped, newlines as <br/>, emoji runs optionally enlarged.
QString escapeStyled(QStringView s, bool enlargeEmoji)
{
    QString out = escape(s);
    out.replace(QLatin1Char('\n'), "<br/>"_L1);
    if (enlargeEmoji && Markdown::clusterHasEmoji(out))
        out = wrapEmojiRuns(out, emojiSizeElement);
    return out;
}

// Code content for StyledText: escaped, newlines as <br/> and every space after the first of
// a run as &nbsp;, because StyledText collapses whitespace and code keeps its indentation.
QString escapeStyledCode(const Node& node)
{
    QString out = collectCodeText(node);
    out.replace(QLatin1Char('\n'), "<br/>"_L1);

    QString spaced;
    spaced.reserve(out.size());
    bool inSpaceRun = false;
    for (const QChar c : out) {
        if (c == QLatin1Char(' ')) {
            spaced += inSpaceRun ? "&nbsp;"_L1 : " "_L1;
            inSpaceRun = true;
        } else {
            spaced += c;
            inSpaceRun = false;
        }
    }
    return spaced;
}

QString renderStyled(const Node& node, const QHash<int, QPair<QString, QString>>& mentions,
                     const Markdown::StyledTextColors& colors, bool enlargeEmoji);

QString renderStyledChildren(const Node& node,
                             const QHash<int, QPair<QString, QString>>& mentions,
                             const Markdown::StyledTextColors& colors, bool enlargeEmoji)
{
    QString out;
    for (const Node& c : node.children)
        out += renderStyled(c, mentions, colors, enlargeEmoji);
    return out;
}

// Prefixes every line of an already rendered fragment with "> " (the lines are the <br/>
// separated pieces this renderer itself emitted). A trailing empty line is left alone: the
// newline that terminates the quote belongs to the block, and the text after it is not quoted.
QString quotePrefixLines(const QString& html)
{
    QStringList lines = html.split("<br/>"_L1);
    const int quoted = lines.constLast().isEmpty() ? lines.size() - 1 : lines.size();
    for (int i = 0; i < quoted; ++i)
        lines[i].prepend("&gt; "_L1);
    return lines.join("<br/>"_L1);
}

QString renderStyled(const Node& node, const QHash<int, QPair<QString, QString>>& mentions,
                     const Markdown::StyledTextColors& colors, bool enlargeEmoji)
{
    const auto children = [&] { return renderStyledChildren(node, mentions, colors, enlargeEmoji); };

    switch (node.kind) {
    case NodeKind::Delimiter:
        return {};

    case NodeKind::Text:
        return escapeStyled(node.literal, enlargeEmoji);

    case NodeKind::Strong:
        return QStringLiteral("<b>%1</b>").arg(children());
    case NodeKind::Emphasis:
        return QStringLiteral("<i>%1</i>").arg(children());
    case NodeKind::Strikethrough:
        return QStringLiteral("<s>%1</s>").arg(children());

    case NodeKind::CodeSpan:
        return fontColorElement(colors.code, escapeStyledCode(node));

    case NodeKind::CodeBlock: {
        // The newlines around a fence are the parser's, not the code's (see renderPlain).
        QString code = escapeStyledCode(node);
        while (code.startsWith("<br/>"_L1)) code.remove(0, 5);
        while (code.endsWith("<br/>"_L1))   code.chop(5);
        return fontColorElement(colors.code, code);
    }

    case NodeKind::QuoteBlock:
        return fontColorElement(colors.quote, quotePrefixLines(children()));

    case NodeKind::Link:
        return QStringLiteral("<a href=\"%1\">%2</a>")
                .arg(escape(node.destination), fontColorElement(colors.link, children()));

    case NodeKind::WalletLink:
        return QStringLiteral("<a href=\"%1%2\">%3</a>")
                .arg(kSendViaChatPrefix, escape(node.destination),
                     fontColorElement(colors.link, children()));

    case NodeKind::Mention: {
        const auto it = mentions.constFind(static_cast<int>(node.start));
        const QString name = it != mentions.cend() ? it->first  : "@mention"_L1;
        const QString href = it != mentions.cend() ? it->second : QString();
        // No pill: StyledText cannot paint a background, so the mention is only coloured.
        return QStringLiteral("<a href=\"%1\">%2</a>")
                .arg(escape(href), fontColorElement(colors.mention, escape(name)));
    }

    case NodeKind::Document:
    case NodeKind::Paragraph:
        return children();
    }
    return {};
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

QString renderPlain(const Node& node, const QHash<int, QPair<QString, QString>>& mentions);

QString renderPlainChildren(const Node& node,
                            const QHash<int, QPair<QString, QString>>& mentions)
{
    QString out;
    for (const Node& c : node.children)
        out += renderPlain(c, mentions);
    return out;
}

// Plain-text projection of the AST: formatting delimiters dropped, mentions rendered as their
// display name, inline/fenced code as their raw content, line breaks preserved. No HTML escaping.
QString renderPlain(const Node& node, const QHash<int, QPair<QString, QString>>& mentions)
{
    switch (node.kind) {
    case NodeKind::Delimiter:
        return {};

    case NodeKind::Text:
        return node.literal;

    case NodeKind::CodeSpan:
        return collectRawText(node);

    case NodeKind::CodeBlock: {
        QString code = collectRawText(node);
        while (code.startsWith(QLatin1Char('\n'))) code.remove(0, 1);
        while (code.endsWith(QLatin1Char('\n')))   code.chop(1);
        return code;
    }

    case NodeKind::Mention: {
        const auto it = mentions.constFind(static_cast<int>(node.start));
        return it != mentions.cend() ? it->first : "@mention"_L1;
    }

    case NodeKind::Strong:
    case NodeKind::Emphasis:
    case NodeKind::Strikethrough:
    case NodeKind::Link:
    case NodeKind::WalletLink:
    case NodeKind::QuoteBlock:
    case NodeKind::Document:
    case NodeKind::Paragraph:
        return renderPlainChildren(node, mentions);
    }
    return {};
}

// Outer emphasis carried into a split block, so the surrounding text and the block's
// own content keep the formatting they were wrapped in.
enum EmphasisBits { kBold = 1 << 0, kItalic = 1 << 1, kStrike = 1 << 2 };

constexpr unsigned int emphasisBitFor(NodeKind kind)
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

// True when the subtree contains a code span somewhere. A code span may span newlines,
// so an emphasis wrapping one must be walked (not rendered as a single node) to keep the
// per-line code handling — otherwise its background bleeds across the line breaks.
bool containsCodeSpan(const Node& node)
{
    if (node.kind == NodeKind::CodeSpan)
        return true;
    for (const Node& c : node.children)
        if (containsCodeSpan(c))
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
    a.blocks.append(QVariantMap{{"type"_L1, "text"_L1}, {"html"_L1, a.lines.join("<br/>"_L1)}});
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
          const QHash<int, QPair<QString, QString>>& mentions, int emojiPx)
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
                    a.cur += wrapEmphasis(emojiWrap(escape(parts[i]), emojiPx), emph);
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
            QVariantMap codeBlock{{"type"_L1, "code"_L1},
                                  {"code"_L1, code},
                                  {"bold"_L1, bool(emph & kBold)},
                                  {"italic"_L1, bool(emph & kItalic)},
                                  {"strikethrough"_L1, bool(emph & kStrike)}};
            a.blocks.append(codeBlock);
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
            walk(c.children, emph, inner, mentions, emojiPx);
            if (inner.curStarted)
                finalizeLine(inner);
            flushTextBlock(inner);
            a.blocks.append(QVariantMap{{"type"_L1, "quote"_L1},
                                        {"blocks"_L1, inner.blocks}});
            a.cur.clear();
            a.curStarted = false;
            a.afterCode = false;
            break;
        }
        case NodeKind::Strong:
        case NodeKind::Emphasis:
        case NodeKind::Strikethrough:
            if (containsBlock(c) || containsCodeSpan(c)) {
                // Walk inline (shared accumulator) so a line straddling the emphasis
                // boundary assembles correctly, carrying the emphasis on the pieces.
                // Walking also routes a nested code span through the per-line CodeSpan
                // case, keeping its background line-local.
                walk(c.children, emph | emphasisBitFor(c.kind), a, mentions, emojiPx);
            } else {
                // inline emphasis (no block) — wrap in any active outer emphasis too
                a.cur += wrapEmphasis(renderNode(c, mentions, emojiPx), emph);
                a.curStarted = true;
            }
            break;

        case NodeKind::CodeSpan: {
            // A code span may span newlines; emit one <code> per line so the
            // background wraps only the content on each line, not the line breaks
            // or blank lines around it (empty segments stay empty — no background).
            const QStringList parts = collectCodeText(c).split(QLatin1Char('\n'));
            for (int i = 0; i < parts.size(); ++i) {
                if (i > 0)
                    finalizeLine(a); // a newline ends the current line
                if (!parts[i].isEmpty())
                    a.cur += wrapEmphasis(
                        codeSpanHtml(parts[i]), emph);
                a.curStarted = true;
            }
            break;
        }

        default: // Link, Mention — inline leaves
            a.cur += wrapEmphasis(renderNode(c, mentions, emojiPx), emph);
            a.curStarted = true;
            break;
        }
    }
}

} // namespace

namespace Markdown {

QString toHtml(const Node& root, const QHash<int, QPair<QString, QString>>& mentions,
               int emojiPx)
{
    return renderNode(root, mentions, emojiPx);
}

QString toSingleLineHtml(const Node& root, const QHash<int, QPair<QString, QString>>& mentions,
                         int emojiPx)
{
    return renderSingleLine(root, mentions, emojiPx);
}

QString toStyledText(const Node& root, const QHash<int, QPair<QString, QString>>& mentions,
                     const StyledTextColors& colors, bool enlargeEmoji)
{
    return renderStyled(root, mentions, colors, enlargeEmoji);
}

QString toPlainText(const Node& root, const QHash<int, QPair<QString, QString>>& mentions)
{
    return renderPlain(root, mentions);
}

QVariantList toBlocks(const Node& root,
                      const QHash<int, QPair<QString, QString>>& mentions, int emojiPx)
{
    // The document is Document > Paragraph > content; walk the paragraph's children.
    const QVector<Node>* content = &root.children;
    if (root.kind == NodeKind::Document && root.children.size() == 1
            && root.children.first().kind == NodeKind::Paragraph)
        content = &root.children.first().children;

    BlockAcc a;
    walk(*content, 0, a, mentions, emojiPx);
    if (a.curStarted)
        finalizeLine(a); // a trailing real line (incl. an empty delimiter/quoted line)
    flushTextBlock(a);
    return a.blocks;
}

} // namespace Markdown
