#pragma once

#include <QObject>
#include <QImage>

class QJSEngine;
class QQmlEngine;
class QUrl;

class ImageEncoderUtils : public QObject
{
    Q_OBJECT

    explicit ImageEncoderUtils(QQmlEngine *engine);

public:
    Q_INVOKABLE QString encodeJpegBase64(const QImage &image, int quality = 70) const;
    Q_INVOKABLE QString encodeJpegBase64FromUrl(const QUrl &url, int quality = 70) const;

    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

private:
    QQmlEngine *m_engine = nullptr;
};
