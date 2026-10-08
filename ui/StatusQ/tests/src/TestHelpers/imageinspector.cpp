#include "imageinspector.h"

#include <QImage>
#include <QImageWriter>

#include <QtQuick/private/qquickimagebase_p.h>
#include <QtQuick/private/qquickimagebase_p_p.h>
#include <QtQuickLayouts/private/qquicklayout_p.h>

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
    return pixmap && !pixmap->isNull() ? QString::number(pixmap->image().cacheKey()) : QString();
}

bool ImageInspector::hasLayoutAttached(QQuickItem* item) const
{
    return qmlAttachedPropertiesObject<QQuickLayout>(item, false) != nullptr;
}

QUrl ImageInspector::writeImage(int width, int height, const QString& format, bool rotated90)
{
    QImage image(width, height, QImage::Format_RGB32);
    image.fill(Qt::darkCyan);

    const QString path = m_dir.filePath(QStringLiteral("%1.%2").arg(m_written++).arg(format));
    QImageWriter writer(path, format.toLatin1());
    if (rotated90)
        writer.setTransformation(QImageIOHandler::TransformationRotate90);
    if (!writer.write(image))
        return {};
    return QUrl::fromLocalFile(path);
}
