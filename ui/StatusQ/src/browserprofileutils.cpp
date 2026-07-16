#include "StatusQ/browserprofileutils.h"

#include <QtWebEngineQuick/qquickwebengineprofile.h>
#include <QtWebEngineCore/QWebEngineCookieStore>

#include <QNetworkCookie>
#include <QPointer>
#include <QSet>
#include <QTimer>

#include <functional>

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

namespace {

// One-shot: deleteCookie(name, siteUrl) for each known name → wait / timeout → notify.
// Chromium's DeleteCookies filter scopes by URL, so same-named cookies on other
// hosts are not removed.
class SiteCookieClearOp : public QObject
{
public:
    SiteCookieClearOp(QWebEngineCookieStore *store,
                      QSet<QByteArray> names,
                      QUrl siteUrl,
                      std::function<void()> onDone,
                      QObject *parent = nullptr)
        : QObject(parent)
        , m_store(store)
        , m_names(std::move(names))
        , m_siteUrl(std::move(siteUrl))
        , m_onDone(std::move(onDone))
        , m_timeout(this)
    {
        m_timeout.setSingleShot(true);
        m_timeout.setInterval(1000);
        connect(&m_timeout, &QTimer::timeout, this, [this]() { finish(); });
    }

    void start()
    {
        if (!m_store || m_siteUrl.host().isEmpty() || m_names.isEmpty()) {
            done();
            return;
        }

        m_pendingNames = m_names;

        m_removedConn = connect(
            m_store,
            &QWebEngineCookieStore::cookieRemoved,
            this,
            [this](const QNetworkCookie &cookie) {
                m_pendingNames.remove(cookie.name());
                if (m_pendingNames.isEmpty())
                    finish();
            });

        for (const QByteArray &name : std::as_const(m_names)) {
            QNetworkCookie cookie(name);
            m_store->deleteCookie(cookie, m_siteUrl);
        }

        m_timeout.start();
    }

private:
    void finish()
    {
        if (m_finished)
            return;
        m_finished = true;
        if (m_removedConn)
            disconnect(m_removedConn);
        m_timeout.stop();
        done();
    }

    void done()
    {
        if (m_onDone)
            m_onDone();
        deleteLater();
    }

    QPointer<QWebEngineCookieStore> m_store;
    QSet<QByteArray> m_names;
    QUrl m_siteUrl;
    QSet<QByteArray> m_pendingNames;
    QMetaObject::Connection m_removedConn;
    QTimer m_timeout;
    std::function<void()> m_onDone;
    bool m_finished = false;
};

} // namespace

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

void BrowserProfileUtils::clearBrowsingData(QObject *profile)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile) {
        qWarning("BrowserProfileUtils::clearBrowsingData: expected a WebEngineProfile");
        return;
    }

    if (auto *cookieStore = webProfile->cookieStore()) {
        cookieStore->deleteAllCookies();
        if (TrackedStore *tracked = trackedStoreFor(profile))
            tracked->cookieNames.clear();
    }

    // Async; the profile emits clearHttpCacheCompleted when done.
    webProfile->clearHttpCache();
}

void BrowserProfileUtils::clearSiteData(QObject *profile, const QUrl &siteUrl)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile) {
        qWarning("BrowserProfileUtils::clearSiteData: expected a WebEngineProfile");
        emit clearSiteDataCompleted();
        return;
    }

    if (siteUrl.host().isEmpty()) {
        qWarning("BrowserProfileUtils::clearSiteData: empty host; ignoring");
        emit clearSiteDataCompleted();
        return;
    }

    TrackedStore *tracked = trackedStoreFor(profile);
    if (!tracked || !tracked->store) {
        qWarning("BrowserProfileUtils::clearSiteData: profile not tracked "
                 "(call trackProfile at profile creation); ignoring");
        emit clearSiteDataCompleted();
        return;
    }

    auto *op = new SiteCookieClearOp(
        tracked->store,
        tracked->cookieNames,
        siteUrl,
        [this]() { emit clearSiteDataCompleted(); },
        this);
    op->start();
}
