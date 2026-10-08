#pragma once

#include <QObject>
#include <QSize>
#include <QTemporaryDir>
#include <QUrl>

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
    // Writes a fresh image file (unknown to any cache); rotated90 stores it with an EXIF
    // orientation that autoTransform turns by 90 degrees.
    Q_INVOKABLE QUrl writeImage(int width, int height, const QString& format = QStringLiteral("png"),
                                bool rotated90 = false);

private:
    QTemporaryDir m_dir;
    int m_written = 0;
};
