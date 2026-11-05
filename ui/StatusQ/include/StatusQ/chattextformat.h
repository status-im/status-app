#pragma once
#include "chattextsegment.h"
#include <QTextCharFormat>

namespace ChatTextFormat {
enum class ForegroundRole { Body, Quote, Link, Mention };
inline ForegroundRole foregroundRole(const ChatTextSegment& segment, int quoteLevel)
{
    if (segment.mention()) return ForegroundRole::Mention;
    if (!segment.href.isEmpty()) return ForegroundRole::Link;
    return quoteLevel > 0 ? ForegroundRole::Quote : ForegroundRole::Body;
}

inline QTextCharFormat emphasis(const ChatTextSegment& segment)
{
    QTextCharFormat format;
    if (segment.bold()) format.setFontWeight(QFont::Bold);
    if (segment.italic()) format.setFontItalic(true);
    if (segment.strikethrough()) format.setFontStrikeOut(true);
    if (segment.underline()) format.setFontUnderline(true);
    return format;
}

// Unformatted text of the segments for screen readers and tests: paragraphs
// split as ChatTextItem splits them, joined by newlines, then a space and
// `editedMarker` if that is not empty. Matches MarkdownUtils::plainText on the
// source, except that a code fence sharing a line with other text is on a line
// of its own, as it is rendered.
inline QString plainText(const QList<ChatTextSegment>& segments, const QString& editedMarker)
{
    QString text;
    bool first = true;
    bool afterCode = false;
    for (const ChatTextSegment& segment : segments) {
        const bool code = segment.codeBlock();
        if (!first && (code || afterCode || segment.newBlock()))
            text += QLatin1Char('\n');
        text += segment.text;
        first = false;
        afterCode = code;
    }
    if (!editedMarker.isEmpty() && !segments.isEmpty())
        text += QLatin1Char(' ') + editedMarker;
    return text;
}
}
