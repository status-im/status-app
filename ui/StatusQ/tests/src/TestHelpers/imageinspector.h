#pragma once

#include <QObject>
#include <QSize>

class QQuickItem;

// Exposes what Qt does not: the pixel size an Image actually decoded.
class ImageInspector : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    Q_INVOKABLE QSize decodedSize(QQuickItem* image) const;
    // Changes whenever the image is decoded again.
    Q_INVOKABLE QString decodeKey(QQuickItem* image) const;
    // Whether a Layout attached object (Layout.*) exists on the item, without creating one.
    Q_INVOKABLE bool hasLayoutAttached(QQuickItem* item) const;
};
