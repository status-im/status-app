#include "StatusQ/mentiontextobject.h"

#include <QTextDocument>
#include <QFontMetricsF>

MentionTextObject::MentionTextObject(QObject* parent)
    : QObject(parent)
{
}

QSizeF MentionTextObject::mentionSize(const QFont& baseFont, const QString& text)
{
    const QFontMetricsF fm(baseFont);
    return QSizeF(fm.horizontalAdvance(text) + 4, fm.height());
}

QSizeF MentionTextObject::intrinsicSize(QTextDocument* doc, int,
                                        const QTextFormat& format)
{
    return mentionSize(doc->defaultFont(),
                       format.property(NameProperty).toString());
}

void MentionTextObject::drawObject(QPainter*, const QRectF&, QTextDocument*, int,
                                   const QTextFormat&)
{
    // Rendering is handled by the QML overlay; nothing to paint here.
}
