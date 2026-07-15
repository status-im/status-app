#include "StatusQ/browserprofileutils.h"

#include <QtWebEngineQuick/qquickwebengineprofile.h>
#include <QtWebEngineCore/QWebEngineCookieStore>

#include <QList>
#include <QNetworkCookie>
#include <QPointer>
#include <QTimer>

#include <functional>

namespace {

bool hostMatchesCookieDomain(const QString &host, QString domain)
{
    if (domain.startsWith(QLatin1Char('.')))
        domain.remove(0, 1);
    if (domain.isEmpty() || host.isEmpty())
        return false;
    return host.compare(domain, Qt::CaseInsensitive) == 0
        || host.endsWith(QLatin1Char('.') + domain, Qt::CaseInsensitive);
}

// One-shot: loadAllCookies → collect matches → deleteCookie → notify.
// No Q_OBJECT / moc: lambdas + QTimer are enough.
class SiteCookieClearOp : public QObject
{
public:
    SiteCookieClearOp(QWebEngineCookieStore *store,
                      QUrl siteUrl,
                      std::function<void()> onDone,
                      QObject *parent = nullptr)
        : QObject(parent)
        , m_store(store)
        , m_siteUrl(std::move(siteUrl))
        , m_host(m_siteUrl.host())
        , m_onDone(std::move(onDone))
        , m_settle(this)
    {
        m_settle.setSingleShot(true);
        m_settle.setInterval(100);
        QObject::connect(&m_settle, &QTimer::timeout, this, [this]() { finish(); });
    }

    void start()
    {
        if (!m_store || m_host.isEmpty()) {
            done();
            return;
        }

        m_conn = QObject::connect(
            m_store,
            &QWebEngineCookieStore::cookieAdded,
            this,
            [this](const QNetworkCookie &cookie) { onCookieAdded(cookie); });

        m_store->loadAllCookies();
        // Complete even when the store has no cookies (no cookieAdded flood).
        m_settle.start();
    }

private:
    void onCookieAdded(const QNetworkCookie &cookie)
    {
        const QString domain = cookie.domain();
        // Empty domain = host-only cookie; deleteCookie(..., siteUrl) scopes it.
        if (domain.isEmpty() || hostMatchesCookieDomain(m_host, domain))
            m_pending.append(cookie);
        m_settle.start();
    }

    void finish()
    {
        if (m_conn)
            QObject::disconnect(m_conn);

        if (m_store) {
            for (const QNetworkCookie &cookie : std::as_const(m_pending))
                m_store->deleteCookie(cookie, m_siteUrl);
        }
        done();
    }

    void done()
    {
        if (m_onDone)
            m_onDone();
        deleteLater();
    }

    QPointer<QWebEngineCookieStore> m_store;
    QUrl m_siteUrl;
    QString m_host;
    QList<QNetworkCookie> m_pending;
    QMetaObject::Connection m_conn;
    QTimer m_settle;
    std::function<void()> m_onDone;
};

} // namespace

BrowserProfileUtils::BrowserProfileUtils(QObject *parent)
    : QObject(parent)
{
}

void BrowserProfileUtils::clearBrowsingData(QObject *profile)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile*>(profile);
    if (!webProfile) {
        qWarning("BrowserProfileUtils::clearBrowsingData: expected a WebEngineProfile");
        return;
    }

    if (auto *cookieStore = webProfile->cookieStore())
        cookieStore->deleteAllCookies();

    // Async; the profile emits clearHttpCacheCompleted when done.
    webProfile->clearHttpCache();
}

void BrowserProfileUtils::clearSiteData(QObject *profile, const QUrl &siteUrl)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile*>(profile);
    if (!webProfile) {
        qWarning("BrowserProfileUtils::clearSiteData: expected a WebEngineProfile");
        emit clearSiteDataCompleted();
        return;
    }

    auto *cookieStore = webProfile->cookieStore();
    if (!cookieStore || siteUrl.host().isEmpty()) {
        qWarning("BrowserProfileUtils::clearSiteData: no cookie store or empty host; ignoring");
        emit clearSiteDataCompleted();
        return;
    }

    auto *op = new SiteCookieClearOp(
        cookieStore,
        siteUrl,
        [this]() { emit clearSiteDataCompleted(); },
        this);
    op->start();
}
