#include "StatusQ/mentiontextobject.h"

#include <QTextDocument>
#include <QFontMetricsF>

MentionTextObject::MentionTextObject(QObject* parent)
    : QObject(parent)
{
}

QSizeF MentionTextObject::mentionSize(const QFont& baseFont, const QString& text)
{
    QFont targetFont = baseFont;
    constexpr int offset = 2;

    if (baseFont.pixelSize() != -1)
        targetFont.setPixelSize(baseFont.pixelSize() - offset);
    else
        targetFont.setPointSizeF(baseFont.pointSizeF() - offset);

    return QSizeF(QFontMetricsF(targetFont).horizontalAdvance(text) + 4,
                  QFontMetricsF(baseFont).height());
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
