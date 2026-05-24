#include "StatusQ/imageencoderutils.h"

#include <QBuffer>
#include <QUrl>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QPixmap>

namespace {

QString encodeToJpegBase64(const QImage &image, int quality)
{
    if (image.isNull())
        return {};

    QByteArray byteArray;
    QBuffer buffer(&byteArray);
    if (!image.save(&buffer, "JPG", quality))
        return {};

    return QByteArrayLiteral("data:image/jpeg;base64,") + byteArray.toBase64();
}

} // namespace

ImageEncoderUtils::ImageEncoderUtils(QQmlEngine *engine)
    : m_engine(engine)
{}

QString ImageEncoderUtils::encodeJpegBase64(const QImage &image, int quality) const
{
    return encodeToJpegBase64(image, quality);
}

QString ImageEncoderUtils::encodeJpegBase64FromUrl(const QUrl &url, int quality) const
{
    if (!url.isValid())
        return {};

    QImage image;

    if (url.scheme() == QLatin1String("image")) {
        if (!m_engine)
            return {};

        const QString providerId = url.host();
        if (providerId.isEmpty())
            return {};

        const auto *providerBase = m_engine->imageProvider(providerId);
        auto *provider = dynamic_cast<QQuickImageProvider *>(
            const_cast<QQmlImageProviderBase *>(providerBase));
        if (!provider)
            return {};

        const QString imageId = url.path().startsWith(u'/') ? url.path().mid(1) : url.path();
        QSize size;

        switch (provider->imageType()) {
        case QQuickImageProvider::Image:
            image = provider->requestImage(imageId, &size, QSize());
            break;
        case QQuickImageProvider::Pixmap:
            image = provider->requestPixmap(imageId, &size, QSize()).toImage();
            break;
        default:
            return {};
        }
    } else if (url.isLocalFile()) {
        image = QImage(url.toLocalFile());
    } else if (url.scheme().isEmpty()) {
        image = QImage(url.toString());
    } else {
        return {};
    }

    return encodeToJpegBase64(image, quality);
}

QObject *ImageEncoderUtils::qmlInstance(QQmlEngine *engine, QJSEngine *)
{
    return new ImageEncoderUtils(engine);
}
