#include <StatusQ/networkaccessfactory.h>

#include <StatusQ/httpstats.h>

#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QNetworkReply>
#include <QQmlEngine>
#include <QUrl>

#include <memory>

namespace Status {

namespace {

// Feeds HttpStats for the QML-layer HTTP statistics screen.
class CountingNetworkAccessManager : public QNetworkAccessManager
{
public:
    using QNetworkAccessManager::QNetworkAccessManager;

protected:
    QNetworkReply* createRequest(Operation op, const QNetworkRequest& request,
                                 QIODevice* outgoingData) override
    {
        auto* reply = QNetworkAccessManager::createRequest(op, withAcceptedImageFormats(request),
                                                          outgoingData);

        const QUrl url = request.url();
        if (!url.host().isEmpty()) {
            // The port distinguishes the local status-go media server from
            // everything else, which is worth seeing on the screen.
            const QString host = url.port() > 0
                ? QStringLiteral("%1:%2").arg(url.host()).arg(url.port())
                : url.host();

            // Bytes come from downloadProgress rather than Content-Length:
            // the header is absent on some responses and wrong on chunked ones.
            auto received = std::make_shared<qint64>(0);
            QObject::connect(reply, &QNetworkReply::downloadProgress, reply,
                             [received](qint64 bytesReceived, qint64) {
                                 *received = bytesReceived;
                             });
            QObject::connect(reply, &QNetworkReply::finished, reply, [reply, host, received]() {
                const bool fromCache =
                    reply->attribute(QNetworkRequest::SourceIsFromCacheAttribute).toBool();
                qint64 bytes = *received;
                if (bytes == 0) {
                    // A cache hit can complete without ever reporting progress.
                    const QVariant length = reply->header(QNetworkRequest::ContentLengthHeader);
                    if (length.isValid())
                        bytes = length.toLongLong();
                }
                HttpStats::instance().record(host, bytes, fromCache);
            });
        }

        return reply;
    }
};

} // namespace

QNetworkRequest withAcceptedImageFormats(const QNetworkRequest& request)
{
    if (request.hasRawHeader("Accept"))
        return request;

    const QUrl url = request.url();
    if (url.host() != QLatin1String("res.cloudinary.com"))
        return request;

    // Both delivery paths Utils.resizedMediaSource writes f_auto into: /image/upload/
    // for a still image, /video/fetch/ for the still frame of an animated collectible.
    const QString path = url.path();
    if (!path.contains(QLatin1String("/image/upload/"))
        && !path.contains(QLatin1String("/video/fetch/")))
        return request;

    QNetworkRequest hinted(request);
    hinted.setRawHeader("Accept", "image/webp,image/png,image/jpeg");
    return hinted;
}

NetworkAccessFactory::NetworkAccessFactory(const QString& cacheDir, qint64 maxCacheSize)
    : m_cacheDir(cacheDir)
    , m_maxCacheSize(maxCacheSize)
{
}

QNetworkAccessManager* NetworkAccessFactory::create(QObject* parent)
{
    auto* manager = new CountingNetworkAccessManager(parent);
    auto* cache = new QNetworkDiskCache(manager);
    cache->setCacheDirectory(m_cacheDir);
    cache->setMaximumCacheSize(m_maxCacheSize);
    manager->setCache(cache);
    HttpStats::instance().registerCache(cache);
    return manager;
}

void setupNetworkAccessManagerFactory(QQmlEngine* engine, const QString& cacheDir,
                                      qint64 maxCacheSize)
{
    // Construct HttpStats on the GUI thread before any NAM factory worker can
    // first-touch it with the wrong QObject affinity (see HttpStats::instance).
    (void)HttpStats::instance();
    engine->setNetworkAccessManagerFactory(new NetworkAccessFactory(cacheDir, maxCacheSize));
}

} // namespace Status
