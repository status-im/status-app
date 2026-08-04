#pragma once

#include <QHash>
#include <QMutex>
#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class QNetworkDiskCache;
class QQmlEngine;
class QJSEngine;

/*!
 * Per-host accounting of everything the QML engine's network access manager
 * fetches. Fed by CountingNetworkAccessManager (src/networkaccessfactory.cpp),
 * read by the HTTP statistics screen in settings.
 *
 * Network and cache are counted separately on purpose: a total that mixes them
 * cannot show that a cache is working, which is the question the screen exists
 * to answer.
 *
 * What this does NOT see, because it never passes through this manager:
 * status-go, messaging, the web engine, and the thread_local managers in
 * systemutilsinternal.cpp and clipboardutils.cpp. The screen says so itself.
 */
class HttpStats : public QObject
{
    Q_OBJECT

public:
    static HttpStats& instance();
    static QObject* qmlInstance(QQmlEngine* engine, QJSEngine* scriptEngine);

    //! Record one finished reply. Callable from any thread a manager lives on.
    void record(const QString& host, qint64 bytes, bool fromCache);

    //! Take note of a disk cache so the screen can report and clear it. Call
    //! from the thread the cache lives on, right after it is configured.
    void registerCache(QNetworkDiskCache* cache);

    //! directory, size (measured on disk) and maximumSize of the disk cache.
    //! Walks the directory, so call it on demand — not on every recorded reply.
    Q_INVOKABLE QVariantMap cache() const;

    //! Empty every registered cache. Required to reproduce a cold measurement
    //! without reinstalling the application.
    Q_INVOKABLE void clearCache();

    //! One entry per host: host, networkRequests, networkBytes,
    //! cacheRequests, cacheBytes. Ordered by total bytes, heaviest first.
    Q_INVOKABLE QVariantList hosts() const;

    //! networkRequests, networkBytes, cacheRequests, cacheBytes across all hosts.
    Q_INVOKABLE QVariantMap totals() const;

    Q_INVOKABLE void reset();

signals:
    //! Emitted when a reply has been recorded, so an open screen can refresh.
    void changed();

    //! Emitted once per cache when clearCache() has finished on that cache's
    //! thread. Separate from changed(), which fires on every reply and so must
    //! not be what a reader hangs an expensive re-measurement on.
    void cacheCleared();

private:
    explicit HttpStats(QObject* parent = nullptr);
    void notifyChanged();
    void emitOnOwnThread(void (HttpStats::*signal)());

    struct Entry {
        qint64 networkRequests = 0;
        qint64 networkBytes = 0;
        qint64 cacheRequests = 0;
        qint64 cacheBytes = 0;
    };

    mutable QMutex m_mutex;
    QHash<QString, Entry> m_entries;

    QString m_cacheDirectory;
    qint64 m_cacheMaximumSize = 0;
    QVector<QPointer<QNetworkDiskCache>> m_caches;
};
