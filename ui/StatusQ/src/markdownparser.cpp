#include "StatusQ/markdownparser.h"

#include <QHash>
#include <QRegularExpression>

#include <algorithm>

using namespace Qt::Literals::StringLiterals;

// ── Parsing primitives ────────────────────────────────────────────────────────
// Low-level scanners shared by the parser. They are pure functions over QString
// and produce position-based intermediate results, later assembled into the AST.
namespace {

using namespace Markdown;

// Internal emphasis format bits (used only while pairing delimiters).
constexpr unsigned int kBold          = 1u << 0;
constexpr unsigned int kItalic        = 1u << 1;
constexpr unsigned int kStrikeThrough = 1u << 2;

constexpr auto kBacktick = '`'_L1;
constexpr auto kTilde = '~'_L1;
constexpr auto kAsterisk = '*'_L1;

struct Delimiter {
    qsizetype pos;
    qsizetype remaining;
    QChar ch;
    bool canOpen;
    bool canClose;
    qsizetype previous = -1;
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
    qsizetype start;       // start of match in the scanned text
    qsizetype end;         // end of match (exclusive)
    qsizetype labelStart;  // label (display text) start; == start for auto-detected links
    qsizetype labelEnd;    // label (display text) end;   == end   for auto-detected links
    NodeKind  kind = NodeKind::Link; // Link for URLs, WalletLink for addresses/ENS names
};

struct QuoteGroup {
    qsizetype start;   // absolute position of '>' on first line
    qsizetype end;     // exclusive end (past last char of last quote line, incl. trailing \n)
};

using Ranges = QVector<QPair<qsizetype,qsizetype>>;

// Coalesce exclusions so overlap checks can use a binary search and scanners can
// skip whole ranges, even when code, links and quote prefixes arrive out of order.
Ranges mergedRanges(Ranges ranges)
{
    std::sort(ranges.begin(), ranges.end());
    qsizetype count = 0;
    for (const auto& range : std::as_const(ranges)) {
        if (count > 0 && range.first <= ranges[count - 1].second)
            ranges[count - 1].second = qMax(ranges[count - 1].second, range.second);
        else
            ranges[count++] = range;
    }
    ranges.resize(count);
    return ranges;
}

bool overlapsRange(const Ranges& ranges, qsizetype start, qsizetype end)
{
    const auto it = std::lower_bound(ranges.cbegin(), ranges.cend(), start,
                                    [](const auto& range, qsizetype pos) {
        return range.second <= pos;
    });
    return it != ranges.cend() && it->first < end;
}

const QRegularExpression& kLinkRegex()
{
    static const QRegularExpression re(
        QStringLiteral(R"(\b(?:https?://[a-zA-Z0-9](?:[a-zA-Z0-9\-.]*[a-zA-Z0-9])?(?:/[^\s<>()\[\]{}'"]*)?|status-app://[a-zA-Z0-9][^\s<>()\[\]{}'"]*)(?<![.,;:!?*~]))"),
        QRegularExpression::CaseInsensitiveOption
    );
    return re;
}

// Wallet address: "0x" + exactly 40 hex chars. Rejects shorter/longer runs and non-hex.
const QRegularExpression& kAddressRegex()
{
    static const QRegularExpression re(
        QStringLiteral(R"(\b0x[a-fA-F0-9]{40}\b)"),
        QRegularExpression::CaseInsensitiveOption
    );
    return re;
}

// ENS name: one or more dot-separated labels ending in ".eth", not followed by another
// label (so "bob.eth.invalid" and "invalid.ethaddress" are rejected).
const QRegularExpression& kEnsRegex()
{
    static const QRegularExpression re(
        QStringLiteral(R"(\b[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.eth\b(?!\.\w))"),
        QRegularExpression::CaseInsensitiveOption
    );
    return re;
}

Ranges linkRangesOf(const QVector<LinkSpan>& links)
{
    Ranges result;
    result.reserve(links.size());
    for (const auto& l : links)
        result.append({l.start, l.end});
    return result;
}

// Locates the "[label](" prefix of an explicit link. The label allows any run without brackets or
// newlines (formatting inside it is ignored by the parser). Capture group 1 is the label.
const QRegularExpression& kExplicitLinkLabelRegex()
{
    static const QRegularExpression re(QStringLiteral(R"(\[([^\[\]\n]*)\]\()"));
    return re;
}

// Explicit markdown links: "[label](url)". The label is the display text; the url must satisfy the
// same supported-scheme rule as auto-detected links (kLinkRegex), so "[a](foo)" stays literal text. Each
// span covers the whole "[label](url)" with the label range carried separately (labelStart/End) so
// the AST can show the label while linking to the url.
QVector<LinkSpan> scanExplicitLinks(QStringView text, const Ranges& urls)
{
    QVector<LinkSpan> result;
    qsizetype consumedUntil = 0; // avoid overlapping matches inside an accepted link
    qsizetype urlIndex = 0;
    auto it = kExplicitLinkLabelRegex().globalMatchView(text);
    while (it.hasNext()) {
        const auto m = it.next();
        if (m.capturedStart() < consumedUntil)
            continue;
        const qsizetype labelStart = m.capturedStart(1);
        const qsizetype labelEnd   = m.capturedEnd(1);
        const qsizetype urlStart   = m.capturedEnd(); // just past '('

        // Reuse the ordered URL matches instead of re-running the regex (and UTF-16
        // validation of the whole subject) for every explicit link.
        while (urlIndex < urls.size() && urls[urlIndex].first < urlStart)
            ++urlIndex;
        if (urlIndex == urls.size() || urls[urlIndex].first != urlStart)
            continue;
        const qsizetype urlEnd = urls[urlIndex].second;
        if (urlEnd >= text.length() || text[urlEnd] != QLatin1Char(')'))
            continue;

        const qsizetype start = m.capturedStart(); // '['
        const qsizetype end   = urlEnd + 1;        // just past ')'
        result.append({text.sliced(urlStart, urlEnd - urlStart).toString(),
                       start, end, labelStart, labelEnd, NodeKind::Link});
        consumedUntil = end;
    }
    return result;
}

QVector<LinkSpan> scanLinks(QStringView text, const Ranges& excludeRanges = {})
{
    QVector<LinkSpan> result;

    const Ranges excluded = mergedRanges(excludeRanges);
    Ranges urls;
    auto it = kLinkRegex().globalMatchView(text);
    while (it.hasNext()) {
        const auto m = it.next();
        urls.append({m.capturedStart(), m.capturedEnd()});
    }

    // Explicit [label](url) links first — they take precedence; their whole span is excluded from
    // the auto URL / wallet / ENS scans below so the inner url isn't linkified twice.
    for (const LinkSpan& l : scanExplicitLinks(text, urls))
        if (!overlapsRange(excluded, l.start, l.end))
            result.append(l);

    // Auto-detected URLs — excluded from code/quote (excludeRanges) and from the explicit-link
    // spans just collected. They win over addresses/ENS that would otherwise match inside a URL.
    Ranges used = excluded;
    used += linkRangesOf(result);
    used = mergedRanges(std::move(used));
    for (const auto& url : std::as_const(urls)) {
        const qsizetype s = url.first, e = url.second;
        if (!overlapsRange(used, s, e))
            result.append({text.sliced(s, e - s).toString(), s, e, s, e, NodeKind::Link});
    }

    // Wallet addresses / ENS names → send-via-personal-chat links. Excluded from code/quote, from
    // explicit links, and from the URL ranges collected above, so an address inside a URL or an
    // explicit link is not linkified twice.
    used = excluded;
    used += linkRangesOf(result);
    used = mergedRanges(std::move(used));
    const auto scanWalletLinks = [&](const QRegularExpression& re) {
        auto wit = re.globalMatchView(text);
        while (wit.hasNext()) {
            const auto m = wit.next();
            const qsizetype s = m.capturedStart(), e = m.capturedEnd();
            if (!overlapsRange(used, s, e))
                result.append({m.captured(), s, e, s, e, NodeKind::WalletLink});
        }
    };
    scanWalletLinks(kAddressRegex());
    scanWalletLinks(kEnsRegex());

    return result;
}

// A textual mention: "@" + a public key (or system-tag id). `pubKey` is the id without the "@".
struct MentionSpan {
    qsizetype start;   // position of '@'
    qsizetype end;     // exclusive end
    QString   pubKey;  // e.g. "0x04ab…" (uncompressed) or "0x00001" (everyone)
};

// Mention grammar, ported verbatim from status-go's markdown parser (status-im/markdown).
// Two forms are recognised (compressed @z… is intentionally out of scope):
//  - uncompressed public key: "@0x" + exactly 130 lowercase-hex chars,
//  - system tag:              "@0x" + exactly 5 digits, last digit != '0' (only 0x00001 =
//     "everyone" is meaningful).
// Either must be followed by end-of-text or a terminating char. The "@" itself may appear
// anywhere (no left-boundary requirement), matching status-go.
// TODO:
//  - improve the grammar to allow compressed mentions (z-base-32) (if needed)
//  - improve detection (e.g. when no delimiter on the right side)
constexpr qsizetype kPubKeyLen = 132;        // "0x" + 130 hex
constexpr qsizetype kSystemTagLen = 7;       // "0x" + 5 digits

constexpr bool isMentionHexChar(QChar c) { return (c >= '0'_L1 && c <= '9'_L1) || (c >= 'a'_L1 && c <= 'f'_L1); }
constexpr bool isMentionDigit(QChar c)   { return c >= '0'_L1 && c <= '9'_L1; }

// end-of-text or one of the status-go terminators.
constexpr bool isTerminatingMentionChar(QStringView text, qsizetype i)
{
    if (i >= text.length())
        return true;
    const QChar c = text[i];
    return c.isSpace() || c == QLatin1Char('.') || c == QLatin1Char(',')
        || c == QLatin1Char(':') || c == QLatin1Char(';') || c == QLatin1Char('!')
        || c == QLatin1Char('?');
}

// Tries to match a mention starting at the '@' at `at`. Returns the exclusive end (> at) and
// fills `pubKey` on success; returns -1 on no match.
constexpr qsizetype matchMention(QStringView text, qsizetype at, QString& pubKey)
{
    const qsizetype n = text.length() - at; // chars available from '@' inclusive

    // Uncompressed public key: "@0x" + 130 hex.
    if (n >= kPubKeyLen + 1 && text[at + 1] == QLatin1Char('0') && text[at + 2] == QLatin1Char('x')) {
        bool ok = true;
        for (qsizetype i = 3; i <= kPubKeyLen; ++i)
            if (!isMentionHexChar(text[at + i])) { ok = false; break; }
        if (ok && isTerminatingMentionChar(text, at + kPubKeyLen + 1)) {
            pubKey = text.sliced(at + 1, kPubKeyLen).toString();
            return at + kPubKeyLen + 1;
        }
    }

    // System tag: "@0x" + 5 digits, last digit != '0'.
    if (n >= kSystemTagLen + 1 && text[at + 1] == QLatin1Char('0') && text[at + 2] == QLatin1Char('x')
            && text[at + kSystemTagLen] != QLatin1Char('0')) {
        bool ok = true;
        for (qsizetype i = 3; i <= kSystemTagLen; ++i)
            if (!isMentionDigit(text[at + i])) { ok = false; break; }
        if (ok && isTerminatingMentionChar(text, at + kSystemTagLen + 1)) {
            pubKey = text.sliced(at + 1, kSystemTagLen).toString();
            return at + kSystemTagLen + 1;
        }
    }

    return -1;
}

QVector<MentionSpan> scanMentions(QStringView text, const Ranges& excludeRanges = {})
{
    QVector<MentionSpan> result;
    const Ranges excluded = mergedRanges(excludeRanges);
    const qsizetype n = text.length();
    for (qsizetype i = 0; i < n; ++i) {
        if (text[i] != QLatin1Char('@'))
            continue;
        QString pubKey;
        const qsizetype end = matchMention(text, i, pubKey);
        if (end < 0)
            continue;
        if (!overlapsRange(excluded, i, end)) {
            result.append({i, end, pubKey});
            i = end - 1; // skip past the consumed mention
        }
    }
    return result;
}

Ranges mentionRangesOf(const QVector<MentionSpan>& mentions)
{
    Ranges result;
    result.reserve(mentions.size());
    for (const auto& m : mentions)
        result.append({m.start, m.end});
    return result;
}

constexpr bool isUnicodeWhitespace(QChar c) { return c.isSpace(); }
bool isUnicodePunctuation(QChar c) { return c.isPunct() || c.isSymbol(); }

// Inline-markup delimiter characters (emphasis *, strikethrough ~, code `). For emphasis
// flanking these count as word-like, not punctuation, so an emphasis run can hug an adjacent
// inline element instead of being blocked by its delimiter — e.g. **~~A~~**B, **`A`**B and
// B**```A```** all keep the outer bold.
constexpr bool isInlineMarkupChar(QChar c)
{
    return c == kAsterisk || c == kTilde || c == kBacktick;
}

// Punctuation for flanking purposes. Inline-markup delimiters (see above) and embedded
// objects (mentions, U+FFFC) count as word-like, not punctuation, so emphasis can hug them
// — e.g. **~~A~~**B and A**<mention>B** keep the outer bold.
constexpr bool isFlankingPunctuation(QChar c)
{
    return c != QChar::ObjectReplacementCharacter
            && !isInlineMarkupChar(c)
            && isUnicodePunctuation(c);
}

constexpr bool isLeftFlanking(QStringView text, qsizetype pos, qsizetype len)
{
    QChar charAfter  = (pos + len < text.length()) ? text[pos + len] : ' '_L1;
    QChar charBefore = (pos > 0)                   ? text[pos - 1]   : ' '_L1;
    if (!isFlankingPunctuation(charAfter))
        return true;
    return isUnicodeWhitespace(charBefore) || isFlankingPunctuation(charBefore);
}

constexpr bool isRightFlanking(QStringView text, qsizetype pos, qsizetype len)
{
    QChar charAfter  = (pos + len < text.length()) ? text[pos + len] : ' '_L1;
    QChar charBefore = (pos > 0)                   ? text[pos - 1]   : ' '_L1;
    if (!isFlankingPunctuation(charBefore))
        return true;
    return isUnicodeWhitespace(charAfter) || isFlankingPunctuation(charAfter);
}

QVector<Delimiter> scanDelimiters(QStringView text, const Ranges& excludeRanges = {})
{
    const qsizetype n = text.length();

    const Ranges excluded = mergedRanges(excludeRanges);
    qsizetype rangeIndex = 0;

    QVector<Delimiter> delimiters;
    qsizetype i = 0;
    while (i < n) {
        if (rangeIndex < excluded.size() && i >= excluded[rangeIndex].first) {
            i = qMax(i, excluded[rangeIndex].second);
            ++rangeIndex;
            continue;
        }

        QChar c = text[i];
        if (c == kAsterisk) {
            qsizetype start = i;
            while (i < n && text[i] == kAsterisk)
                ++i;
            qsizetype len = i - start;
            bool canOpen  = isLeftFlanking(text, start, len);
            bool canClose = isRightFlanking(text, start, len);
            delimiters.append({start, len, c, canOpen, canClose});
        } else if (c == kTilde) {
            qsizetype start = i;
            while (i < n && text[i] == kTilde)
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
    for (qsizetype i = 0; i < delimiters.size(); ++i)
        delimiters[i].previous = i - 1;

    qsizetype openers_bottom[2][3][2];
    for (int a = 0; a < 2; ++a)
        for (int b = 0; b < 3; ++b)
            for (int c2 = 0; c2 < 2; ++c2)
                openers_bottom[a][b][c2] = -1;

    constexpr auto chIndex = [](QChar ch) { return ch == kAsterisk ? 0 : 1; };

    // Stable backward links avoid moving the vector's tail for every consumed delimiter.
    // Processing advances monotonically, so the next live delimiter is always current + 1.
    // Keep the live-list rank separately: opener bottoms use the compacted ranks
    // of the original algorithm, not the stable storage indices.
    qsizetype current = 0;
    qsizetype currentRank = 0;
    while (current < delimiters.size()) {
        Delimiter& closer = delimiters[current];
        if (!closer.canClose) {
            ++current;
            ++currentRank;
            continue;
        }

        int ci = chIndex(closer.ch);
        qsizetype bottom = openers_bottom[ci][closer.remaining % 3][closer.canOpen ? 1 : 0];

        qsizetype found = -1;
        qsizetype foundRank = currentRank - 1;
        for (qsizetype j = closer.previous; j >= 0 && foundRank > bottom;
             j = delimiters[j].previous, --foundRank) {
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
            openers_bottom[ci][closer.remaining % 3][closer.canOpen ? 1 : 0] = currentRank - 1;
            if (!closer.canOpen) {
                if (current + 1 < delimiters.size())
                    delimiters[current + 1].previous = closer.previous;
            } else {
                ++currentRank;
            }
            ++current;
            continue;
        }

        Delimiter& opener = delimiters[found];

        qsizetype useCount;
        if (opener.ch == kTilde)
            useCount = 2;
        else
            useCount = (opener.remaining >= 2 && closer.remaining >= 2) ? 2 : 1;

        unsigned int bits;
        if (opener.ch == kTilde)
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

        closer.previous = found;
        currentRank = foundRank + 1;

        opener.remaining -= useCount;
        if (opener.remaining == 0) {
            closer.previous = opener.previous;
            --currentRank;
        }

        closer.pos       += useCount;
        closer.remaining -= useCount;
        if (closer.remaining == 0) {
            if (current + 1 < delimiters.size())
                delimiters[current + 1].previous = closer.previous;
            ++current;
        }
    }

    return spans;
}

void appendIndexedCodeSpans(QStringView text, qsizetype start, QVector<CodeSpan>& result)
{
    struct BacktickRun {
        qsizetype start;
        qsizetype end;
        qsizetype next = -1;
    };

    QVector<BacktickRun> runs;
    for (qsizetype i = start; i < text.size();) {
        if (text[i] != kBacktick) {
            ++i;
            continue;
        }
        const qsizetype start = i;
        while (i < text.size() && text[i] == kBacktick)
            ++i;
        runs.append({start, i});
    }

    // Index the next run of each length once. Single/triple runs are the common
    // case and need no hash entry; other lengths still participate in pairing.
    qsizetype nextSingle = -1;
    qsizetype nextTriple = -1;
    QHash<qsizetype, qsizetype> nextOther;
    for (qsizetype i = runs.size(); i-- > 0;) {
        BacktickRun& run = runs[i];
        const qsizetype length = run.end - run.start;
        if (length == 1) {
            run.next = nextSingle;
            nextSingle = i;
        } else if (length == 3) {
            run.next = nextTriple;
            nextTriple = i;
        } else {
            const auto it = nextOther.constFind(length);
            if (it != nextOther.cend())
                run.next = it.value();
            nextOther.insert(length, i);
        }
    }

    for (qsizetype i = 0; i < runs.size();) {
        const BacktickRun& opener = runs[i];
        if (opener.next < 0) {
            ++i;
            continue;
        }
        const BacktickRun& closer = runs[opener.next];
        result.append({opener.start, opener.end, closer.start, closer.end});
        i = opener.next + 1;
    }
}

QVector<CodeSpan> scanCodeSpans(QStringView text)
{
    QVector<CodeSpan> result;
    qsizetype i = 0;
    while (i < text.size()) {
        if (text[i] != kBacktick) {
            ++i;
            continue;
        }
        const qsizetype openerStart = i;
        while (i < text.size() && text[i] == kBacktick)
            ++i;
        const qsizetype contentStart = i;

        qsizetype j = i;
        while (j < text.size() && text[j] != kBacktick)
            ++j;
        if (j == text.size())
            break;
        const qsizetype closerStart = j;
        while (j < text.size() && text[j] == kBacktick)
            ++j;
        if (j - closerStart != contentStart - openerStart) {
            // Adjacent matching runs need only a streaming scan. Once different
            // lengths intervene, index the remaining suffix to avoid rescanning it.
            appendIndexedCodeSpans(text, openerStart, result);
            break;
        }
        result.append({openerStart, contentStart, closerStart, j});
        i = j;
    }
    return result;
}

// Returns the start of the first triple-backtick run that has no matching closer,
// or -1 if all ``` openers are paired.
constexpr qsizetype findOpenCodeFence(QStringView text)
{
    qsizetype i = 0;
    const qsizetype len = text.length();
    qsizetype opener = -1;
    while (i < len) {
        if (text[i] != kBacktick) { ++i; continue; }
        const qsizetype runStart = i;
        while (i < len && text[i] == kBacktick) ++i;
        if (i - runStart != 3) continue;
        opener = opener < 0 ? runStart : -1;
    }
    return opener;
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
QVector<QuoteGroup> scanQuoteGroups(QStringView text, bool formatUnclosedFence)
{
    enum CodeState { NoCode, InCodeStandalone, InCodeInQuote };

    constexpr auto fence = "```"_L1;

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

        const QStringView line = text.sliced(lineStart, lineEnd - lineStart);
        const bool isQuote = line.startsWith("> "_L1);
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

constexpr NodeKind kindFromBits(unsigned int bits)
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

    if (c.kind == NodeKind::Link || c.kind == NodeKind::WalletLink) {
        n.destination = c.destination;
        if (c.cS == c.oS && c.cE == c.oE) {
            // Auto-detected link (content == outer): a single Text child = the whole match.
            n.children.reserve(1);
            n.children.append(leaf(NodeKind::Text, full, c.oS, c.oE));
        } else {
            n.children.reserve(3);
            // Explicit [label](url): '[' delimiter, the raw label (excluded from scanning, so no
            // nested formatting), then the '](url)' delimiter. Static renderers skip delimiters,
            // yielding <a href="url">label</a>; the editor dims them.
            if (c.cS > c.oS)
                n.children.append(leaf(NodeKind::Delimiter, full, c.oS, c.cS));
            n.children.append(buildInlineChildren(full, c.cS, c.cE, tree.childrenOf[idx], conts, tree));
            if (c.oE > c.cE)
                n.children.append(leaf(NodeKind::Delimiter, full, c.cE, c.oE));
        }
        return n;
    }

    if (c.kind == NodeKind::Mention) {
        // Textual mention ("@0x…"): a leaf carrying the pub key; the "@…" text is not emitted
        // as a child (the renderer resolves a display name from the pub key).
        n.destination = c.destination;
        return n;
    }

    // Emphasis (Strong / Emphasis / Strikethrough) and code (CodeSpan / CodeBlock):
    // opener/closer delimiters around content, with any nested containers in between.
    // For code the content is not re-parsed for emphasis (inlineContainers excludes code
    // ranges from delimiter scanning), so the children hold only "> " prefixes — letting a
    // quoted code block keep its prefixes as Delimiter children. Top-level code has none,
    // yielding a single Text child, as before.
    n.children.reserve(3);
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
    const QStringView region = QStringView(full).sliced(rs, re - rs);
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
        // content range = label; for auto-detected links label == whole match. materialize()
        // uses content ⊂ outer to tell an explicit [label](url) from an auto-detected URL.
        for (const LinkSpan& l : links)
            conts.append({l.kind, l.start + off, l.end + off,
                          l.labelStart + off, l.labelEnd + off, l.url});
    };
    auto addEmph = [&](const QVector<EmphSpan>& spans, qsizetype off) {
        for (const EmphSpan& s : spans)
            conts.append({kindFromBits(s.formatBits),
                          s.openerStart + off, s.closerEnd + off,
                          s.start + off, s.end + off, {}});
    };
    auto addMentions = [&](const QVector<MentionSpan>& mentions, qsizetype off) {
        for (const MentionSpan& m : mentions)
            conts.append({NodeKind::Mention, m.start + off, m.end + off,
                          m.start + off, m.end + off, m.pubKey});
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
        const QStringView gap = region.sliced(gs, ge - gs);
        const auto spans = scanCodeSpans(gap);
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
    for (const auto& q : std::as_const(quoteRanges)) {
        scanGap(cursor, q.first);
        cursor = q.second;
    }
    scanGap(cursor, regionLen);

    Ranges exclude = codeRanges;
    exclude += prefixRegion;
    exclude += quoteRanges;
    const QVector<LinkSpan> links = detectLinks ? scanLinks(region, exclude)
                                                : QVector<LinkSpan>{};

    // Mentions are detected outside code/quote prefixes and outside links (a URL may contain
    // '@'). Their ranges then exclude emphasis so "*" inside a pub key isn't paired.
    Ranges mentionExclude = exclude;
    mentionExclude += linkRangesOf(links);
    const QVector<MentionSpan> mentions = scanMentions(region, mentionExclude);

    Ranges emphExclude = exclude;
    emphExclude += linkRangesOf(links);
    emphExclude += mentionRangesOf(mentions);
    const QVector<EmphSpan> emph = processEmphasis(scanDelimiters(region, emphExclude));

    addLinks(links, rs);
    addMentions(mentions, rs);
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
