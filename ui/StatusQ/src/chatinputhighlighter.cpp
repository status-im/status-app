#include "StatusQ/chatinputhighlighter.h"

#include <QTextCharFormat>
#include <QVariantMap>
#include <QVector>

namespace {

static const int kBold          = 1 << 0;
static const int kItalic        = 1 << 1;
static const int kStrikeThrough = 1 << 2;

struct Delimiter {
    int pos;
    int remaining;
    QChar ch;
    bool canOpen;
    bool canClose;
};

struct EmphSpan {
    int start;
    int end;
    int formatBits;
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

QVector<Delimiter> scanDelimiters(const QString& text)
{
    QVector<Delimiter> delimiters;
    int i = 0;
    while (i < text.length()) {
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

        int contentStart = opener.pos + opener.remaining;
        int contentEnd   = closer.pos;
        spans.append({contentStart, contentEnd, bits});

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

QTextCharFormat buildFormat(int bits)
{
    QTextCharFormat fmt;
    if (bits & kBold)
        fmt.setFontWeight(QFont::Bold);
    if (bits & kItalic)
        fmt.setFontItalic(true);
    if (bits & kStrikeThrough)
        fmt.setFontStrikeOut(true);
    return fmt;
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
    m_quickTextDocument = doc;
    if (doc)
        setDocument(doc->textDocument());
    else
        setDocument(nullptr);
    emit quickTextDocumentChanged();
}

QVariantList ChatInputHighlighter::parseFormats(const QString& text) const
{
    const auto spans = processEmphasis(scanDelimiters(text));
    QVariantList result;
    result.reserve(spans.size());
    for (const EmphSpan& s : spans) {
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

void ChatInputHighlighter::highlightBlock(const QString& text)
{
    const int docLen = document()->characterCount() - 1;
    if (m_flags.size() != docLen)
        m_flags.assign(docLen, 0);

    const int blockStart = currentBlock().position();

    for (int i = blockStart; i < blockStart + text.length() && i < m_flags.size(); ++i)
        m_flags[i] = 0;

    QVector<Delimiter> delimiters = scanDelimiters(text);
    QVector<EmphSpan>  spans      = processEmphasis(delimiters);

    for (const EmphSpan& s : spans) {
        int start = qMax(0, s.start);
        int end   = qMin(text.length(), s.end + 1);
        for (int i = start; i < end; ++i)
            if (blockStart + i < m_flags.size())
                m_flags[blockStart + i] |= s.formatBits;
    }

    QVector<int> localFlags(text.length(), 0);
    for (const EmphSpan& s : spans) {
        int start = qMax(0, s.start);
        int end   = qMin(text.length(), s.end);
        for (int i = start; i < end; ++i)
            localFlags[i] |= s.formatBits;
    }

    int i = 0;
    while (i < text.length()) {
        int start = i;
        int f = localFlags[i];
        while (i < text.length() && localFlags[i] == f)
            ++i;
        if (f)
            setFormat(start, i - start, buildFormat(f));
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

    QTextBlock block = document()->findBlock(position);
    if (!block.isValid())
        return allFalse();

    const int posInBlock = position - block.position();
    QString modified = block.text();
    modified.insert(posInBlock, QLatin1Char('a'));

    const QVector<EmphSpan> spans = processEmphasis(scanDelimiters(modified));

    int bits = 0;
    for (const EmphSpan& s : spans) {
        if (posInBlock >= s.start && posInBlock < s.end)
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
