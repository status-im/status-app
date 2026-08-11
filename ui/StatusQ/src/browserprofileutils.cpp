#include "StatusQ/browserprofileutils.h"

#include <QtWebEngineQuick/qquickwebengineprofile.h>
#include <QtWebEngineCore/QWebEngineCookieStore>
#include <QtWebEngineCore/QWebEngineDownloadRequest>
#include <QtWebEngineCore/QWebEnginePage>
#include <QtWebEngineCore/QWebEngineProfile>
#include <QtWebEngineCore/QWebEngineUrlRequestInfo>
#include <QtWebEngineCore/QWebEngineUrlRequestInterceptor>

#include <QDir>
#include <QFileInfo>
#include <QNetworkCookie>
#include <QPointer>
#include <QSet>
#include <QStandardPaths>
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

// Keep in sync with BrowserDownloadOpenContext.mediaPlayerDirectory (QML).
constexpr char kMediaPlayerDirName[] = "status-browser-player";

// Resolve symlinks so the two allowed roots and the requested path are compared
// in the same form (macOS TempLocation is /var/... -> /private/var/...).
// canonicalFilePath() is empty for paths that do not exist, hence the fallback.
QString canonicalPath(const QString &path)
{
    if (path.isEmpty())
        return {};
    const QString canonical = QFileInfo(path).canonicalFilePath();
    return canonical.isEmpty() ? QDir::cleanPath(QDir(path).absolutePath()) : canonical;
}

// Canonicalize the (existing) parent and append the leaf, so the root resolves
// even before the leaf is created — the player directory is written lazily, and
// canonicalizing it while absent would leave /var/... unresolved and then fail
// to match the /private/var/... form the same request arrives in later.
QString canonicalSubDir(const QString &parent, const QString &leaf)
{
    const QString root = canonicalPath(parent);
    return root.isEmpty() ? QString() : root + QLatin1Char('/') + leaf;
}

// The Backend's local-browsing policy: file:// navigation is blocked except
// inside the two directories the browser itself writes — the platform downloads
// location (Download Targets) and the temp directory holding generated player
// pages (ADR 0006 §8). Owned here rather than injected from QML so both Backends
// keep the policy library-side; mobilewebview has the equivalent guard.
//
// Scope: navigations only (main frame + subframes), matching what the QML
// navigationRequested handler used to cover. Subresources are deliberately left
// alone so a player page can load the media it points at; Chromium already
// forbids web origins from reaching file:// subresources.
//
// Stateless after construction (two const roots computed on the UI thread), so
// it is safe whichever thread WebEngine calls interceptRequest on.
class LocalUrlPolicyInterceptor final : public QWebEngineUrlRequestInterceptor
{
public:
    explicit LocalUrlPolicyInterceptor(QObject *parent = nullptr)
        : QWebEngineUrlRequestInterceptor(parent)
        , m_downloadsDir(canonicalPath(
              QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)))
        , m_playerDir(canonicalSubDir(
              QStandardPaths::writableLocation(QStandardPaths::TempLocation),
              QLatin1String(kMediaPlayerDirName)))
    {
    }

    void interceptRequest(QWebEngineUrlRequestInfo &info) override
    {
        const QUrl url = info.requestUrl();
        if (!url.isLocalFile())
            return;

        const auto type = info.resourceType();
        if (type != QWebEngineUrlRequestInfo::ResourceTypeMainFrame
            && type != QWebEngineUrlRequestInfo::ResourceTypeSubFrame)
            return;

        if (isAllowed(url.toLocalFile()))
            return;

        qWarning("BrowserProfileUtils: local file browsing is disabled");
        info.block(true);
    }

private:
    bool isAllowed(const QString &localFile) const
    {
        const QString path = canonicalPath(localFile);
        if (path.isEmpty())
            return false;
        return isUnder(path, m_downloadsDir) || isUnder(path, m_playerDir);
    }

    static bool isUnder(const QString &path, const QString &dir)
    {
        // The trailing separator keeps "/home/user/Downloads-evil" out.
        return !dir.isEmpty() && path.startsWith(dir + QLatin1Char('/'));
    }

    const QString m_downloadsDir;
    const QString m_playerDir;
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

// QML WebEngineView has no page.download(); Core QWebEnginePages on an OTR
// helper profile force downloadRequested for Retry (renderable media would
// otherwise navigate/play). Helper does not share the tab's live cookies.
struct BrowserProfileUtils::DownloadHelper
{
    // What downloadUrl() promised to hand back with the download it starts.
    struct Origin
    {
        // QPointer so a destroyed view degrades to null rather than dangling.
        QPointer<QObject> view;
        QString token;
    };

    // Owns the pages in pageViews and the coreProfile they live on; pages must
    // go first so their retire connections die before the helper does.
    ~DownloadHelper()
    {
        for (auto it = pageViews.cbegin(); it != pageViews.cend(); ++it)
            delete it.key();
        pageViews.clear();
        delete coreProfile;
    }

    QPointer<QQuickWebEngineProfile> quickProfile;
    QWebEngineProfile *coreProfile = nullptr;
    QMetaObject::Connection downloadConn;
    QMetaObject::Connection destroyedConn;

    // Live transient download pages (one per downloadUrl() call) mapped to the
    // origin of that call.
    QHash<QWebEnginePage *, Origin> pageViews;
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
        delete helper;
    }
    m_downloadHelpers.clear();
}

void BrowserProfileUtils::installLocalUrlPolicy(QObject *profile)
{
    auto *webProfile = qobject_cast<QQuickWebEngineProfile *>(profile);
    if (!webProfile) {
        qWarning("BrowserProfileUtils::installLocalUrlPolicy: expected a WebEngineProfile");
        return;
    }

    if (!m_localUrlPolicy)
        m_localUrlPolicy = new LocalUrlPolicyInterceptor(this);

    webProfile->setUrlRequestInterceptor(m_localUrlPolicy);

    // A storage profile can fail to instantiate (one live profile per data path),
    // leaving the view on the default profile — it must carry the policy too.
    if (auto *fallback = QQuickWebEngineProfile::defaultProfile();
        fallback && fallback != webProfile)
        fallback->setUrlRequestInterceptor(m_localUrlPolicy);
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

    helper->downloadConn = connect(
        helper->coreProfile,
        &QWebEngineProfile::downloadRequested,
        this,
        [this, helper](QWebEngineDownloadRequest *download) {
            if (!download)
                return;
            // Only downloadUrl() pages live on this profile, so an unknown
            // page() means the request has no identifiable initiator.
            QWebEnginePage *page = download->page();
            const auto it = helper->pageViews.constFind(page);
            if (it == helper->pageViews.cend()) {
                qWarning("BrowserProfileUtils: downloadRequested from an unknown page");
                emit downloadRequested(nullptr, download, QString());
                return;
            }
            const DownloadHelper::Origin origin = it.value();
            retirePageWhenFinished(helper, page, download);
            emit downloadRequested(origin.view.data(), download, origin.token);
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
            delete gone;
        });

    m_downloadHelpers.insert(key, helper);
    return helper;
}

// Whether a download outlives the page it started on is undocumented, so the
// transient page is kept until the download finishes (or is deleted).
void BrowserProfileUtils::retirePageWhenFinished(DownloadHelper *helper,
                                                 QWebEnginePage *page,
                                                 QWebEngineDownloadRequest *download)
{
    // Capturing `helper` raw is safe: both connections have context `page`, and
    // ~DownloadHelper deletes its pages first, so no run can outlive the helper.
    const auto retire = [helper, page]() {
        if (helper->pageViews.remove(page) > 0)
            page->deleteLater();
    };
    connect(download, &QWebEngineDownloadRequest::isFinishedChanged, page,
            [download, retire]() {
                if (download->isFinished())
                    retire();
            });
    connect(download, &QObject::destroyed, page, retire);
}

void BrowserProfileUtils::downloadUrl(QObject *profile, QObject *webEngineView,
                                      const QUrl &url,
                                      const QString &suggestedFileName,
                                      const QString &token)
{
    if (!url.isValid()) {
        qWarning("BrowserProfileUtils::downloadUrl: invalid url");
        return;
    }

    DownloadHelper *helper = helperFor(profile);
    if (!helper || !helper->coreProfile) {
        qWarning("BrowserProfileUtils::downloadUrl: expected a WebEngineProfile");
        return;
    }

    // One page per call: downloadRequested carries page(), so concurrent calls
    // are matched to their initiating view by identity, never by call order.
    auto *page = new QWebEnginePage(helper->coreProfile, this);
    helper->pageViews.insert(page, DownloadHelper::Origin{
                                       QPointer<QObject>(webEngineView), token});
    page->download(url, suggestedFileName);
}
