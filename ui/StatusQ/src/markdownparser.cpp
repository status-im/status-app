#include "StatusQ/markdownparser.h"

#include <QRegularExpression>

#include <algorithm>

// ── Parsing primitives ────────────────────────────────────────────────────────
// Low-level scanners shared by the parser. They are pure functions over QString
// and produce position-based intermediate results, later assembled into the AST.
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

// Inline-markup delimiter characters (emphasis *, strikethrough ~, code `). For emphasis
// flanking these count as word-like, not punctuation, so an emphasis run can hug an adjacent
// inline element instead of being blocked by its delimiter — e.g. **~~A~~**B, **`A`**B and
// B**```A```** all keep the outer bold.
bool isInlineMarkupChar(QChar c)
{
    return c == QLatin1Char('*') || c == QLatin1Char('~') || c == QLatin1Char('`');
}

// Punctuation for flanking purposes. Inline-markup delimiters (see above) and embedded
// objects (mentions, U+FFFC) count as word-like, not punctuation, so emphasis can hug them
// — e.g. **~~A~~**B and A**<mention>B** keep the outer bold.
bool isFlankingPunctuation(QChar c)
{
    return c != QChar::ObjectReplacementCharacter
            && !isInlineMarkupChar(c)
            && isUnicodePunctuation(c);
}

bool isLeftFlanking(const QString& text, qsizetype pos, qsizetype len)
{
    QChar charAfter  = (pos + len < text.length()) ? text[pos + len] : QChar(' ');
    QChar charBefore = (pos > 0)                   ? text[pos - 1]   : QChar(' ');
    if (!isFlankingPunctuation(charAfter))
        return true;
    return isUnicodeWhitespace(charBefore) || isFlankingPunctuation(charBefore);
}

bool isRightFlanking(const QString& text, qsizetype pos, qsizetype len)
{
    QChar charAfter  = (pos + len < text.length()) ? text[pos + len] : QChar(' ');
    QChar charBefore = (pos > 0)                   ? text[pos - 1]   : QChar(' ');
    if (!isFlankingPunctuation(charBefore))
        return true;
    return isUnicodeWhitespace(charAfter) || isFlankingPunctuation(charAfter);
}

QVector<Delimiter> scanDelimiters(const QString& text, const Ranges& excludeRanges = {})
{
    const qsizetype n = text.length();

    // Mark positions inside excluded (code / link / "> " prefix) ranges once, so the scan
    // skips them in O(1) instead of testing every range at every position.
    QVector<bool> excluded(n, false);
    for (const auto& r : excludeRanges)
        for (qsizetype k = qMax<qsizetype>(0, r.first); k < qMin(n, r.second); ++k)
            excluded[k] = true;

    QVector<Delimiter> delimiters;
    qsizetype i = 0;
    while (i < n) {
        if (excluded[i]) { ++i; continue; }

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

// Finds maximal runs of consecutive "> " lines, with a line-based, fence-aware
// state machine so the quote/fence containment rules hold:
//   - lines inside a *standalone* code fence (one opened on a non-"> " line) are
//     code content, not quote lines;
//   - a fence opened inside a quote is bounded by the quote: a non-"> " line ends
//     both the quote and that fence.
// (Modeled on the reference ChatInputMentions block state machine.)
//
// `formatUnclosedFence` controls the unclosed standalone case: a non-"> " line
// that opens a fence which never closes is only a real code block (suppressing
// following quotes) when unclosed fences are formatted; otherwise the ``` is plain
// text and must not swallow a following "> " line.
QVector<QuoteGroup> scanQuoteGroups(const QString& text, bool formatUnclosedFence)
{
    enum CodeState { NoCode, InCodeStandalone, InCodeInQuote };

    static const QString fence = QStringLiteral("```");

    QVector<QuoteGroup> groups;
    qsizetype i = 0;
    const qsizetype n = text.length();
    qsizetype groupStart = -1;
    CodeState state = NoCode;

    while (i < n) {
        const qsizetype lineStart = i;
        while (i < n && text[i] != QLatin1Char('\n')) ++i;
        const qsizetype lineEnd = i;
        if (i < n) ++i;

        const QString line = text.mid(lineStart, lineEnd - lineStart);
        const bool isQuote = line.startsWith(QStringLiteral("> "));
        const CodeState stateAtStart = state;

        if (state == NoCode) {
            // Walk ``` runs on this line; one without a closer on the same line
            // opens a fence. Inside a quote, start past the "> " prefix.
            qsizetype cursor = isQuote ? 2 : 0;
            while (true) {
                const qsizetype openPos = line.indexOf(fence, cursor);
                if (openPos < 0)
                    break;
                const qsizetype closePos = line.indexOf(fence, openPos + 3);
                if (closePos < 0) {
                    if (isQuote) {
                        state = InCodeInQuote;
                    } else {
                        // Standalone opener: only a real fence (suppressing quotes)
                        // if it closes later, or if unclosed fences are formatted.
                        const bool closesLater = text.indexOf(fence, i) >= 0;
                        if (closesLater || formatUnclosedFence)
                            state = InCodeStandalone;
                    }
                    break;
                }
                cursor = closePos + 3;
            }
        } else if (state == InCodeStandalone) {
            if (line.indexOf(fence) >= 0)
                state = NoCode; // a closing fence ends the standalone code block
        } else { // InCodeInQuote
            if (!isQuote)
                state = NoCode;                  // quote ended → the fence ends too
            else if (line.indexOf(fence, 2) >= 0)
                state = NoCode;                  // closing fence within the quote
        }

        // A "> " line inside a standalone code block is code content, not a quote.
        const bool realQuote = isQuote && stateAtStart != InCodeStandalone;

        if (realQuote) {
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
    QVector<Node> built;  // QuoteBlock only: pre-built children
};

NodeKind kindFromBits(unsigned int bits)
{
    if (bits & kStrikeThrough) return NodeKind::Strikethrough;
    if (bits & kBold)          return NodeKind::Strong;
    return NodeKind::Emphasis;
}

// Forward declaration — inlineContainers builds nested quote blocks eagerly,
// and makeQuoteBlock in turn calls inlineContainers (with quote detection off).
Node makeQuoteBlock(const QString& full, const QuoteGroup& g, bool detectLinks,
                    bool formatUnclosedFence);

Node leaf(NodeKind kind, const QString& full, qsizetype s, qsizetype e)
{
    Node n;
    n.kind = kind;
    n.start = s;
    n.end = e;
    n.literal = full.mid(s, e - s);
    return n;
}

// Appends plain content over [s, e) as Text leaves, splitting out each embedded
// ObjectReplacementCharacter (U+FFFC) as a one-char Mention leaf. Mentions are
// opaque to markdown — their metadata lives in the document char format.
void appendInline(QVector<Node>& out, const QString& full, qsizetype s, qsizetype e)
{
    qsizetype i = s;
    while (i < e) {
        if (full[i] == QChar::ObjectReplacementCharacter) {
            Node m;
            m.kind = NodeKind::Mention;
            m.start = i;
            m.end = i + 1;
            out.append(m);
            ++i;
        } else {
            qsizetype j = i;
            while (j < e && full[j] != QChar::ObjectReplacementCharacter)
                ++j;
            out.append(leaf(NodeKind::Text, full, i, j));
            i = j;
        }
    }
}

// Direct-children forest over the containers. They are properly nested (emphasis nests;
// code/link/quote ranges are mutually disjoint), so a single stack sweep gives each
// container its direct children in O(n log n) — replacing the previous O(n²) containment
// scans in buildInline/materialize.
struct ContainerTree {
    QVector<int> roots;                // top-level containers, ordered by start position
    QVector<QVector<int>> childrenOf;  // childrenOf[i] = direct children of container i
};

ContainerTree buildContainerTree(const QVector<Container>& conts)
{
    ContainerTree tree;
    tree.childrenOf.resize(conts.size());

    QVector<int> order(conts.size());
    for (int i = 0; i < conts.size(); ++i)
        order[i] = i;
    std::sort(order.begin(), order.end(), [&](int x, int y) {
        const Container& a = conts[x];
        const Container& b = conts[y];
        return a.oS != b.oS ? a.oS < b.oS : a.oE > b.oE; // outer/earlier container first
    });

    // The stack holds the chain of open ancestors; its top is the innermost container
    // still covering the one being visited.
    QVector<int> stack;
    for (int idx : std::as_const(order)) {
        const Container& c = conts[idx];
        while (!stack.isEmpty() && conts[stack.last()].oE <= c.oS)
            stack.removeLast();
        if (stack.isEmpty())
            tree.roots.append(idx);
        else
            tree.childrenOf[stack.last()].append(idx);
        stack.append(idx);
    }
    return tree;
}

QVector<Node> buildInlineChildren(const QString& full, qsizetype rs, qsizetype re,
                                  const QVector<int>& childIdx,
                                  const QVector<Container>& conts, const ContainerTree& tree);

Node materialize(const QString& full, int idx,
                 const QVector<Container>& conts, const ContainerTree& tree)
{
    const Container& c = conts[idx];
    Node n;
    n.kind = c.kind;
    n.start = c.oS;
    n.end = c.oE;

    if (c.kind == NodeKind::QuoteBlock) {
        n.children = c.built; // children built eagerly when the container was emitted
        return n;
    }

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
    // opener/closer delimiters around content, with any nested containers in between.
    // For code the content is not re-parsed for emphasis (inlineContainers excludes code
    // ranges from delimiter scanning), so the children hold only "> " prefixes — letting a
    // quoted code block keep its prefixes as Delimiter children. Top-level code has none,
    // yielding a single Text child, as before.
    if (c.cS > c.oS)
        n.children.append(leaf(NodeKind::Delimiter, full, c.oS, c.cS));
    n.children.append(buildInlineChildren(full, c.cS, c.cE, tree.childrenOf[idx], conts, tree));
    if (c.oE > c.cE)
        n.children.append(leaf(NodeKind::Delimiter, full, c.cE, c.oE));
    return n;
}

// Materializes `childIdx` (direct children, ordered by start) over [rs, re), filling the
// gaps between/around them with plain inline text.
QVector<Node> buildInlineChildren(const QString& full, qsizetype rs, qsizetype re,
                                  const QVector<int>& childIdx,
                                  const QVector<Container>& conts, const ContainerTree& tree)
{
    QVector<Node> out;
    qsizetype pos = rs;
    for (int idx : childIdx) {
        const Container& c = conts[idx];
        if (c.oS > pos)
            appendInline(out, full, pos, c.oS);
        out.append(materialize(full, idx, conts, tree));
        pos = c.oE;
    }
    if (pos < re)
        appendInline(out, full, pos, re);
    return out;
}

// Builds inline nodes covering [rs, re) from the flat container list.
QVector<Node> buildInline(const QString& full, qsizetype rs, qsizetype re,
                          const QVector<Container>& conts)
{
    const ContainerTree tree = buildContainerTree(conts);
    return buildInlineChildren(full, rs, re, tree.roots, conts, tree);
}

// Computes the inline containers (emphasis, code spans/blocks, quote blocks,
// links) for a region [rs, re), in absolute coordinates. `prefixExcludes` are
// absolute ranges (e.g. quote "> " prefixes) excluded from emphasis/link scanning.
// When `detectQuotes` is true, quote groups in the region become nested QuoteBlock
// containers (built eagerly) and are excluded from emphasis — so emphasis spans
// across them. It is false while parsing a quote's own content (no nested quotes).
// Emphasis/code/quotes/links may span multiple lines within the region.
QVector<Container> inlineContainers(const QString& full, qsizetype rs, qsizetype re,
                                    const Ranges& prefixExcludes,
                                    bool detectLinks, bool detectQuotes,
                                    bool formatUnclosedFence)
{
    const QString region = full.mid(rs, re - rs);
    const qsizetype regionLen = region.length();
    QVector<Container> conts;

    auto addCode = [&](const QVector<CodeSpan>& spans, qsizetype off) {
        for (const CodeSpan& c : spans) {
            const qsizetype blen = c.contentStart - c.openerStart;
            // single-backtick → inline CodeSpan; triple-backtick → CodeBlock.
            // Other lengths ignored.
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

    // Quote groups (region-relative), each built eagerly as a nested QuoteBlock.
    Ranges quoteRanges;
    if (detectQuotes) {
        for (const QuoteGroup& g : scanQuoteGroups(region, formatUnclosedFence)) {
            Node qb = makeQuoteBlock(full, {rs + g.start, rs + g.end}, detectLinks,
                                     formatUnclosedFence);
            conts.append({NodeKind::QuoteBlock, rs + g.start, rs + g.end,
                          rs + g.start, rs + g.end, {}, qb.children});
            quoteRanges.append({g.start, g.end});
        }
    }

    // Code fences/spans are scanned per "gap" (region minus quote ranges) so a
    // fence never pairs across a quote boundary. An unclosed fence (when enabled)
    // is bounded by the gap end. Quote ranges come back sorted from scanQuoteGroups.
    Ranges codeRanges;
    qsizetype cursor = 0;
    auto scanGap = [&](qsizetype gs, qsizetype ge) {
        if (gs >= ge)
            return;
        const QString gap = region.mid(gs, ge - gs);
        const QVector<CodeSpan> spans = scanCodeSpans(gap);
        for (const CodeSpan& c : spans)
            codeRanges.append({gs + c.openerStart, gs + c.closerEnd});
        addCode(spans, rs + gs);
        if (formatUnclosedFence) {
            const qsizetype u = findOpenCodeFence(gap);
            if (u >= 0) {
                conts.append({NodeKind::CodeBlock, rs + gs + u, rs + ge,
                              rs + gs + u + 3, rs + ge, {}});
                codeRanges.append({gs + u, ge});
            }
        }
    };
    for (const auto& q : quoteRanges) {
        scanGap(cursor, q.first);
        cursor = q.second;
    }
    scanGap(cursor, regionLen);

    Ranges exclude = codeRanges;
    exclude += prefixRegion;
    exclude += quoteRanges;
    const QVector<LinkSpan> links = detectLinks ? scanLinks(region, exclude)
                                                : QVector<LinkSpan>{};
    Ranges emphExclude = exclude;
    emphExclude += linkRangesOf(links);
    const QVector<EmphSpan> emph = processEmphasis(scanDelimiters(region, emphExclude));

    addLinks(links, rs);
    addEmph(emph, rs);

    return conts;
}

Node makeQuoteBlock(const QString& full, const QuoteGroup& g, bool detectLinks,
                    bool formatUnclosedFence)
{
    Node n;
    n.kind = NodeKind::QuoteBlock;
    n.start = g.start;
    n.end = g.end;

    const Ranges prefixes = quoteGroupPrefixRanges(full, g);
    // detectQuotes=false: a quote's own content is not re-scanned for nested quotes.
    QVector<Container> conts = inlineContainers(full, g.start, g.end, prefixes,
                                                detectLinks, /*detectQuotes=*/false,
                                                formatUnclosedFence);
    // "> " prefixes are first-class Delimiter nodes.
    for (const auto& p : prefixes)
        conts.append({NodeKind::Delimiter, p.first, p.second, p.first, p.second, {}});

    n.children = buildInline(full, g.start, g.end, conts);
    return n;
}

Node makeParagraph(const QString& full, qsizetype s, qsizetype e, bool detectLinks,
                   bool formatUnclosedFence)
{
    Node n;
    n.kind = NodeKind::Paragraph;
    n.start = s;
    n.end = e;
    QVector<Container> conts = inlineContainers(full, s, e, {}, detectLinks,
                                                /*detectQuotes=*/true, formatUnclosedFence);
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

    // The whole document is one Paragraph region. Quote groups and code fences
    // (including unclosed ones) are detected and scoped within it by
    // inlineContainers, so emphasis can span across them and fences can't pair
    // across a quote boundary.
    if (text.length() > 0)
        doc.children.append(makeParagraph(text, 0, text.length(), options.detectLinks,
                                          options.formatUnclosedCodeFence));

    return doc;
}

qsizetype findUnclosedCodeFence(const QString& text)
{
    return findOpenCodeFence(text);
}

} // namespace Markdown
