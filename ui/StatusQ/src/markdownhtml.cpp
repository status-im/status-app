#include "StatusQ/markdownhtml.h"

#include <QFile>
#include <QTextBoundaryFinder>
#include <QUrl>
#include <QVariantMap>

namespace {

using Markdown::Node;
using Markdown::NodeKind;

// Prefix applied to a WalletLink's raw destination (address / ENS name) so that activating the
// rendered <a> invokes the "send via personal chat" flow (see MessageView.onLinkActivated).
const QString kSendViaChatPrefix = QStringLiteral("//send-via-personal-chat//");

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

// A font-size span for one emoji run (font-based rendering).
QString emojiFontSpan(const QString& emoji, int emojiPx)
{
    return QStringLiteral("<span style=\"font-size:%1px\">%2</span>").arg(emojiPx).arg(emoji);
}

// ── image-based emoji (Twemoji) — used when an emoji base url is supplied ────────

// Local path a url resolves to for an existence check (filesystem or bundled qrc:).
QString localPathForUrl(const QString& url)
{
    const QUrl u(url);
    if (u.scheme() == QLatin1String("qrc"))
        return QLatin1Char(':') + u.path();
    if (u.isLocalFile())
        return u.toLocalFile();
    return url;
}

// Maps a single emoji (one grapheme cluster) to its Twemoji svg url under `base`, following
// twemoji.js' rule (drop U+FE0F unless the cluster has a ZWJ; join code points as lowercase hex
// with '-'). "" when no svg exists. Mirrors chatinputhighlighter.cpp's twemojiSvgUrl.
QString twemojiSvgUrl(const QString& base, const QString& emoji)
{
    if (base.isEmpty())
        return {};
    const bool hasZwj = emoji.contains(QChar(0x200D));
    QString name;
    for (qsizetype i = 0; i < emoji.size();) {
        const QChar c = emoji[i];
        char32_t cp;
        if (c.isHighSurrogate() && i + 1 < emoji.size() && emoji[i + 1].isLowSurrogate()) {
            cp = QChar::surrogateToUcs4(c, emoji[i + 1]);
            i += 2;
        } else {
            cp = c.unicode();
            i += 1;
        }
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

// Renders an emoji run as Twemoji <img> tags: segmented per grapheme cluster so ZWJ sequences map
// to their combined svg and adjacent emoji each get their own image. Clusters without a Twemoji svg
// fall back to a font-size span.
QString emojiImagesHtml(const QString& run, int emojiPx, const QString& emojiBaseUrl)
{
    QString out;
    QTextBoundaryFinder bf(QTextBoundaryFinder::Grapheme, run);
    int cs = 0;
    for (int ce = bf.toNextBoundary(); ce >= 0; ce = bf.toNextBoundary()) {
        if (ce > cs) {
            const QString cluster = run.mid(cs, ce - cs);
            const QString url = twemojiSvgUrl(emojiBaseUrl, cluster);
            if (!url.isEmpty())
                out += QStringLiteral("<img src=\"%1\" width=\"%2\" height=\"%2\""
                                      " style=\"vertical-align:bottom\">").arg(url).arg(emojiPx);
            else
                out += emojiFontSpan(cluster, emojiPx);
        }
        cs = ce;
    }
    return out;
}

// Renders each run of emoji code points in `s` (already HTML-escaped). `emojiPx <= 0` leaves the
// string unchanged. When `emojiBaseUrl` is empty, each run is wrapped in a font-size span so the
// rich-text view enlarges them ~to the line height (font-based). When set, each emoji is emitted as
// a Twemoji <img>. Safe on escaped text: entities and <br/> are ASCII, never in the emoji ranges.
QString emojiWrap(const QString& s, int emojiPx, const QString& emojiBaseUrl)
{
    if (emojiPx <= 0)
        return s;

    const auto codePointAt = [&](int i, int& units) -> char32_t {
        if (s[i].isHighSurrogate() && i + 1 < s.size() && s[i + 1].isLowSurrogate()) {
            units = 2;
            return QChar::surrogateToUcs4(s[i], s[i + 1]);
        }
        units = 1;
        return s[i].unicode();
    };

    QString out;
    out.reserve(s.size());
    int i = 0;
    while (i < s.size()) {
        int units = 1;
        if (Markdown::isEmojiCodePoint(codePointAt(i, units))) {
            const int start = i;
            do { i += units; }
            while (i < s.size() && Markdown::isEmojiCodePoint(codePointAt(i, units)));
            const QString run = s.mid(start, i - start);
            out += emojiBaseUrl.isEmpty() ? emojiFontSpan(run, emojiPx)
                                          : emojiImagesHtml(run, emojiPx, emojiBaseUrl);
        } else {
            out += s.mid(i, units);
            i += units;
        }
    }
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
                       const QHash<int, QPair<QString, QString>>& mentions, int emojiPx, const QString& emojiBaseUrl);

// Inline code markup; `content` is already escaped.
QString codeSpanHtml(const QString& content)
{
    return QStringLiteral("<code>%1</code>").arg(content);
}

QString renderNode(const Node& node,
                   const QHash<int, QPair<QString, QString>>& mentions, int emojiPx, const QString& emojiBaseUrl)
{
    switch (node.kind) {
    case NodeKind::Delimiter:
        return {}; // formatting characters are never rendered

    case NodeKind::Text:
        return emojiWrap(escapeInline(node.literal), emojiPx, emojiBaseUrl);

    case NodeKind::Strong:
        return QStringLiteral("<b>%1</b>").arg(renderChildren(node, mentions, emojiPx, emojiBaseUrl));
    case NodeKind::Emphasis:
        return QStringLiteral("<i>%1</i>").arg(renderChildren(node, mentions, emojiPx, emojiBaseUrl));
    case NodeKind::Strikethrough:
        return QStringLiteral("<s>%1</s>").arg(renderChildren(node, mentions, emojiPx, emojiBaseUrl));

    case NodeKind::CodeSpan:
        return codeSpanHtml(collectCodeText(node));
    case NodeKind::CodeBlock:
        // Block element ⇒ its own paragraph (starts on a new line).
        return QStringLiteral("<pre>%1</pre>").arg(collectCodeText(node));

    case NodeKind::QuoteBlock:
        return QStringLiteral("<blockquote>%1</blockquote>")
                .arg(renderChildren(node, mentions, emojiPx, emojiBaseUrl));

    case NodeKind::Link:
        return QStringLiteral("<a href=\"%1\">%2</a>")
                .arg(escape(node.destination), renderChildren(node, mentions, emojiPx, emojiBaseUrl));

    case NodeKind::WalletLink:
        return QStringLiteral("<a href=\"%1%2\">%3</a>")
                .arg(kSendViaChatPrefix, escape(node.destination),
                     renderChildren(node, mentions, emojiPx, emojiBaseUrl));

    case NodeKind::Mention: {
        const auto it = mentions.constFind(static_cast<int>(node.start));
        const QString name = it != mentions.cend() ? it->first  : QStringLiteral("@mention");
        const QString href = it != mentions.cend() ? it->second : QString();
        // Background is applied by the consumer via an `a.mention { … }` CSS rule.
        return QStringLiteral("<a href=\"%1\" class=\"mention\">%2</a>")
                .arg(escape(href), escape(name));
    }

    case NodeKind::Document:
    case NodeKind::Paragraph:
        return renderChildren(node, mentions, emojiPx, emojiBaseUrl);
    }
    return {};
}

QString renderChildren(const Node& node,
                       const QHash<int, QPair<QString, QString>>& mentions, int emojiPx, const QString& emojiBaseUrl)
{
    QString out;
    for (const Node& c : node.children)
        out += renderNode(c, mentions, emojiPx, emojiBaseUrl);
    return out;
}

QString renderSingleLine(const Node& node,
                         const QHash<int, QPair<QString, QString>>& mentions, int emojiPx, const QString& emojiBaseUrl);

QString renderSingleLineChildren(const Node& node,
                                 const QHash<int, QPair<QString, QString>>& mentions, int emojiPx, const QString& emojiBaseUrl)
{
    QString out;
    for (const Node& c : node.children)
        out += renderSingleLine(c, mentions, emojiPx, emojiBaseUrl);
    return out;
}

// One-line rendering: newlines collapse to spaces, code fences render like inline code spans,
// and quote blocks become "> "-prefixed classed spans (colored by the consumer's span.quote
// rule). Inline formatting, links and mentions match renderNode. Used for compact previews.
QString renderSingleLine(const Node& node,
                         const QHash<int, QPair<QString, QString>>& mentions, int emojiPx, const QString& emojiBaseUrl)
{
    switch (node.kind) {
    case NodeKind::Delimiter:
        return {};

    case NodeKind::Text: {
        QString t = escape(node.literal);
        t.replace(QLatin1Char('\n'), QLatin1Char(' '));
        return emojiWrap(t, emojiPx, emojiBaseUrl);
    }

    case NodeKind::Strong:
        return QStringLiteral("<b>%1</b>").arg(renderSingleLineChildren(node, mentions, emojiPx, emojiBaseUrl));
    case NodeKind::Emphasis:
        return QStringLiteral("<i>%1</i>").arg(renderSingleLineChildren(node, mentions, emojiPx, emojiBaseUrl));
    case NodeKind::Strikethrough:
        return QStringLiteral("<s>%1</s>").arg(renderSingleLineChildren(node, mentions, emojiPx, emojiBaseUrl));

    case NodeKind::CodeSpan:
    case NodeKind::CodeBlock: {
        // A fenced code block is rendered like an inline code span on one line.
        QString c = collectCodeText(node);
        c.replace(QLatin1Char('\n'), QLatin1Char(' '));
        return codeSpanHtml(c.trimmed());
    }

    case NodeKind::QuoteBlock:
        return QStringLiteral("<span class=\"quote\">&gt; %1</span>")
                .arg(renderSingleLineChildren(node, mentions, emojiPx, emojiBaseUrl));

    case NodeKind::Link:
        return QStringLiteral("<a href=\"%1\">%2</a>")
                .arg(escape(node.destination), renderSingleLineChildren(node, mentions, emojiPx, emojiBaseUrl));

    case NodeKind::WalletLink:
        return QStringLiteral("<a href=\"%1%2\">%3</a>")
                .arg(kSendViaChatPrefix, escape(node.destination),
                     renderSingleLineChildren(node, mentions, emojiPx, emojiBaseUrl));

    case NodeKind::Mention: {
        const auto it = mentions.constFind(static_cast<int>(node.start));
        const QString name = it != mentions.cend() ? it->first  : QStringLiteral("@mention");
        const QString href = it != mentions.cend() ? it->second : QString();
        return QStringLiteral("<a href=\"%1\" class=\"mention\">%2</a>")
                .arg(escape(href), escape(name));
    }

    case NodeKind::Document:
    case NodeKind::Paragraph:
        return renderSingleLineChildren(node, mentions, emojiPx, emojiBaseUrl);
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
        return it != mentions.cend() ? it->first : QStringLiteral("@mention");
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
          const QHash<int, QPair<QString, QString>>& mentions, int emojiPx, const QString& emojiBaseUrl)
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
                    a.cur += wrapEmphasis(emojiWrap(escape(parts[i]), emojiPx, emojiBaseUrl), emph);
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
            walk(c.children, emph, inner, mentions, emojiPx, emojiBaseUrl);
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
            if (containsBlock(c) || containsCodeSpan(c)) {
                // Walk inline (shared accumulator) so a line straddling the emphasis
                // boundary assembles correctly, carrying the emphasis on the pieces.
                // Walking also routes a nested code span through the per-line CodeSpan
                // case, keeping its background line-local.
                walk(c.children, emph | emphasisBitFor(c.kind), a, mentions, emojiPx, emojiBaseUrl);
            } else {
                // inline emphasis (no block) — wrap in any active outer emphasis too
                a.cur += wrapEmphasis(renderNode(c, mentions, emojiPx, emojiBaseUrl), emph);
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
                    a.cur += wrapEmphasis(codeSpanHtml(parts[i]), emph);
                a.curStarted = true;
            }
            break;
        }

        default: // Link, Mention — inline leaves
            a.cur += wrapEmphasis(renderNode(c, mentions, emojiPx, emojiBaseUrl), emph);
            a.curStarted = true;
            break;
        }
    }
}

} // namespace

namespace Markdown {

QString toHtml(const Node& root, const QHash<int, QPair<QString, QString>>& mentions,
               int emojiPx, const QString& emojiBaseUrl)
{
    return renderNode(root, mentions, emojiPx, emojiBaseUrl);
}

QString toSingleLineHtml(const Node& root, const QHash<int, QPair<QString, QString>>& mentions,
                         int emojiPx, const QString& emojiBaseUrl)
{
    return renderSingleLine(root, mentions, emojiPx, emojiBaseUrl);
}

QString toPlainText(const Node& root, const QHash<int, QPair<QString, QString>>& mentions)
{
    return renderPlain(root, mentions);
}

QVariantList toBlocks(const Node& root,
                      const QHash<int, QPair<QString, QString>>& mentions, int emojiPx, const QString& emojiBaseUrl)
{
    // The document is Document > Paragraph > content; walk the paragraph's children.
    const QVector<Node>* content = &root.children;
    if (root.kind == NodeKind::Document && root.children.size() == 1
            && root.children.first().kind == NodeKind::Paragraph)
        content = &root.children.first().children;

    BlockAcc a;
    walk(*content, 0, a, mentions, emojiPx, emojiBaseUrl);
    if (a.curStarted)
        finalizeLine(a); // a trailing real line (incl. an empty delimiter/quoted line)
    flushTextBlock(a);
    return a.blocks;
}

} // namespace Markdown
