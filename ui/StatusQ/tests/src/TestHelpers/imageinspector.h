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
};
