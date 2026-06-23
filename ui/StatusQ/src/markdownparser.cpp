#include "StatusQ/markdownparser.h"

#include <QRegularExpression>

#include <algorithm>

// ── Parsing primitives ────────────────────────────────────────────────────────
// Low-level scanners shared by the parser. These were originally inlined in
// ChatInputHighlighter; they are pure functions over QString and produce
// position-based intermediate results, later assembled into the AST.
namespace {

using namespace Markdown;

// Internal emphasis format bits (used only while pairing delimiters).
constexpr unsigned int kBold          = 1u << 0;
constexpr unsigned int kItalic        = 1u << 1;
constexpr unsigned int kStrikeThrough = 1u << 2;

struct Delimiter {
    qsizetype pos;
    qsizetype remaining;
    QChar ch;
    bool canOpen;
    bool canClose;
};

struct CodeSpan {
    qsizetype openerStart;   // start of opening backtick run
    qsizetype contentStart;  // end of opening backtick run = content start
    qsizetype contentEnd;    // start of closing backtick run = content end
    qsizetype closerEnd;     // end of closing backtick run
};

struct EmphSpan {
    qsizetype    start;        // content start (= opener delimiter end)
    qsizetype    end;          // content end   (= closer delimiter start)
    unsigned int formatBits;
    qsizetype    openerStart;  // start of consumed opener delimiter chars
    qsizetype    closerEnd;    // end   of consumed closer delimiter chars
};

struct LinkSpan {
    QString   url;
    qsizetype start;   // start of match in the scanned text
    qsizetype end;     // end of match (exclusive)
};

struct QuoteGroup {
    qsizetype start;   // absolute position of '>' on first line
    qsizetype end;     // exclusive end (past last char of last quote line, incl. trailing \n)
};

using Ranges = QVector<QPair<qsizetype,qsizetype>>;

const QRegularExpression& kLinkRegex()
{
    static const QRegularExpression re(
        QStringLiteral(R"(\bhttps?://[a-zA-Z0-9](?:[a-zA-Z0-9\-.]*[a-zA-Z0-9])?(?:/[^\s<>()\[\]{}'"]*)?(?<![.,;:!?*~]))"),
        QRegularExpression::CaseInsensitiveOption
    );
    return re;
}

QVector<LinkSpan> scanLinks(const QString& text, const Ranges& excludeRanges = {})
{
    QVector<LinkSpan> result;
    auto it = kLinkRegex().globalMatch(text);
    while (it.hasNext()) {
        const auto m = it.next();
        const qsizetype s = m.capturedStart(), e = m.capturedEnd();
        bool excluded = false;
        for (const auto& r : excludeRanges)
            if (s < r.second && e > r.first) { excluded = true; break; }
        if (!excluded)
            result.append({m.captured(), s, e});
    }
    return result;
}

Ranges linkRangesOf(const QVector<LinkSpan>& links)
{
    Ranges result;
    for (const auto& l : links)
        result.append({l.start, l.end});
    return result;
}

bool isUnicodeWhitespace(QChar c) { return c.isSpace(); }
bool isUnicodePunctuation(QChar c) { return c.isPunct() || c.isSymbol(); }

bool isLeftFlanking(const QString& text, qsizetype pos, qsizetype len)
{
    QChar charAfter  = (pos + len < text.length()) ? text[pos + len] : QChar(' ');
    QChar charBefore = (pos > 0)                   ? text[pos - 1]   : QChar(' ');
    if (!isUnicodePunctuation(charAfter))
        return true;
    return isUnicodeWhitespace(charBefore) || isUnicodePunctuation(charBefore);
}

bool isRightFlanking(const QString& text, qsizetype pos, qsizetype len)
{
    QChar charAfter  = (pos + len < text.length()) ? text[pos + len] : QChar(' ');
    QChar charBefore = (pos > 0)                   ? text[pos - 1]   : QChar(' ');
    if (!isUnicodePunctuation(charBefore))
        return true;
    return isUnicodeWhitespace(charAfter) || isUnicodePunctuation(charAfter);
}

QVector<Delimiter> scanDelimiters(const QString& text, const Ranges& codeRanges = {})
{
    QVector<Delimiter> delimiters;
    qsizetype i = 0;
    const qsizetype n = text.length();
    while (i < n) {
        for (const auto& r : codeRanges)
            if (i >= r.first && i < r.second) { i = r.second; break; }
        if (i >= n) break;

        QChar c = text[i];
        if (c == QLatin1Char('*')) {
            qsizetype start = i;
            while (i < n && text[i] == QLatin1Char('*'))
                ++i;
            qsizetype len = i - start;
            bool canOpen  = isLeftFlanking(text, start, len);
            bool canClose = isRightFlanking(text, start, len);
            delimiters.append({start, len, c, canOpen, canClose});
        } else if (c == QLatin1Char('~')) {
            qsizetype start = i;
            while (i < n && text[i] == QLatin1Char('~'))
                ++i;
            qsizetype len = i - start;
            if (len == 2) {
                bool canOpen  = isLeftFlanking(text, start, len);
                bool canClose = isRightFlanking(text, start, len);
                delimiters.append({start, 2, c, canOpen, canClose});
            }
        } else {
            ++i;
        }
    }
    return delimiters;
}

QVector<EmphSpan> processEmphasis(QVector<Delimiter> delimiters)
{
    QVector<EmphSpan> spans;

    qsizetype openers_bottom[2][3][2];
    for (int a = 0; a < 2; ++a)
        for (int b = 0; b < 3; ++b)
            for (int c2 = 0; c2 < 2; ++c2)
                openers_bottom[a][b][c2] = -1;

    auto chIndex = [](QChar ch) { return ch == QLatin1Char('*') ? 0 : 1; };

    qsizetype current = 0;
    while (current < delimiters.size()) {
        Delimiter& closer = delimiters[current];
        if (!closer.canClose) { ++current; continue; }

        int ci = chIndex(closer.ch);
        qsizetype bottom = openers_bottom[ci][closer.remaining % 3][closer.canOpen ? 1 : 0];

        qsizetype found = -1;
        for (qsizetype j = current - 1; j > bottom; --j) {
            const Delimiter& o = delimiters[j];
            if (!o.canOpen || o.ch != closer.ch)
                continue;
            if (o.canClose || closer.canOpen) {
                qsizetype sumMod3 = (o.remaining + closer.remaining) % 3;
                if (sumMod3 == 0 && (o.remaining % 3 != 0 || closer.remaining % 3 != 0))
                    continue;
            }
            found = j;
            break;
        }

        if (found == -1) {
            openers_bottom[ci][closer.remaining % 3][closer.canOpen ? 1 : 0] = current - 1;
            if (!closer.canOpen)
                delimiters.removeAt(current);
            else
                ++current;
            continue;
        }

        Delimiter& opener = delimiters[found];

        qsizetype useCount;
        if (opener.ch == QLatin1Char('~'))
            useCount = 2;
        else
            useCount = (opener.remaining >= 2 && closer.remaining >= 2) ? 2 : 1;

        unsigned int bits;
        if (opener.ch == QLatin1Char('~'))
            bits = kStrikeThrough;
        else if (useCount == 2)
            bits = kBold;
        else
            bits = kItalic;

        qsizetype contentStart     = opener.pos + opener.remaining;
        qsizetype contentEnd       = closer.pos;
        qsizetype openerDelimStart = contentStart - useCount;
        qsizetype closerDelimEnd   = contentEnd   + useCount;
        spans.append({contentStart, contentEnd, bits, openerDelimStart, closerDelimEnd});

        qsizetype removeFrom = found + 1;
        qsizetype removeTo   = current - 1;
        if (removeFrom <= removeTo)
            delimiters.erase(delimiters.begin() + removeFrom,
                             delimiters.begin() + removeTo + 1);
        current = found + 1;

        opener.remaining -= useCount;
        if (opener.remaining == 0) {
            delimiters.removeAt(found);
            --current;
        }

        Delimiter& closerRef = delimiters[current];
        closerRef.pos       += useCount;
        closerRef.remaining -= useCount;
        if (closerRef.remaining == 0)
            delimiters.removeAt(current);
    }

    return spans;
}

QVector<CodeSpan> scanCodeSpans(const QString& text)
{
    QVector<CodeSpan> result;
    qsizetype i = 0;
    const qsizetype len = text.length();
    while (i < len) {
        if (text[i] != QLatin1Char('`')) { ++i; continue; }
        qsizetype openerStart = i;
        while (i < len && text[i] == QLatin1Char('`')) ++i;
        qsizetype openerLen    = i - openerStart;
        qsizetype contentStart = i;

        qsizetype j = i;
        while (j < len) {
            if (text[j] != QLatin1Char('`')) { ++j; continue; }
            qsizetype closerStart = j;
            while (j < len && text[j] == QLatin1Char('`')) ++j;
            qsizetype closerLen = j - closerStart;
            if (closerLen == openerLen) {
                result.append({openerStart, contentStart, closerStart, j});
                i = j;
                break;
            }
        }
    }
    return result;
}

// Returns the start of the first triple-backtick run that has no matching closer,
// or -1 if all ``` openers are paired.
qsizetype findOpenCodeFence(const QString& text)
{
    qsizetype i = 0;
    const qsizetype len = text.length();
    while (i < len) {
        if (text[i] != QLatin1Char('`')) { ++i; continue; }
        const qsizetype runStart = i;
        while (i < len && text[i] == QLatin1Char('`')) ++i;
        if (i - runStart != 3) continue;
        qsizetype j = i;
        bool found = false;
        while (j < len) {
            if (text[j] != QLatin1Char('`')) { ++j; continue; }
            const qsizetype cs = j;
            while (j < len && text[j] == QLatin1Char('`')) ++j;
            if (j - cs == 3) { found = true; i = j; break; }
        }
        if (!found) return runStart;
    }
    return -1;
}

// Finds maximal runs of consecutive lines starting with "> ".
QVector<QuoteGroup> scanQuoteGroups(const QString& text, const Ranges& fenceRanges)
{
    QVector<QuoteGroup> groups;
    qsizetype i = 0;
    const qsizetype n = text.length();
    qsizetype groupStart = -1;

    while (i < n) {
        const qsizetype lineStart = i;
        while (i < n && text[i] != QLatin1Char('\n')) ++i;
        const qsizetype lineEnd = i;
        if (i < n) ++i;

        bool inFence = false;
        for (const auto& r : fenceRanges)
            if (r.first < lineStart && r.second > lineStart) { inFence = true; break; }

        const bool isQuote = !inFence
                          && lineEnd - lineStart >= 2
                          && text[lineStart] == QLatin1Char('>')
                          && text[lineStart + 1] == QLatin1Char(' ');

        if (isQuote) {
            if (groupStart < 0) groupStart = lineStart;
        } else if (groupStart >= 0) {
            groups.append({groupStart, lineStart});
            groupStart = -1;
        }
    }
    if (groupStart >= 0)
        groups.append({groupStart, n});

    return groups;
}

// True when the line containing `pos` starts with "> " (a quote line). Used to
// tell a standalone fence from one that opens inside a quote.
bool onQuoteLine(const QString& text, qsizetype pos)
{
    qsizetype ls = pos;
    while (ls > 0 && text[ls - 1] != QLatin1Char('\n')) --ls;
    return ls + 1 < text.length()
        && text[ls] == QLatin1Char('>') && text[ls + 1] == QLatin1Char(' ');
}

// Returns the absolute "> " prefix ranges (2 chars each) for every line in a group.
Ranges quoteGroupPrefixRanges(const QString& text, const QuoteGroup& g)
{
    Ranges result;
    qsizetype i = g.start;
    while (i < g.end) {
        result.append({i, i + 2});
        while (i < g.end && text[i] != QLatin1Char('\n')) ++i;
        if (i < g.end) ++i;
    }
    return result;
}

// ── AST assembly ──────────────────────────────────────────────────────────────

// A flat, properly-nested interval describing an inline construct, later
// materialized into a Node. Emphasis containers carry separate outer (incl.
// delimiters) and content ranges; leaf-like containers (Link, quote prefix
// Delimiter) have content == outer.
struct Container {
    NodeKind kind;
    qsizetype oS, oE;     // outer  [oS, oE)
    qsizetype cS, cE;     // content [cS, cE)
    QString destination;  // Link only
};

NodeKind kindFromBits(unsigned int bits)
{
    if (bits & kStrikeThrough) return NodeKind::Strikethrough;
    if (bits & kBold)          return NodeKind::Strong;
    return NodeKind::Emphasis;
}

Node leaf(NodeKind kind, const QString& full, qsizetype s, qsizetype e)
{
    Node n;
    n.kind = kind;
    n.start = s;
    n.end = e;
    n.literal = full.mid(s, e - s);
    return n;
}

QVector<Node> buildInline(const QString& full, qsizetype rs, qsizetype re,
                          const QVector<Container>& conts);

Node materialize(const QString& full, const Container& c, const QVector<Container>& conts)
{
    Node n;
    n.kind = c.kind;
    n.start = c.oS;
    n.end = c.oE;

    if (c.kind == NodeKind::Delimiter) {
        n.literal = full.mid(c.oS, c.oE - c.oS);
        return n;
    }

    if (c.kind == NodeKind::Link) {
        n.destination = c.destination;
        n.children.append(leaf(NodeKind::Text, full, c.oS, c.oE));
        return n;
    }

    // Emphasis (Strong / Emphasis / Strikethrough) and code (CodeSpan / CodeBlock):
    // opener/closer delimiters around content, with any contained containers nested.
    // For code, the content is not re-parsed for emphasis (inlineContainers excludes
    // code ranges from delimiter scanning), so `inner` holds only "> " prefixes —
    // letting a quoted code block keep its prefixes as Delimiter children. For
    // top-level code (empty conts) this yields a single Text child, as before.
    if (c.cS > c.oS)
        n.children.append(leaf(NodeKind::Delimiter, full, c.oS, c.cS));

    QVector<Container> inner;
    for (const auto& d : conts) {
        if (d.oS == c.oS && d.oE == c.oE)
            continue; // self
        if (d.oS >= c.cS && d.oE <= c.cE)
            inner.append(d);
    }
    n.children.append(buildInline(full, c.cS, c.cE, inner));

    if (c.oE > c.cE)
        n.children.append(leaf(NodeKind::Delimiter, full, c.cE, c.oE));
    return n;
}

// Builds inline nodes covering [rs, re): top-level containers in order,
// plain text for the gaps between/around them.
QVector<Node> buildInline(const QString& full, qsizetype rs, qsizetype re,
                          const QVector<Container>& conts)
{
    QVector<int> top;
    for (int i = 0; i < conts.size(); ++i) {
        bool contained = false;
        for (int j = 0; j < conts.size(); ++j) {
            if (i == j) continue;
            const auto& a = conts[i];
            const auto& b = conts[j];
            const bool same = (a.oS == b.oS && a.oE == b.oE);
            if (!same && b.oS <= a.oS && b.oE >= a.oE) { contained = true; break; }
        }
        if (!contained)
            top.append(i);
    }
    std::sort(top.begin(), top.end(),
              [&](int x, int y) { return conts[x].oS < conts[y].oS; });

    QVector<Node> out;
    qsizetype pos = rs;
    for (int idx : top) {
        const Container& c = conts[idx];
        if (c.oS > pos)
            out.append(leaf(NodeKind::Text, full, pos, c.oS));
        out.append(materialize(full, c, conts));
        pos = c.oE;
    }
    if (pos < re)
        out.append(leaf(NodeKind::Text, full, pos, re));
    return out;
}

// Computes the inline containers (emphasis, single-backtick code spans, links)
// for a region [rs, re), in absolute coordinates. `prefixExcludes` are absolute
// ranges (e.g. quote "> " prefixes) excluded from emphasis/link scanning.
// Emphasis/code/links may span multiple lines within the region.
QVector<Container> inlineContainers(const QString& full, qsizetype rs, qsizetype re,
                                    const Ranges& prefixExcludes,
                                    bool detectLinks)
{
    const QString region = full.mid(rs, re - rs);
    QVector<Container> conts;

    auto addCode = [&](const QVector<CodeSpan>& spans, qsizetype off) {
        for (const CodeSpan& c : spans) {
            const qsizetype blen = c.contentStart - c.openerStart;
            // single-backtick → inline CodeSpan; triple-backtick → CodeBlock
            // (the latter only occurs here in the quote path). Other lengths ignored.
            if (blen != 1 && blen != 3)
                continue;
            conts.append({blen == 1 ? NodeKind::CodeSpan : NodeKind::CodeBlock,
                          c.openerStart + off, c.closerEnd + off,
                          c.contentStart + off, c.contentEnd + off, {}});
        }
    };
    auto addLinks = [&](const QVector<LinkSpan>& links, qsizetype off) {
        for (const LinkSpan& l : links)
            conts.append({NodeKind::Link, l.start + off, l.end + off,
                          l.start + off, l.end + off, l.url});
    };
    auto addEmph = [&](const QVector<EmphSpan>& spans, qsizetype off) {
        for (const EmphSpan& s : spans)
            conts.append({kindFromBits(s.formatBits),
                          s.openerStart + off, s.closerEnd + off,
                          s.start + off, s.end + off, {}});
    };

    // prefix excludes converted to region-relative
    Ranges prefixRegion;
    for (const auto& r : prefixExcludes)
        prefixRegion.append({r.first - rs, r.second - rs});

    const QVector<CodeSpan> code = scanCodeSpans(region);
    Ranges codeRanges;
    for (const CodeSpan& c : code)
        codeRanges.append({c.openerStart, c.closerEnd});

    Ranges exclude = codeRanges;
    exclude += prefixRegion;
    const QVector<LinkSpan> links = detectLinks ? scanLinks(region, exclude)
                                                : QVector<LinkSpan>{};
    Ranges emphExclude = exclude;
    emphExclude += linkRangesOf(links);
    const QVector<EmphSpan> emph = processEmphasis(scanDelimiters(region, emphExclude));

    addCode(code, rs);
    addLinks(links, rs);
    addEmph(emph, rs);

    return conts;
}

Node makeCodeBlock(const QString& full, qsizetype oS, qsizetype cS,
                   qsizetype cE, qsizetype oE)
{
    Container c{NodeKind::CodeBlock, oS, oE, cS, cE, {}};
    return materialize(full, c, {});
}

Node makeQuoteBlock(const QString& full, const QuoteGroup& g, bool detectLinks)
{
    Node n;
    n.kind = NodeKind::QuoteBlock;
    n.start = g.start;
    n.end = g.end;

    const Ranges prefixes = quoteGroupPrefixRanges(full, g);
    QVector<Container> conts = inlineContainers(full, g.start, g.end, prefixes,
                                                detectLinks);
    // "> " prefixes are first-class Delimiter nodes.
    for (const auto& p : prefixes)
        conts.append({NodeKind::Delimiter, p.first, p.second, p.first, p.second, {}});

    n.children = buildInline(full, g.start, g.end, conts);
    return n;
}

Node makeParagraph(const QString& full, qsizetype s, qsizetype e, bool detectLinks)
{
    Node n;
    n.kind = NodeKind::Paragraph;
    n.start = s;
    n.end = e;
    QVector<Container> conts = inlineContainers(full, s, e, {}, detectLinks);
    n.children = buildInline(full, s, e, conts);
    return n;
}

} // namespace

namespace Markdown {

Node parse(const QString& text, const Options& options)
{
    Node doc;
    doc.kind = NodeKind::Document;
    doc.start = 0;
    doc.end = text.length();

    // Closed triple-backtick fences are NOT top-level blocks; they are handled
    // inline by inlineContainers (emitted as nested CodeBlock containers) so that
    // emphasis can span across them — identically at the top level and inside
    // quotes. Only "standalone" fences (those NOT opening on a "> " line) are
    // tracked here, so scanQuoteGroups keeps their "> " content lines from being
    // mistaken for quotes.
    const QVector<CodeSpan> allCodeSpans = scanCodeSpans(text);
    Ranges standaloneFenceRanges;
    for (const CodeSpan& c : allCodeSpans)
        if (c.contentStart - c.openerStart == 3 && !onQuoteLine(text, c.openerStart))
            standaloneFenceRanges.append({c.openerStart, c.closerEnd});
    const qsizetype unclosed = options.formatUnclosedCodeFence ? findOpenCodeFence(text) : -1;
    if (unclosed >= 0 && !onQuoteLine(text, unclosed))
        standaloneFenceRanges.append({unclosed, text.length()});

    // Quote groups (quote detection excludes lines inside a standalone fence).
    const QVector<QuoteGroup> quoteGroups = scanQuoteGroups(text, standaloneFenceRanges);
    Ranges quoteAbsRanges;
    for (const QuoteGroup& g : quoteGroups)
        quoteAbsRanges.append({g.start, g.end});

    auto insideQuote = [&](qsizetype pos) {
        for (const auto& r : quoteAbsRanges)
            if (pos >= r.first && pos < r.second) return true;
        return false;
    };

    // Collect top-level block intervals: the optional unclosed fence (which
    // consumes the rest of the document) and quote groups, in document order.
    // Closed fences are handled inline by inlineContainers, not here.
    struct Block { qsizetype s, e; int type; CodeSpan fence; QuoteGroup grp; };
    QVector<Block> blocks;
    if (unclosed >= 0 && !insideQuote(unclosed))
        blocks.append({unclosed, text.length(), 0,
                       {unclosed, unclosed + 3, text.length(), text.length()}, {}});
    for (const QuoteGroup& g : quoteGroups)
        blocks.append({g.start, g.end, 1, {}, g});
    std::sort(blocks.begin(), blocks.end(),
              [](const Block& a, const Block& b) { return a.s < b.s; });

    // Walk the document, emitting Paragraph nodes for the gaps between blocks.
    qsizetype pos = 0;
    for (const Block& b : blocks) {
        if (b.s > pos)
            doc.children.append(makeParagraph(text, pos, b.s, options.detectLinks));
        if (b.type == 0)
            doc.children.append(makeCodeBlock(text, b.fence.openerStart, b.fence.contentStart,
                                              b.fence.contentEnd, b.fence.closerEnd));
        else
            doc.children.append(makeQuoteBlock(text, b.grp, options.detectLinks));
        pos = b.e;
    }
    if (pos < text.length())
        doc.children.append(makeParagraph(text, pos, text.length(), options.detectLinks));

    return doc;
}

qsizetype findUnclosedCodeFence(const QString& text)
{
    return findOpenCodeFence(text);
}

} // namespace Markdown
