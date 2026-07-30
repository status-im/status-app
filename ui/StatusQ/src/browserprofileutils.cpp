#include "StatusQ/browserprofileutils.h"

#include <QtWebEngineQuick/qquickwebengineprofile.h>
#include <QtWebEngineCore/QWebEngineCookieStore>
#include <QtWebEngineCore/QWebEngineDownloadRequest>
#include <QtWebEngineCore/QWebEnginePage>
#include <QtWebEngineCore/QWebEngineProfile>

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

// QML WebEngineView has no page.download(); a Core QWebEnginePage on an OTR
// helper profile forces downloadRequested for Retry (renderable media would
// otherwise navigate/play). Helper does not share the tab's live cookies.
struct BrowserProfileUtils::DownloadHelper
{
    QPointer<QQuickWebEngineProfile> quickProfile;
    QWebEngineProfile *coreProfile = nullptr;
    QWebEnginePage *page = nullptr;
    QMetaObject::Connection downloadConn;
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

    for (DownloadHelper *helper : std::as_const(m_downloadHelpers)) {
        if (helper->downloadConn)
            disconnect(helper->downloadConn);
        if (helper->destroyedConn)
            disconnect(helper->destroyedConn);
        delete helper->page;
        delete helper->coreProfile;
        delete helper;
    }
    m_downloadHelpers.clear();
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

BrowserProfileUtils::DownloadHelper *BrowserProfileUtils::helperFor(QObject *profile)
{
    auto *quickProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!quickProfile)
        return nullptr;

    const quintptr key = reinterpret_cast<quintptr>(quickProfile);
    if (DownloadHelper *existing = m_downloadHelpers.value(key, nullptr))
        return existing;

    auto *helper = new DownloadHelper;
    helper->quickProfile = quickProfile;

    // Always OTR: a named Core profile with the same storageName as the Quick
    // profile risks opening the same on-disk cookie DB twice. Public API cannot
    // attach a QWebEnginePage to the Quick profile's ProfileAdapter, so Retry
    // downloads do not see the tab's live cookies (OK for public CDN media;
    // authenticated Retry may need a revisit).
    helper->coreProfile = new QWebEngineProfile(this);
    helper->page = new QWebEnginePage(helper->coreProfile, this);

    helper->downloadConn = connect(
        helper->coreProfile,
        &QWebEngineProfile::downloadRequested,
        this,
        [this](QWebEngineDownloadRequest *download) {
            QObject *view = m_pendingView.data();
            m_pendingView.clear();
            if (!download)
                return;
            emit downloadRequested(view, download);
        });

    helper->destroyedConn = connect(
        quickProfile,
        &QObject::destroyed,
        this,
        [this, key]() {
            DownloadHelper *gone = m_downloadHelpers.take(key);
            if (!gone)
                return;
            if (gone->downloadConn)
                disconnect(gone->downloadConn);
            if (gone->destroyedConn)
                disconnect(gone->destroyedConn);
            delete gone->page;
            delete gone->coreProfile;
            delete gone;
        });

    m_downloadHelpers.insert(key, helper);
    return helper;
}

void BrowserProfileUtils::downloadUrl(QObject *profile, QObject *webEngineView,
                                      const QUrl &url,
                                      const QString &suggestedFileName)
{
    if (!url.isValid()) {
        qWarning("BrowserProfileUtils::downloadUrl: invalid url");
        return;
    }

    DownloadHelper *helper = helperFor(profile);
    if (!helper || !helper->page) {
        qWarning("BrowserProfileUtils::downloadUrl: expected a WebEngineProfile");
        return;
    }

    m_pendingView = webEngineView;
    helper->page->download(url, suggestedFileName);
}
