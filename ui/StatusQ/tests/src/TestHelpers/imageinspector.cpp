#include "imageinspector.h"

#include <QtQuick/private/qquickimagebase_p.h>
#include <QtQuick/private/qquickimagebase_p_p.h>

QSize ImageInspector::decodedSize(QQuickItem* image) const
{
    auto imageBase = qobject_cast<QQuickImageBase*>(image);
    if (!imageBase)
        return {};

    const auto pixmap = QQuickImageBasePrivate::get(imageBase)->currentPix;
    return pixmap ? QSize(pixmap->width(), pixmap->height()) : QSize();
}

QString ImageInspector::decodeKey(QQuickItem* image) const
{
    auto imageBase = qobject_cast<QQuickImageBase*>(image);
    if (!imageBase)
        return {};

    const auto pixmap = QQuickImageBasePrivate::get(imageBase)->currentPix;
    return pixmap ? QString::number(pixmap->image().cacheKey()) : QString();
}
