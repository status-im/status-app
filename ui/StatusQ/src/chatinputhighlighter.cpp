#include "StatusQ/chatinputhighlighter.h"

#include <QColor>
#include <QFontDatabase>
#include <QRegularExpression>
#include <QTextCharFormat>
#include <QVariantMap>
#include <QVector>

#include <utility>

namespace {

static const unsigned int kBold          = 1u << 0;
static const unsigned int kItalic        = 1u << 1;
static const unsigned int kStrikeThrough = 1u << 2;
static const unsigned int kDelimiter     = 1u << 3;
static const unsigned int kCode          = 1u << 4; // single-backtick: monospace + background
static const unsigned int kCodeFence     = 1u << 5; // triple-backtick content: monospace, no background
static const unsigned int kLink          = 1u << 6; // URL: blue foreground, combines with emphasis bits

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

using Ranges = QVector<QPair<qsizetype,qsizetype>>;

const QRegularExpression& kLinkRegex()
{
    static const QRegularExpression re(
        QStringLiteral(R"(\bhttps?://[a-zA-Z0-9](?:[a-zA-Z0-9\-.]*[a-zA-Z0-9])?(?:/[^\s<>()\[\]{}'"]*)?(?<![.,;:!?*~]))"),
        QRegularExpression::CaseInsensitiveOption
    );
    return re;
}

QVector<LinkSpan> scanLinks(const QString& text,
                            const Ranges& excludeRanges = {})
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

bool isUnicodeWhitespace(QChar c)
{
    return c.isSpace();
}

bool isUnicodePunctuation(QChar c)
{
    return c.isPunct() || c.isSymbol();
}

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

QVector<Delimiter> scanDelimiters(const QString& text,
                                   const Ranges& codeRanges = {})
{
    QVector<Delimiter> delimiters;
    qsizetype i = 0;
    const qsizetype n = text.length();
    while (i < n) {
        // Skip characters inside code spans — they cannot be emphasis delimiters
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
    qsizetype openers_bottom[2][3][2];
    for (int a = 0; a < 2; ++a)
        for (int b = 0; b < 3; ++b)
            for (int c2 = 0; c2 < 2; ++c2)
                openers_bottom[a][b][c2] = -1;

    auto chIndex = [](QChar ch) { return ch == QLatin1Char('*') ? 0 : 1; };

    qsizetype current = 0;
    while (current < delimiters.size()) {
        Delimiter& closer = delimiters[current];
        if (!closer.canClose) {
            ++current;
            continue;
        }

        int ci = chIndex(closer.ch);
        qsizetype bottom = openers_bottom[ci][closer.remaining % 3][closer.canOpen ? 1 : 0];

        qsizetype found = -1;
        for (qsizetype j = current - 1; j > bottom; --j) {
            const Delimiter& o = delimiters[j];
            if (!o.canOpen || o.ch != closer.ch)
                continue;
            // Rules 9/10: if either can both open and close, (sum % 3 != 0)
            // unless both are multiples of 3
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

        // Remove delimiters strictly between opener and closer.
        // After removal, closer shifts to found+1 (= current - count), which is
        // exactly what the unconditional assignment below sets.
        qsizetype removeFrom = found + 1;
        qsizetype removeTo   = current - 1;
        if (removeFrom <= removeTo)
            delimiters.erase(delimiters.begin() + removeFrom,
                             delimiters.begin() + removeTo + 1);
        // current now points at closer
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
    qsizetype i = 0;
    const qsizetype len = text.length();

    while (i < len) {
        if (text[i] != QLatin1Char('`')) { ++i; continue; }

        qsizetype openerStart = i;
        while (i < len && text[i] == QLatin1Char('`')) ++i;
        qsizetype openerLen    = i - openerStart;
        qsizetype contentStart = i;

        qsizetype j = i;
        bool found = false;
        while (j < len) {
            if (text[j] != QLatin1Char('`')) { ++j; continue; }
            qsizetype closerStart = j;
            while (j < len && text[j] == QLatin1Char('`')) ++j;
            qsizetype closerLen = j - closerStart;
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
        // Search forward for a matching closer
        qsizetype j = i;
        bool found = false;
        while (j < len) {
            if (text[j] != QLatin1Char('`')) { ++j; continue; }
            const qsizetype cs = j;
            while (j < len && text[j] == QLatin1Char('`')) ++j;
            if (j - cs == 3) { found = true; i = j; break; } // i=j: skip past closer
        }
        if (!found) return runStart;
    }
    return -1;
}

// Returns [openerStart, closerEnd) ranges for all code spans in text.
Ranges codeRangesOf(const QString& text)
{
    Ranges result;
    const auto codeSpans = scanCodeSpans(text);
    for (const CodeSpan& c : codeSpans)
        result.append({c.openerStart, c.closerEnd});
    return result;
}

// Filters code spans to those whose opening backtick run has exactly `backtickLen` characters.
QVector<CodeSpan> codeSpansByLen(const QVector<CodeSpan>& spans, qsizetype backtickLen)
{
    QVector<CodeSpan> result;
    for (const CodeSpan& c : spans)
        if (c.contentStart - c.openerStart == backtickLen)
            result.append(c);
    return result;
}

// Converts absolute code ranges to line-relative coordinates,
// including only those that intersect [lineStart, lineStart+lineLen).
Ranges lineRelativeRanges(
    const Ranges& absRanges, qsizetype lineStart, qsizetype lineLen)
{
    Ranges result;
    for (const auto& r : absRanges)
        if (r.first < lineStart + lineLen && r.second > lineStart)
            result.append({qMax(qsizetype(0), r.first - lineStart),
                           qMin(lineLen, r.second - lineStart)});
    return result;
}

bool anyOverlap(const Ranges& ranges, qsizetype start, qsizetype end)
{
    for (const auto& r : ranges)
        if (start < r.second && end > r.first) return true;
    return false;
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
    const qsizetype unclosedStart = findOpenCodeFence(document()->toPlainText());
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
    return fmt;
}

QVariantList ChatInputHighlighter::parseFormats(const QString& text) const
{
    QVariantList result;

    // Pre-compute all code spans once; derive triple-backtick ranges for inCode checks.
    const QVector<CodeSpan> allCodeSpans = scanCodeSpans(text);
    Ranges tripleAbsRanges;
    for (const CodeSpan& c : allCodeSpans)
        if (c.contentStart - c.openerStart == 3)
            tripleAbsRanges.append({c.openerStart, c.closerEnd});
    if (m_formatUnclosedCodeFence) {
        const qsizetype u = findOpenCodeFence(text);
        if (u >= 0) tripleAbsRanges.append({u, text.length()});
    }

    if (!m_multilineEmphasis) {
        qsizetype lineStart = 0;
        for (qsizetype i = 0; i <= text.length(); ++i) {
            if (i == text.length() || text[i] == QLatin1Char('\n')) {
                const QString line    = text.mid(lineStart, i - lineStart);
                const qsizetype lineLen = line.length();
                // Line-relative code ranges for delimiter scanning — compute spans once
                const QVector<CodeSpan> lineCodeSpans = scanCodeSpans(line);
                Ranges lineRanges;
                // Absolute code ranges for the inCode safety-net filter
                Ranges absCodeRanges = tripleAbsRanges;
                for (const CodeSpan& c : lineCodeSpans) {
                    lineRanges.append({c.openerStart, c.closerEnd});
                    absCodeRanges.append({c.openerStart + lineStart, c.closerEnd + lineStart});
                }
                const auto relRanges = lineRelativeRanges(tripleAbsRanges, lineStart, lineLen);
                for (const auto& r : relRanges)
                    lineRanges.append(r);
                // Exclude link ranges so URL characters don't trigger emphasis
                const auto linkRanges = linkRangesOf(scanLinks(line, lineRanges));
                for (const auto& r : linkRanges)
                    lineRanges.append(r);

                const auto emphSpans = processEmphasis(scanDelimiters(line, lineRanges));
                for (const EmphSpan& s : emphSpans) {
                    const qsizetype absStart = s.start + lineStart;
                    const qsizetype absEnd   = s.end   + lineStart;
                    if (anyOverlap(absCodeRanges, absStart, absEnd)) continue;
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
    Ranges allRanges;
    for (const CodeSpan& c : allCodeSpans)
        allRanges.append({c.openerStart, c.closerEnd});
    if (m_formatUnclosedCodeFence) {
        const qsizetype u = findOpenCodeFence(text);
        if (u >= 0) allRanges.append({u, text.length()});
    }
    // Exclude link ranges so URL characters don't trigger emphasis
    Ranges allExcluded = allRanges;
    const auto allLinkRanges = linkRangesOf(scanLinks(text, allRanges));
    for (const auto& r : allLinkRanges)
        allExcluded.append(r);
    const auto allEmphSpans = processEmphasis(scanDelimiters(text, allExcluded));
    for (const EmphSpan& s : allEmphSpans) {
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

    auto addCodeDelims = [&](const QVector<CodeSpan>& spans, qsizetype offset) {
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
        qsizetype lineStart = 0;
        for (qsizetype i = 0; i <= text.length(); ++i) {
            if (i == text.length() || text[i] == QLatin1Char('\n')) {
                const QString line         = text.mid(lineStart, i - lineStart);
                const QVector<CodeSpan> lineCodeSpans = scanCodeSpans(line);
                Ranges lineRanges;
                for (const CodeSpan& c : lineCodeSpans)
                    lineRanges.append({c.openerStart, c.closerEnd});
                const auto lineEmphSpans = processEmphasis(scanDelimiters(line, lineRanges));
                for (const EmphSpan& s : lineEmphSpans) {
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
        const Ranges allRanges = codeRangesOf(text);
        const auto emphSpans = processEmphasis(scanDelimiters(text, allRanges));
        for (const EmphSpan& s : emphSpans) {
            QVariantMap op;
            op[QStringLiteral("start")] = s.openerStart;
            op[QStringLiteral("end")]   = s.start;
            result.append(op);
            QVariantMap cl;
            cl[QStringLiteral("start")] = s.end;
            cl[QStringLiteral("end")]   = s.closerEnd;
            result.append(cl);
        }
        const auto allCodeSpans = scanCodeSpans(text);
        for (const CodeSpan& c : allCodeSpans) {
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

QVariantList ChatInputHighlighter::parseLinks(const QString& text) const
{
    QVariantList result;

    // Pre-compute triple-backtick ranges (always full-text)
    const QVector<CodeSpan> allCodeSpans = scanCodeSpans(text);
    Ranges tripleAbsRanges;
    for (const CodeSpan& c : allCodeSpans)
        if (c.contentStart - c.openerStart == 3)
            tripleAbsRanges.append({c.openerStart, c.closerEnd});

    if (!m_multilineEmphasis) {
        qsizetype lineStart = 0;
        for (qsizetype i = 0; i <= text.length(); ++i) {
            if (i == text.length() || text[i] == QLatin1Char('\n')) {
                const QString line      = text.mid(lineStart, i - lineStart);
                const qsizetype lineLen = line.length();
                Ranges lineRanges = codeRangesOf(line);
                const auto relRanges = lineRelativeRanges(tripleAbsRanges, lineStart, lineLen);
                for (const auto& r : relRanges)
                    lineRanges.append(r);

                const auto lineLinks = scanLinks(line, lineRanges);
                for (const LinkSpan& l : lineLinks) {
                    QVariantMap m;
                    m[QStringLiteral("text")]   = l.url;
                    m[QStringLiteral("start")]  = l.start + lineStart;
                    m[QStringLiteral("length")] = l.end - l.start;
                    result.append(m);
                }
                lineStart = i + 1;
            }
        }
        return result;
    }

    // Multiline: exclude all code spans
    Ranges allRanges;
    for (const CodeSpan& c : allCodeSpans)
        allRanges.append({c.openerStart, c.closerEnd});
    const auto textLinks = scanLinks(text, allRanges);
    for (const LinkSpan& l : textLinks) {
        QVariantMap m;
        m[QStringLiteral("text")]   = l.url;
        m[QStringLiteral("start")]  = l.start;
        m[QStringLiteral("length")] = l.end - l.start;
        result.append(m);
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
        const qsizetype docLen = fullText.length();
        m_flags.assign(docLen, 0u);

        auto applyCodeSpans = [&](const QVector<CodeSpan>& codeSpans,
                                  qsizetype len, qsizetype offset) {
            for (const CodeSpan& c : codeSpans) {
                const bool         isSingle   = (c.contentStart - c.openerStart == 1);
                const unsigned int contentFlag = isSingle ? kCode : kCodeFence;
                const unsigned int delimFlag   = isSingle ? kCode : kDelimiter;
                const qsizetype start = qMax(qsizetype(0), c.contentStart) + offset;
                const qsizetype end   = qMin(len, c.contentEnd)  + offset;
                for (qsizetype k = start; k < end; ++k)
                    m_flags[k] = contentFlag;
                const qsizetype opStart = qMax(qsizetype(0), c.openerStart)    + offset;
                const qsizetype opEnd   = qMin(len, c.contentStart) + offset;
                for (qsizetype k = opStart; k < opEnd; ++k)
                    m_flags[k] = delimFlag;
                const qsizetype clStart = qMax(qsizetype(0), c.contentEnd)  + offset;
                const qsizetype clEnd   = qMin(len, c.closerEnd) + offset;
                for (qsizetype k = clStart; k < clEnd; ++k)
                    m_flags[k] = delimFlag;
            }
        };

        // Pre-compute all code spans once; partition into triple/single for reuse.
        const QVector<CodeSpan> fullCodeSpans = scanCodeSpans(fullText);
        QVector<CodeSpan>                        tripleFences, singleSpans;
        Ranges      fullCodeRanges, tripleAbsRanges;
        for (const CodeSpan& c : fullCodeSpans) {
            fullCodeRanges.append({c.openerStart, c.closerEnd});
            const qsizetype blen = c.contentStart - c.openerStart;
            if (blen == 3) {
                tripleFences.append(c);
                tripleAbsRanges.append({c.openerStart, c.closerEnd});
            } else if (blen == 1) {
                singleSpans.append(c);
            }
        }

        // ── Unclosed code fence ───────────────────────────────────────────────
        const qsizetype unclosedStart = findOpenCodeFence(fullText);
        if (m_formatUnclosedCodeFence && unclosedStart >= 0) {
            tripleFences.append({unclosedStart, unclosedStart + 3, docLen, docLen});
            fullCodeRanges.append({unclosedStart, docLen});
            tripleAbsRanges.append({unclosedStart, docLen});
        }

        QVector<ChatInputLinksModel::LinkItem> modelItems;

        if (m_multilineEmphasis) {
            // Scan links first so their ranges exclude emphasis delimiter recognition
            const QVector<LinkSpan> fullLinks = scanLinks(fullText, fullCodeRanges);

            Ranges allExcluded = fullCodeRanges;
            const auto fullLinkRanges = linkRangesOf(fullLinks);
            for (const auto& r : fullLinkRanges)
                allExcluded.append(r);

            const QVector<EmphSpan> spans = processEmphasis(
                scanDelimiters(fullText, allExcluded));
            // Pass 1: content bits
            for (const EmphSpan& s : spans) {
                for (qsizetype i = qMax(qsizetype(0), s.start); i < qMin(docLen, s.end); ++i)
                    m_flags[i] |= s.formatBits;
            }
            // Pass 2: delimiter bits (overwrite — ensures delimiter chars are ONLY blue)
            for (const EmphSpan& s : spans) {
                for (qsizetype i = qMax(qsizetype(0), s.openerStart); i < qMin(docLen, s.start); ++i)
                    m_flags[i] = kDelimiter;
                for (qsizetype i = qMax(qsizetype(0), s.end); i < qMin(docLen, s.closerEnd); ++i)
                    m_flags[i] = kDelimiter;
            }
            // Pass 3: triple-backtick fences (always full-document)
            applyCodeSpans(tripleFences, docLen, 0);
            // Pass 4: single-backtick spans
            applyCodeSpans(singleSpans, docLen, 0);
            // Pass 5: link bits (OR in — allows combining with emphasis)
            for (const auto& l : fullLinks) {
                for (qsizetype k = l.start; k < l.end; ++k)
                    m_flags[k] |= kLink;
                modelItems.append({static_cast<int>(l.start),
                                   static_cast<int>(l.end - l.start), l.url});
            }
        } else {
            qsizetype lineStart = 0;
            for (qsizetype i = 0; i <= docLen; ++i) {
                if (i == docLen || fullText[i] == QLatin1Char('\n')) {
                    const QString line        = fullText.mid(lineStart, i - lineStart);
                    const qsizetype lineLen   = line.length();
                    // Scan line code spans once; reuse for both delimiter filtering and pass 3.
                    const QVector<CodeSpan> lineCodeSpans = scanCodeSpans(line);
                    Ranges lineRanges;
                    QVector<CodeSpan> lineSingleSpans;
                    for (const CodeSpan& c : lineCodeSpans) {
                        lineRanges.append({c.openerStart, c.closerEnd});
                        if (c.contentStart - c.openerStart == 1)
                            lineSingleSpans.append(c);
                    }
                    const auto tripleRelRanges = lineRelativeRanges(tripleAbsRanges, lineStart, lineLen);
                    for (const auto& r : tripleRelRanges)
                        lineRanges.append(r);

                    // Scan links before delimiter recognition so URL characters are excluded
                    const QVector<LinkSpan> lineLinks = scanLinks(line, lineRanges);
                    Ranges lineExcluded = lineRanges;
                    const auto lineLinkRanges = linkRangesOf(lineLinks);
                    for (const auto& r : lineLinkRanges)
                        lineExcluded.append(r);

                    const QVector<EmphSpan> spans = processEmphasis(scanDelimiters(line, lineExcluded));
                    // Pass 1: content bits
                    for (const EmphSpan& s : spans) {
                        const qsizetype start = qMax(qsizetype(0), s.start) + lineStart;
                        const qsizetype end   = qMin(lineLen, s.end) + lineStart;
                        for (qsizetype k = start; k < end; ++k)
                            m_flags[k] |= s.formatBits;
                    }
                    // Pass 2: delimiter bits (overwrite)
                    for (const EmphSpan& s : spans) {
                        const qsizetype opStart = qMax(qsizetype(0), s.openerStart) + lineStart;
                        const qsizetype opEnd   = qMin(lineLen, s.start) + lineStart;
                        for (qsizetype k = opStart; k < opEnd; ++k)
                            m_flags[k] = kDelimiter;
                        const qsizetype clStart = qMax(qsizetype(0), s.end) + lineStart;
                        const qsizetype clEnd   = qMin(lineLen, s.closerEnd) + lineStart;
                        for (qsizetype k = clStart; k < clEnd; ++k)
                            m_flags[k] = kDelimiter;
                    }
                    // Pass 3: single-backtick spans (per-line, reuse already-scanned spans)
                    applyCodeSpans(lineSingleSpans, lineLen, lineStart);
                    // Pass 4 (per-line): link bits
                    for (const auto& l : lineLinks) {
                        for (qsizetype k = l.start + lineStart; k < l.end + lineStart; ++k)
                            m_flags[k] |= kLink;
                        modelItems.append({static_cast<int>(l.start + lineStart),
                                           static_cast<int>(l.end - l.start), l.url});
                    }

                    lineStart = i + 1;
                }
            }
            // Pass 4 (global): triple-backtick fences (full-document, already computed above)
            applyCodeSpans(tripleFences, docLen, 0);
        }

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

    unsigned int bits = 0u;
    if (m_multilineEmphasis) {
        const Ranges ranges = codeRangesOf(fullText);
        const QVector<EmphSpan> spans = processEmphasis(scanDelimiters(fullText, ranges));
        for (const EmphSpan& s : spans)
            if (static_cast<qsizetype>(position) >= s.start &&
                static_cast<qsizetype>(position) < s.end)
                bits |= s.formatBits;
    } else {
        qsizetype lineStart = position;
        while (lineStart > 0 && fullText[lineStart - 1] != QLatin1Char('\n'))
            --lineStart;
        qsizetype lineEnd = position + 1; // +1 for the inserted 'a'
        while (lineEnd < fullText.length() && fullText[lineEnd] != QLatin1Char('\n'))
            ++lineEnd;
        const QString line = fullText.mid(lineStart, lineEnd - lineStart);
        const qsizetype posInLine = position - lineStart;
        const Ranges lineRanges = codeRangesOf(line);
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
    const unsigned int bits = (position >= 0 && position < static_cast<int>(m_flags.size()))
                              ? m_flags[position] : 0u;
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
    QVector<CodeSpan> tripleFencesForParse = codeSpansByLen(allCodeSpans, 3);
    if (m_formatUnclosedCodeFence) {
        const qsizetype u = findOpenCodeFence(text);
        if (u >= 0)
            tripleFencesForParse.append({u, u + 3, text.length(), text.length()});
    }
    for (const CodeSpan& c : std::as_const(tripleFencesForParse)) {
        QVariantMap m;
        m[QStringLiteral("start")] = c.contentStart;
        m[QStringLiteral("end")]   = c.contentEnd;
        result.append(m);
    }

    // Single-backtick: per-line or full-text depending on multilineEmphasis
    if (!m_multilineEmphasis) {
        qsizetype lineStart = 0;
        for (qsizetype i = 0; i <= text.length(); ++i) {
            if (i == text.length() || text[i] == QLatin1Char('\n')) {
                const QString line = text.mid(lineStart, i - lineStart);
                const auto singleLineSpans = codeSpansByLen(scanCodeSpans(line), 1);
                for (const CodeSpan& c : singleLineSpans) {
                    QVariantMap m;
                    m[QStringLiteral("start")] = c.contentStart + lineStart;
                    m[QStringLiteral("end")]   = c.contentEnd   + lineStart;
                    result.append(m);
                }
                lineStart = i + 1;
            }
        }
    } else {
        const auto singleSpans = codeSpansByLen(allCodeSpans, 1);
        for (const CodeSpan& c : singleSpans) {
            QVariantMap m;
            m[QStringLiteral("start")] = c.contentStart;
            m[QStringLiteral("end")]   = c.contentEnd;
            result.append(m);
        }
    }
    return result;
}
