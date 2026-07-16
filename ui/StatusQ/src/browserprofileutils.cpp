#include "StatusQ/browserprofileutils.h"

#include <QtWebEngineQuick/qquickwebengineprofile.h>
#include <QtWebEngineCore/QWebEngineCookieStore>

#include <QNetworkCookie>
#include <QPointer>
#include <QSet>
#include <QTimer>

namespace {

// Written after deletes so cookieAdded(sentinel) means the store has applied
// every prior deleteCookie for this host (Mojo IPC is ordered per store).
constexpr char kClearBarrierCookieName[] = "__status_clear_barrier";

void invokeCallback(QJSValue callback)
{
    if (!callback.isCallable())
        return;
    const QJSValue result = callback.call();
    if (result.isError())
        qWarning("BrowserProfileUtils: clear callback threw: %s",
                 qPrintable(result.toString()));
}

// One-shot: deleteCookie(name, siteUrl) for each known name, then set a sentinel
// cookie and wait for cookieAdded(sentinel) before notifying. No pending-name
// counters — Mojo ordering guarantees deletes are applied before the add.
class SiteCookieClearOp : public QObject
{
public:
    SiteCookieClearOp(QWebEngineCookieStore *store,
                      QSet<QByteArray> names,
                      QUrl siteUrl,
                      QJSValue callback,
                      QObject *parent = nullptr)
        : QObject(parent)
        , m_store(store)
        , m_names(std::move(names))
        , m_siteUrl(std::move(siteUrl))
        , m_callback(std::move(callback))
        , m_timeout(this)
    {
        m_timeout.setSingleShot(true);
        m_timeout.setInterval(2000);
        connect(&m_timeout, &QTimer::timeout, this, [this]() { finish(); });
    }

    void start()
    {
        if (!m_store || m_siteUrl.host().isEmpty()) {
            done();
            return;
        }

        m_names.remove(QByteArray(kClearBarrierCookieName));

        m_addedConn = connect(
            m_store,
            &QWebEngineCookieStore::cookieAdded,
            this,
            [this](const QNetworkCookie &cookie) {
                if (cookie.name() != QByteArray(kClearBarrierCookieName))
                    return;
                // Drop the sentinel so it does not linger on the site.
                m_store->deleteCookie(cookie, m_siteUrl);
                finish();
            });

        for (const QByteArray &name : std::as_const(m_names)) {
            QNetworkCookie cookie(name);
            m_store->deleteCookie(cookie, m_siteUrl);
        }

        QNetworkCookie barrier(QByteArray(kClearBarrierCookieName),
                               QByteArrayLiteral("1"));
        barrier.setPath(QStringLiteral("/"));
        m_store->setCookie(barrier, m_siteUrl);

        m_timeout.start();
    }

private:
    void finish()
    {
        if (m_finished)
            return;
        m_finished = true;
        if (m_addedConn)
            disconnect(m_addedConn);
        m_timeout.stop();
        done();
    }

    void done()
    {
        invokeCallback(m_callback);
        deleteLater();
    }

    QPointer<QWebEngineCookieStore> m_store;
    QSet<QByteArray> m_names;
    QUrl m_siteUrl;
    QJSValue m_callback;
    QMetaObject::Connection m_addedConn;
    QTimer m_timeout;
    bool m_finished = false;
};

// One-shot: wait for clearHttpCacheCompleted (or timeout), then invoke callback.
class BrowsingDataClearOp : public QObject
{
public:
    BrowsingDataClearOp(QQuickWebEngineProfile *profile,
                        QJSValue callback,
                        QObject *parent = nullptr)
        : QObject(parent)
        , m_profile(profile)
        , m_callback(std::move(callback))
        , m_timeout(this)
    {
        m_timeout.setSingleShot(true);
        m_timeout.setInterval(2000);
        connect(&m_timeout, &QTimer::timeout, this, [this]() { finish(); });
    }

    void start()
    {
        if (!m_profile) {
            done();
            return;
        }

        m_cacheConn = connect(
            m_profile,
            &QQuickWebEngineProfile::clearHttpCacheCompleted,
            this,
            [this]() { finish(); });

        m_profile->clearHttpCache();
        m_timeout.start();
    }

private:
    void finish()
    {
        if (m_finished)
            return;
        m_finished = true;
        if (m_cacheConn)
            disconnect(m_cacheConn);
        m_timeout.stop();
        done();
    }

    void done()
    {
        invokeCallback(m_callback);
        deleteLater();
    }

    QPointer<QQuickWebEngineProfile> m_profile;
    QJSValue m_callback;
    QMetaObject::Connection m_cacheConn;
    QTimer m_timeout;
    bool m_finished = false;
};

} // namespace

struct BrowserProfileUtils::TrackedStore
{
    QPointer<QWebEngineCookieStore> store;
    // Cookie names observed via cookieAdded. Qt 6 reports overwrites
    // (e.g. JS cookie replaced by HttpOnly Set-Cookie) as cookieRemoved only,
    // so we never drop names on removal — stale names make deleteCookie a no-op.
    QSet<QByteArray> cookieNames;
    QMetaObject::Connection addedConn;
    QMetaObject::Connection destroyedConn;
};

BrowserProfileUtils::BrowserProfileUtils(QObject *parent)
    : QObject(parent)
{
}

BrowserProfileUtils::~BrowserProfileUtils()
{
    for (TrackedStore *tracked : std::as_const(m_tracked)) {
        if (tracked->addedConn)
            disconnect(tracked->addedConn);
        if (tracked->destroyedConn)
            disconnect(tracked->destroyedConn);
        delete tracked;
    }
    m_tracked.clear();
}

BrowserProfileUtils::TrackedStore *BrowserProfileUtils::trackedStoreFor(QObject *profile) const
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile)
        return nullptr;
    auto *store = webProfile->cookieStore();
    if (!store)
        return nullptr;
    return m_tracked.value(reinterpret_cast<quintptr>(store), nullptr);
}

void BrowserProfileUtils::trackProfile(QObject *profile)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile) {
        qWarning("BrowserProfileUtils::trackProfile: expected a WebEngineProfile");
        return;
    }

    auto *store = webProfile->cookieStore();
    if (!store) {
        qWarning("BrowserProfileUtils::trackProfile: no cookie store");
        return;
    }

    const quintptr key = reinterpret_cast<quintptr>(store);
    if (m_tracked.contains(key))
        return;

    auto *tracked = new TrackedStore;
    tracked->store = store;

    tracked->addedConn = connect(
        store,
        &QWebEngineCookieStore::cookieAdded,
        this,
        [tracked](const QNetworkCookie &cookie) {
            if (cookie.name() == QByteArray(kClearBarrierCookieName))
                return;
            tracked->cookieNames.insert(cookie.name());
        });

    tracked->destroyedConn = connect(
        store,
        &QObject::destroyed,
        this,
        [this, key]() {
            TrackedStore *gone = m_tracked.take(key);
            if (!gone)
                return;
            if (gone->addedConn)
                disconnect(gone->addedConn);
            delete gone;
        });

    m_tracked.insert(key, tracked);
}

void BrowserProfileUtils::clearBrowsingData(QObject *profile, QJSValue callback)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile) {
        qWarning("BrowserProfileUtils::clearBrowsingData: expected a WebEngineProfile");
        invokeCallback(callback);
        return;
    }

    if (auto *cookieStore = webProfile->cookieStore()) {
        cookieStore->deleteAllCookies();
        if (TrackedStore *tracked = trackedStoreFor(profile))
            tracked->cookieNames.clear();
    }

    auto *op = new BrowsingDataClearOp(webProfile, std::move(callback), this);
    op->start();
}

void BrowserProfileUtils::clearSiteData(QObject *profile, const QUrl &siteUrl,
                                        QJSValue callback)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile) {
        qWarning("BrowserProfileUtils::clearSiteData: expected a WebEngineProfile");
        invokeCallback(callback);
        return;
    }

    if (siteUrl.host().isEmpty()) {
        qWarning("BrowserProfileUtils::clearSiteData: empty host; ignoring");
        invokeCallback(callback);
        return;
    }

    TrackedStore *tracked = trackedStoreFor(profile);
    if (!tracked || !tracked->store) {
        qWarning("BrowserProfileUtils::clearSiteData: profile not tracked "
                 "(call trackProfile at profile creation); ignoring");
        invokeCallback(callback);
        return;
    }

    auto *op = new SiteCookieClearOp(
        tracked->store,
        tracked->cookieNames,
        siteUrl,
        std::move(callback),
        this);
    op->start();
}
