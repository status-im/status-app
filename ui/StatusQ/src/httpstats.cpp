#include "StatusQ/httpstats.h"

#include <QCoreApplication>
#include <QDirIterator>
#include <QFileInfo>
#include <QMetaObject>
#include <QMutexLocker>
#include <QNetworkDiskCache>
#include <QQmlEngine>
#include <QThread>

#include <algorithm>

HttpStats::HttpStats(QObject* parent)
    : QObject(parent)
{
}

HttpStats& HttpStats::instance()
{
    // Heap-allocated so we can moveToThread: NAM factory workers must not pin
    // this QObject to a non-GUI thread (QQmlEngine Connections require GUI affinity).
    static HttpStats& ref = *[]() -> HttpStats* {
        auto* stats = new HttpStats;
        if (auto* app = QCoreApplication::instance()) {
            QThread* guiThread = app->thread();
            if (stats->thread() != guiThread)
                stats->moveToThread(guiThread);
        }
        return stats;
    }();
    return ref;
}

QObject* HttpStats::qmlInstance(QQmlEngine* engine, QJSEngine* scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    // Process-lifetime singleton shared with the network access managers; the
    // QML engine must not take ownership of it.
    QQmlEngine::setObjectOwnership(&instance(), QQmlEngine::CppOwnership);
    return &instance();
}

void HttpStats::notifyChanged()
{
    emitOnOwnThread(&HttpStats::changed);
}

void HttpStats::emitOnOwnThread(void (HttpStats::*signal)())
{
    // record()/clearCache() are called from NAM threads. Emitting from this
    // object's own thread keeps every receiver's connection type resolved the
    // same way, whoever the caller was.
    if (QThread::currentThread() == thread())
        (this->*signal)();
    else
        QMetaObject::invokeMethod(this, signal, Qt::QueuedConnection);
}

void HttpStats::record(const QString& host, qint64 bytes, bool fromCache)
{
    if (host.isEmpty())
        return;

    {
        QMutexLocker locker(&m_mutex);
        auto& entry = m_entries[host];
        if (fromCache) {
            entry.cacheRequests += 1;
            entry.cacheBytes += std::max<qint64>(bytes, 0);
        } else {
            entry.networkRequests += 1;
            entry.networkBytes += std::max<qint64>(bytes, 0);
        }
    }

    notifyChanged();
}

QVariantList HttpStats::hosts() const
{
    QVariantList result;

    {
        QMutexLocker locker(&m_mutex);
        result.reserve(m_entries.size());
        for (auto it = m_entries.cbegin(); it != m_entries.cend(); ++it) {
            result.append(QVariantMap{
                {QStringLiteral("host"), it.key()},
                {QStringLiteral("networkRequests"), it.value().networkRequests},
                {QStringLiteral("networkBytes"), it.value().networkBytes},
                {QStringLiteral("cacheRequests"), it.value().cacheRequests},
                {QStringLiteral("cacheBytes"), it.value().cacheBytes},
            });
        }
    }

    std::sort(result.begin(), result.end(), [](const QVariant& lhs, const QVariant& rhs) {
        const auto left = lhs.toMap();
        const auto right = rhs.toMap();
        const auto weight = [](const QVariantMap& row) {
            return row.value(QStringLiteral("networkBytes")).toLongLong()
                 + row.value(QStringLiteral("cacheBytes")).toLongLong();
        };
        return weight(left) > weight(right);
    });

    return result;
}

QVariantMap HttpStats::totals() const
{
    Entry total;

    {
        QMutexLocker locker(&m_mutex);
        for (const auto& entry : m_entries) {
            total.networkRequests += entry.networkRequests;
            total.networkBytes += entry.networkBytes;
            total.cacheRequests += entry.cacheRequests;
            total.cacheBytes += entry.cacheBytes;
        }
    }

    return QVariantMap{
        {QStringLiteral("networkRequests"), total.networkRequests},
        {QStringLiteral("networkBytes"), total.networkBytes},
        {QStringLiteral("cacheRequests"), total.cacheRequests},
        {QStringLiteral("cacheBytes"), total.cacheBytes},
    };
}

void HttpStats::registerCache(QNetworkDiskCache* cache)
{
    if (cache == nullptr)
        return;

    QMutexLocker locker(&m_mutex);
    m_caches.append(QPointer<QNetworkDiskCache>(cache));
    // All managers share one directory/limit; take them from the first cache.
    m_cacheDirectory = cache->cacheDirectory();
    m_cacheMaximumSize = cache->maximumCacheSize();
}

QVariantMap HttpStats::cache() const
{
    QString directory;
    qint64 maximumSize = 0;

    {
        QMutexLocker locker(&m_mutex);
        directory = m_cacheDirectory;
        maximumSize = m_cacheMaximumSize;
    }

    // Measured on disk rather than through QNetworkDiskCache::cacheSize().
    // Several caches share this directory (see the accepted risk in ADR 0006),
    // and each of them counts only its own writes, so no single one of them
    // knows what is there. The directory does.
    qint64 size = 0;
    if (!directory.isEmpty()) {
        QDirIterator it(directory, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            size += it.fileInfo().size();
        }
    }

    return QVariantMap{
        {QStringLiteral("directory"), directory},
        {QStringLiteral("size"), size},
        {QStringLiteral("maximumSize"), maximumSize},
    };
}

void HttpStats::clearCache()
{
    QVector<QPointer<QNetworkDiskCache>> caches;

    {
        QMutexLocker locker(&m_mutex);
        m_caches.removeIf([](const QPointer<QNetworkDiskCache>& cache) { return cache.isNull(); });
        caches = m_caches;
    }

    if (caches.isEmpty()) {
        emitOnOwnThread(&HttpStats::cacheCleared);
        return;
    }

    for (const auto& cache : caches) {
        if (cache.isNull())
            continue;
        // Clear on the cache's thread, and report from inside the same call so a
        // screen refreshing on cacheCleared() measures the directory afterwards
        // rather than before.
        QMetaObject::invokeMethod(cache, [this, cache]() {
            if (!cache.isNull())
                cache->clear();
            emitOnOwnThread(&HttpStats::cacheCleared);
        }, Qt::QueuedConnection);
    }
}

void HttpStats::reset()
{
    {
        QMutexLocker locker(&m_mutex);
        m_entries.clear();
    }

    notifyChanged();
}
