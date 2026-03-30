#include "StatusQ/chatinputhighlighter.h"

#include <QColor>
#include <QFontDatabase>
#include <QTextCharFormat>
#include <QVariantMap>
#include <QVector>

namespace {

static const int kBold          = 1 << 0;
static const int kItalic        = 1 << 1;
static const int kStrikeThrough = 1 << 2;
static const int kDelimiter     = 1 << 3;
static const int kCode          = 1 << 4; // single-backtick: monospace + background
static const int kCodeFence     = 1 << 5; // triple-backtick content: monospace, no background

struct Delimiter {
    int pos;
    int remaining;
    QChar ch;
    bool canOpen;
    bool canClose;
};

struct CodeSpan {
    int openerStart;   // start of opening backtick run
    int contentStart;  // end of opening backtick run = content start
    int contentEnd;    // start of closing backtick run = content end
    int closerEnd;     // end of closing backtick run
};

struct EmphSpan {
    int start;        // content start (= opener delimiter end)
    int end;          // content end   (= closer delimiter start)
    int formatBits;
    int openerStart;  // start of consumed opener delimiter chars
    int closerEnd;    // end   of consumed closer delimiter chars
};

bool isUnicodeWhitespace(QChar c)
{
    return c.isSpace();
}

bool isUnicodePunctuation(QChar c)
{
    auto cat = c.category();
    return (cat >= QChar::Punctuation_Connector && cat <= QChar::Punctuation_Other)
        || (cat >= QChar::Symbol_Math && cat <= QChar::Symbol_Other);
}

bool isLeftFlanking(const QString& text, int pos, int len)
{
    QChar charAfter  = (pos + len < text.length()) ? text[pos + len] : QChar(' ');
    QChar charBefore = (pos > 0)                   ? text[pos - 1]   : QChar(' ');

    if (!isUnicodePunctuation(charAfter))
        return true;
    return isUnicodeWhitespace(charBefore) || isUnicodePunctuation(charBefore);
}

bool isRightFlanking(const QString& text, int pos, int len)
{
    QChar charAfter  = (pos + len < text.length()) ? text[pos + len] : QChar(' ');
    QChar charBefore = (pos > 0)                   ? text[pos - 1]   : QChar(' ');

    if (!isUnicodePunctuation(charBefore))
        return true;
    return isUnicodeWhitespace(charAfter) || isUnicodePunctuation(charAfter);
}

QVector<Delimiter> scanDelimiters(const QString& text,
                                   const QVector<QPair<int,int>>& codeRanges = {})
{
    QVector<Delimiter> delimiters;
    int i = 0;
    while (i < text.length()) {
        // Skip characters inside code spans — they cannot be emphasis delimiters
        for (const auto& r : codeRanges)
            if (i >= r.first && i < r.second) { i = r.second; break; }
        if (i >= text.length()) break;

        QChar c = text[i];

        if (c == QLatin1Char('*')) {
            int start = i;
            while (i < text.length() && text[i] == QLatin1Char('*'))
                ++i;
            int len = i - start;
            bool canOpen  = isLeftFlanking(text, start, len);
            bool canClose = isRightFlanking(text, start, len);
            delimiters.append({start, len, c, canOpen, canClose});
        } else if (c == QLatin1Char('~')) {
            int start = i;
            while (i < text.length() && text[i] == QLatin1Char('~'))
                ++i;
            int len = i - start;
            if (len == 2) {
                bool canOpen  = isLeftFlanking(text, start, len);
                bool canClose = isRightFlanking(text, start, len);
                delimiters.append({start, 2, c, canOpen, canClose});
            }
            // otherwise skip (no strikethrough for ~ or ~~~+)
        } else {
            ++i;
        }
    }
    return delimiters;
}

QVector<EmphSpan> processEmphasis(QVector<Delimiter> delimiters)
{
    QVector<EmphSpan> spans;

    // openers_bottom[ch_index][remMod3][canOpenAsInt]
    // ch_index: 0 = '*', 1 = '~'
    int openers_bottom[2][3][2];
    for (int a = 0; a < 2; ++a)
        for (int b = 0; b < 3; ++b)
            for (int c2 = 0; c2 < 2; ++c2)
                openers_bottom[a][b][c2] = -1;

    auto chIndex = [](QChar ch) { return ch == QLatin1Char('*') ? 0 : 1; };

    int current = 0;
    while (current < delimiters.size()) {
        Delimiter& closer = delimiters[current];
        if (!closer.canClose) {
            ++current;
            continue;
        }

        int ci = chIndex(closer.ch);
        int bottom = openers_bottom[ci][closer.remaining % 3][closer.canOpen ? 1 : 0];

        int found = -1;
        for (int j = current - 1; j > bottom; --j) {
            const Delimiter& o = delimiters[j];
            if (!o.canOpen || o.ch != closer.ch)
                continue;
            // Rules 9/10: if either can both open and close, (sum % 3 != 0)
            // unless both are multiples of 3
            if (o.canClose || closer.canOpen) {
                int sumMod3 = (o.remaining + closer.remaining) % 3;
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

        int useCount;
        if (opener.ch == QLatin1Char('~'))
            useCount = 2;
        else
            useCount = (opener.remaining >= 2 && closer.remaining >= 2) ? 2 : 1;

        int bits;
        if (opener.ch == QLatin1Char('~'))
            bits = kStrikeThrough;
        else if (useCount == 2)
            bits = kBold;
        else
            bits = kItalic;

        int contentStart     = opener.pos + opener.remaining;
        int contentEnd       = closer.pos;
        int openerDelimStart = contentStart - useCount;
        int closerDelimEnd   = contentEnd   + useCount;
        spans.append({contentStart, contentEnd, bits, openerDelimStart, closerDelimEnd});

        // Remove delimiters strictly between opener and closer
        int removeFrom = found + 1;
        int removeTo   = current - 1;
        if (removeFrom <= removeTo) {
            int count = removeTo - removeFrom + 1;
            delimiters.erase(delimiters.begin() + removeFrom,
                             delimiters.begin() + removeFrom + count);
            current -= count;
        }
        // current now points at closer (after removal adjustments)
        current = found + 1;

        // Consume from opener (rightmost chars → pos stays, remaining decreases)
        opener.remaining -= useCount;
        if (opener.remaining == 0) {
            delimiters.removeAt(found);
            --current;
        }

        // Consume from closer (leftmost chars → pos advances)
        // After possible opener removal, closer is at current
        Delimiter& closerRef = delimiters[current];
        closerRef.pos       += useCount;
        closerRef.remaining -= useCount;
        if (closerRef.remaining == 0)
            delimiters.removeAt(current);
        // if remaining > 0, stay at current to try matching again
    }

    return spans;
}

QVector<CodeSpan> scanCodeSpans(const QString& text)
{
    QVector<CodeSpan> result;
    int i = 0;
    const int len = text.length();

    while (i < len) {
        if (text[i] != QLatin1Char('`')) { ++i; continue; }

        int openerStart = i;
        while (i < len && text[i] == QLatin1Char('`')) ++i;
        int openerLen    = i - openerStart;
        int contentStart = i;

        int j = i;
        bool found = false;
        while (j < len) {
            if (text[j] != QLatin1Char('`')) { ++j; continue; }
            int closerStart = j;
            while (j < len && text[j] == QLatin1Char('`')) ++j;
            int closerLen = j - closerStart;
            if (closerLen == openerLen) {
                result.append({openerStart, contentStart, closerStart, j});
                i = j;
                found = true;
                break;
            }
        }
        (void)found;
    }
    return result;
}

// Returns [openerStart, closerEnd) ranges for all code spans in text.
QVector<QPair<int,int>> codeRangesOf(const QString& text)
{
    QVector<QPair<int,int>> result;
    for (const CodeSpan& c : scanCodeSpans(text))
        result.append({c.openerStart, c.closerEnd});
    return result;
}

// Filters code spans to those whose opening backtick run has exactly `backtickLen` characters.
QVector<CodeSpan> codeSpansByLen(const QVector<CodeSpan>& spans, int backtickLen)
{
    QVector<CodeSpan> result;
    for (const CodeSpan& c : spans)
        if (c.contentStart - c.openerStart == backtickLen)
            result.append(c);
    return result;
}

// Converts absolute code ranges to line-relative coordinates,
// including only those that intersect [lineStart, lineStart+lineLen).
QVector<QPair<int,int>> lineRelativeRanges(const QVector<QPair<int,int>>& absRanges,
                                           int lineStart, int lineLen)
{
    QVector<QPair<int,int>> result;
    for (const auto& r : absRanges)
        if (r.first < lineStart + lineLen && r.second > lineStart)
            result.append({qMax(0, r.first - lineStart), qMin(lineLen, r.second - lineStart)});
    return result;
}

bool anyOverlap(const QVector<QPair<int,int>>& ranges, int start, int end)
{
    for (const auto& r : ranges)
        if (start < r.second && end > r.first) return true;
    return false;
}

} // namespace

ChatInputHighlighter::ChatInputHighlighter(QObject* parent)
    : QSyntaxHighlighter(parent)
{
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

QTextCharFormat ChatInputHighlighter::buildFormat(int bits) const
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
    if (bits & kBold)
        fmt.setFontWeight(QFont::Bold);
    if (bits & kItalic)
        fmt.setFontItalic(true);
    if (bits & kStrikeThrough)
        fmt.setFontStrikeOut(true);
    return fmt;
}

QVariantList ChatInputHighlighter::parseFormats(const QString& text) const
{
    QVariantList result;

    // Pre-compute all code spans once; derive triple-backtick ranges for inCode checks.
    const QVector<CodeSpan> allCodeSpans = scanCodeSpans(text);
    QVector<QPair<int,int>> tripleAbsRanges;
    for (const CodeSpan& c : allCodeSpans)
        if (c.contentStart - c.openerStart == 3)
            tripleAbsRanges.append({c.openerStart, c.closerEnd});

    if (!m_multilineEmphasis) {
        int lineStart = 0;
        for (int i = 0; i <= text.length(); ++i) {
            if (i == text.length() || text[i] == QLatin1Char('\n')) {
                const QString line    = text.mid(lineStart, i - lineStart);
                const int     lineLen = line.length();
                // Line-relative code ranges for delimiter scanning
                const QVector<QPair<int,int>> lineRanges = codeRangesOf(line);
                // Absolute code ranges for the inCode safety-net filter
                QVector<QPair<int,int>> absRanges = tripleAbsRanges;
                for (const auto& r : lineRanges)
                    absRanges.append({r.first + lineStart, r.second + lineStart});

                for (const EmphSpan& s : processEmphasis(scanDelimiters(line, lineRanges))) {
                    const int absStart = s.start + lineStart;
                    const int absEnd   = s.end   + lineStart;
                    if (anyOverlap(absRanges, absStart, absEnd)) continue;
                    QVariantMap m;
                    m[QStringLiteral("start")]         = absStart;
                    m[QStringLiteral("end")]           = absEnd;
                    m[QStringLiteral("bold")]          = bool(s.formatBits & kBold);
                    m[QStringLiteral("italic")]        = bool(s.formatBits & kItalic);
                    m[QStringLiteral("strikethrough")] = bool(s.formatBits & kStrikeThrough);
                    result.append(m);
                }
                lineStart = i + 1;
            }
        }
        return result;
    }

    // Multiline: all code ranges derived from the already-computed spans
    QVector<QPair<int,int>> allRanges;
    for (const CodeSpan& c : allCodeSpans)
        allRanges.append({c.openerStart, c.closerEnd});
    for (const EmphSpan& s : processEmphasis(scanDelimiters(text, allRanges))) {
        if (anyOverlap(allRanges, s.start, s.end)) continue;
        QVariantMap m;
        m[QStringLiteral("start")]         = s.start;
        m[QStringLiteral("end")]           = s.end;
        m[QStringLiteral("bold")]          = bool(s.formatBits & kBold);
        m[QStringLiteral("italic")]        = bool(s.formatBits & kItalic);
        m[QStringLiteral("strikethrough")] = bool(s.formatBits & kStrikeThrough);
        result.append(m);
    }
    return result;
}

QVariantList ChatInputHighlighter::parseDelimiters(const QString& text) const
{
    QVariantList result;

    auto addCodeDelims = [&](const QVector<CodeSpan>& spans, int offset) {
        for (const CodeSpan& c : spans) {
            QVariantMap op;
            op[QStringLiteral("start")] = c.openerStart  + offset;
            op[QStringLiteral("end")]   = c.contentStart + offset;
            result.append(op);
            QVariantMap cl;
            cl[QStringLiteral("start")] = c.contentEnd + offset;
            cl[QStringLiteral("end")]   = c.closerEnd  + offset;
            result.append(cl);
        }
    };

    if (!m_multilineEmphasis) {
        int lineStart = 0;
        for (int i = 0; i <= text.length(); ++i) {
            if (i == text.length() || text[i] == QLatin1Char('\n')) {
                const QString line         = text.mid(lineStart, i - lineStart);
                const QVector<CodeSpan> lineCodeSpans = scanCodeSpans(line);
                QVector<QPair<int,int>> lineRanges;
                for (const CodeSpan& c : lineCodeSpans)
                    lineRanges.append({c.openerStart, c.closerEnd});
                for (const EmphSpan& s : processEmphasis(scanDelimiters(line, lineRanges))) {
                    QVariantMap op;
                    op[QStringLiteral("start")] = s.openerStart + lineStart;
                    op[QStringLiteral("end")]   = s.start       + lineStart;
                    result.append(op);
                    QVariantMap cl;
                    cl[QStringLiteral("start")] = s.end       + lineStart;
                    cl[QStringLiteral("end")]   = s.closerEnd + lineStart;
                    result.append(cl);
                }
                addCodeDelims(codeSpansByLen(lineCodeSpans, 1), lineStart);
                lineStart = i + 1;
            }
        }
        // Triple-backtick: always full-text
        addCodeDelims(codeSpansByLen(scanCodeSpans(text), 3), 0);
    } else {
        const QVector<QPair<int,int>> allRanges = codeRangesOf(text);
        for (const EmphSpan& s : processEmphasis(scanDelimiters(text, allRanges))) {
            QVariantMap op;
            op[QStringLiteral("start")] = s.openerStart;
            op[QStringLiteral("end")]   = s.start;
            result.append(op);
            QVariantMap cl;
            cl[QStringLiteral("start")] = s.end;
            cl[QStringLiteral("end")]   = s.closerEnd;
            result.append(cl);
        }
        for (const CodeSpan& c : scanCodeSpans(text)) {
            QVariantMap op;
            op[QStringLiteral("start")] = c.openerStart;
            op[QStringLiteral("end")]   = c.contentStart;
            result.append(op);
            QVariantMap cl;
            cl[QStringLiteral("start")] = c.contentEnd;
            cl[QStringLiteral("end")]   = c.closerEnd;
            result.append(cl);
        }
    }
    return result;
}

void ChatInputHighlighter::highlightBlock(const QString& text)
{
    if (!document())
        return;

    const QString fullText = document()->toPlainText();

    if (fullText != m_cachedText) {
        m_cachedText = fullText;
        const int docLen = fullText.length();
        m_flags.assign(docLen, 0);

        auto applyCodeSpans = [&](const QVector<CodeSpan>& codeSpans, int len, int offset) {
            for (const CodeSpan& c : codeSpans) {
                const bool isSingle   = (c.contentStart - c.openerStart == 1);
                const int contentFlag = isSingle ? kCode : kCodeFence;
                const int delimFlag   = isSingle ? kCode : kDelimiter;
                const int start = qMax(0, c.contentStart) + offset;
                const int end   = qMin(len, c.contentEnd)  + offset;
                for (int k = start; k < end; ++k)
                    m_flags[k] = contentFlag;
                const int opStart = qMax(0, c.openerStart)    + offset;
                const int opEnd   = qMin(len, c.contentStart) + offset;
                for (int k = opStart; k < opEnd; ++k)
                    m_flags[k] = delimFlag;
                const int clStart = qMax(0, c.contentEnd)  + offset;
                const int clEnd   = qMin(len, c.closerEnd) + offset;
                for (int k = clStart; k < clEnd; ++k)
                    m_flags[k] = delimFlag;
            }
        };

        // Pre-compute all code spans once; partition into triple/single for reuse.
        const QVector<CodeSpan> fullCodeSpans = scanCodeSpans(fullText);
        QVector<CodeSpan>        tripleFences, singleSpans;
        QVector<QPair<int,int>>  fullCodeRanges, tripleAbsRanges;
        for (const CodeSpan& c : fullCodeSpans) {
            fullCodeRanges.append({c.openerStart, c.closerEnd});
            const int blen = c.contentStart - c.openerStart;
            if (blen == 3) {
                tripleFences.append(c);
                tripleAbsRanges.append({c.openerStart, c.closerEnd});
            } else if (blen == 1) {
                singleSpans.append(c);
            }
        }

        if (m_multilineEmphasis) {
            const QVector<EmphSpan> spans = processEmphasis(
                scanDelimiters(fullText, fullCodeRanges));
            // Pass 1: content bits
            for (const EmphSpan& s : spans) {
                for (int i = qMax(0, s.start); i < qMin(docLen, s.end); ++i)
                    m_flags[i] |= s.formatBits;
            }
            // Pass 2: delimiter bits (overwrite — ensures delimiter chars are ONLY blue)
            for (const EmphSpan& s : spans) {
                for (int i = qMax(0, s.openerStart); i < qMin(docLen, s.start); ++i)
                    m_flags[i] = kDelimiter;
                for (int i = qMax(0, s.end); i < qMin(docLen, s.closerEnd); ++i)
                    m_flags[i] = kDelimiter;
            }
            // Pass 3: triple-backtick fences (always full-document)
            applyCodeSpans(tripleFences, docLen, 0);
            // Pass 4: single-backtick spans
            applyCodeSpans(singleSpans, docLen, 0);
        } else {
            int lineStart = 0;
            for (int i = 0; i <= docLen; ++i) {
                if (i == docLen || fullText[i] == QLatin1Char('\n')) {
                    const QString line = fullText.mid(lineStart, i - lineStart);
                    const int lineLen  = line.length();
                    // Scan line code spans once; reuse for both delimiter filtering and pass 3.
                    const QVector<CodeSpan> lineCodeSpans = scanCodeSpans(line);
                    QVector<QPair<int,int>> lineRanges;
                    QVector<CodeSpan> lineSingleSpans;
                    for (const CodeSpan& c : lineCodeSpans) {
                        lineRanges.append({c.openerStart, c.closerEnd});
                        if (c.contentStart - c.openerStart == 1)
                            lineSingleSpans.append(c);
                    }
                    for (const auto& r : lineRelativeRanges(tripleAbsRanges, lineStart, lineLen))
                        lineRanges.append(r);
                    const QVector<EmphSpan> spans = processEmphasis(scanDelimiters(line, lineRanges));
                    // Pass 1: content bits
                    for (const EmphSpan& s : spans) {
                        const int start = qMax(0, s.start) + lineStart;
                        const int end   = qMin(lineLen, s.end) + lineStart;
                        for (int k = start; k < end; ++k)
                            m_flags[k] |= s.formatBits;
                    }
                    // Pass 2: delimiter bits (overwrite)
                    for (const EmphSpan& s : spans) {
                        const int opStart = qMax(0, s.openerStart) + lineStart;
                        const int opEnd   = qMin(lineLen, s.start) + lineStart;
                        for (int k = opStart; k < opEnd; ++k)
                            m_flags[k] = kDelimiter;
                        const int clStart = qMax(0, s.end) + lineStart;
                        const int clEnd   = qMin(lineLen, s.closerEnd) + lineStart;
                        for (int k = clStart; k < clEnd; ++k)
                            m_flags[k] = kDelimiter;
                    }
                    // Pass 3: single-backtick spans (per-line, reuse already-scanned spans)
                    applyCodeSpans(lineSingleSpans, lineLen, lineStart);
                    lineStart = i + 1;
                }
            }
            // Pass 4: triple-backtick fences (full-document, already computed above)
            applyCodeSpans(tripleFences, docLen, 0);
        }
    }

    const int blockStart = currentBlock().position();
    const int blockLen   = text.length();

    int i = 0;
    while (i < blockLen) {
        const int docPos = blockStart + i;
        const int f = (docPos < (int)m_flags.size()) ? m_flags[docPos] : 0;
        int j = i + 1;
        while (j < blockLen) {
            const int nf = ((blockStart + j) < (int)m_flags.size())
                           ? m_flags[blockStart + j] : 0;
            if (nf != f) break;
            ++j;
        }
        if (f)
            setFormat(i, j - i, buildFormat(f));
        i = j;
    }
}

QVariantMap ChatInputHighlighter::emphasisAtInsertion(int position) const
{
    const auto allFalse = []() -> QVariantMap {
        return {
            {QStringLiteral("bold"),          false},
            {QStringLiteral("italic"),        false},
            {QStringLiteral("strikethrough"), false},
        };
    };

    if (!document())
        return allFalse();

    QString fullText = document()->toPlainText();
    if (position < 0 || position > fullText.length())
        return allFalse();

    fullText.insert(position, QLatin1Char('a'));

    int bits = 0;
    if (m_multilineEmphasis) {
        const QVector<QPair<int,int>> ranges = codeRangesOf(fullText);
        const QVector<EmphSpan> spans = processEmphasis(scanDelimiters(fullText, ranges));
        for (const EmphSpan& s : spans)
            if (position >= s.start && position < s.end)
                bits |= s.formatBits;
    } else {
        int lineStart = position;
        while (lineStart > 0 && fullText[lineStart - 1] != QLatin1Char('\n'))
            --lineStart;
        int lineEnd = position + 1; // +1 for the inserted 'a'
        while (lineEnd < fullText.length() && fullText[lineEnd] != QLatin1Char('\n'))
            ++lineEnd;
        const QString line = fullText.mid(lineStart, lineEnd - lineStart);
        const int posInLine = position - lineStart;
        const QVector<QPair<int,int>> lineRanges = codeRangesOf(line);
        const QVector<EmphSpan> spans = processEmphasis(scanDelimiters(line, lineRanges));
        for (const EmphSpan& s : spans)
            if (posInLine >= s.start && posInLine < s.end)
                bits |= s.formatBits;
    }

    return {
        {QStringLiteral("bold"),          bool(bits & kBold)},
        {QStringLiteral("italic"),        bool(bits & kItalic)},
        {QStringLiteral("strikethrough"), bool(bits & kStrikeThrough)},
    };
}

QVariantMap ChatInputHighlighter::emphasisAt(int position) const
{
    const int bits = (position >= 0 && position < m_flags.size())
                     ? m_flags[position] : 0;
    return {
        {QStringLiteral("bold"),          bool(bits & kBold)},
        {QStringLiteral("italic"),        bool(bits & kItalic)},
        {QStringLiteral("strikethrough"), bool(bits & kStrikeThrough)},
    };
}

QVariantList ChatInputHighlighter::parseCodeSpans(const QString& text) const
{
    QVariantList result;

    // Pre-compute all code spans once; reuse for both triple and (in multiline mode) single spans.
    const QVector<CodeSpan> allCodeSpans = scanCodeSpans(text);

    // Triple-backtick fences: always full-document
    for (const CodeSpan& c : codeSpansByLen(allCodeSpans, 3)) {
        QVariantMap m;
        m[QStringLiteral("start")] = c.contentStart;
        m[QStringLiteral("end")]   = c.contentEnd;
        result.append(m);
    }

    // Single-backtick: per-line or full-text depending on multilineEmphasis
    if (!m_multilineEmphasis) {
        int lineStart = 0;
        for (int i = 0; i <= text.length(); ++i) {
            if (i == text.length() || text[i] == QLatin1Char('\n')) {
                const QString line = text.mid(lineStart, i - lineStart);
                for (const CodeSpan& c : codeSpansByLen(scanCodeSpans(line), 1)) {
                    QVariantMap m;
                    m[QStringLiteral("start")] = c.contentStart + lineStart;
                    m[QStringLiteral("end")]   = c.contentEnd   + lineStart;
                    result.append(m);
                }
                lineStart = i + 1;
            }
        }
    } else {
        for (const CodeSpan& c : codeSpansByLen(allCodeSpans, 1)) {
            QVariantMap m;
            m[QStringLiteral("start")] = c.contentStart;
            m[QStringLiteral("end")]   = c.contentEnd;
            result.append(m);
        }
    }
    return result;
}
