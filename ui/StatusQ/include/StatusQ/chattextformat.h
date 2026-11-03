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
}
