#pragma once

#include <QHash>
#include <QJSValue>
#include <QObject>
#include <QUrl>

class QWebEngineDownloadRequest;
class QWebEnginePage;
class QWebEngineUrlRequestInterceptor;

// Desktop-only helper exposing WebEngineProfile clearing that the QML
// WebEngineProfile type does not expose (cookie store). Registered only when
// StatusQ is built with Qt WebEngine (STATUSQ_HAS_QTWEBENGINE).
//
// Note: this singleton keeps a small live cookie-name index per profile store
// because Qt 6 cannot enumerate cookies for per-site clear (loadAllCookies does
// not re-emit via cookieAdded). Prefer keeping the index here over scattering
// store subscriptions across QML.
class BrowserProfileUtils : public QObject
{
    Q_OBJECT

public:
    explicit BrowserProfileUtils(QObject *parent = nullptr);
    ~BrowserProfileUtils() override;

    // Subscribe to cookieAdded on the profile's cookie store and keep a live
    // set of cookie names. Must be called once when the profile is created
    // (before first navigation). Names are kept across overwrites (Qt reports
    // overwrite as cookieRemoved only). Persistent cookies restored from disk
    // are not indexed until they are (re)set in the current session.
    Q_INVOKABLE void trackProfile(QObject *profile);

    // Install the local-browsing policy on `profile`: file:// navigation is
    // blocked except under the downloads location and the generated player-page
    // directory (ADR 0006 §8). Call once per profile at creation, before the
    // first navigation. Also (re)installs on the default profile, which backs
    // views whose storage profile could not be created.
    Q_INVOKABLE void installLocalUrlPolicy(QObject *profile);

    // Clears profile-wide browsing data: HTTP cache and all cookies.
    // `profile` must be a QML WebEngineProfile (QQuickWebEngineProfile);
    // no-op with a warning otherwise. Invokes `callback` when clearHttpCache
    // completes (or after a short timeout fallback).
    // Note: global DOM storage / visited links are not clearable via Qt's
    // public API and are therefore left untouched.
    Q_INVOKABLE void clearBrowsingData(QObject *profile, QJSValue callback = {});

    // Clears cookies that belong to `siteUrl`'s host using the live name index
    // from trackProfile (DeleteCookies is URL-scoped). Invokes `callback` when
    // deletes settle (sentinel barrier) so the initiating WebViewAdapter can
    // wipe DOM storage / reload. Pair with injected site_utils.js on the page.
    Q_INVOKABLE void clearSiteData(QObject *profile, const QUrl &siteUrl,
                                   QJSValue callback = {});

    // Force a Download via QWebEnginePage::download (QML WebEngineView has no
    // page.download). Used for Retry — navigating renderable media (video/audio)
    // would play in the tab instead of downloading. `webEngineView` is the
    // initiating view so the matching adapter can forward downloadRequested;
    // null when no view initiated it (host-side Retry needs no live tab).
    // `token` is opaque here — it is echoed back on downloadRequested so the
    // caller can recognise its own re-issue by identity.
    // `profile` must be a QML WebEngineProfile.
    Q_INVOKABLE void downloadUrl(QObject *profile, QObject *webEngineView,
                                 const QUrl &url,
                                 const QString &suggestedFileName = {},
                                 const QString &token = {});

signals:
    // Emitted for downloads started by downloadUrl(). `webEngineView` is the
    // initiator passed to downloadUrl (null when there was none, or when it has
    // since been destroyed); `download` is a QWebEngineDownloadRequest; `token`
    // is the one passed to downloadUrl (empty if the page is unknown).
    void downloadRequested(QObject *webEngineView, QObject *download,
                           const QString &token);

private:
    struct TrackedStore;
    struct DownloadHelper;

    // Stateless policy shared by every profile; owned by this singleton.
    QWebEngineUrlRequestInterceptor *m_localUrlPolicy = nullptr;

    TrackedStore *trackedStoreFor(QObject *profile) const;
    DownloadHelper *helperFor(QObject *profile);
    void retirePageWhenFinished(DownloadHelper *helper, QWebEnginePage *page,
                                QWebEngineDownloadRequest *download);

    // Keyed by cookie store pointer; owned.
    QHash<quintptr, TrackedStore *> m_tracked;
    // Keyed by Quick profile pointer; owned helpers (core profile + pages).
    QHash<quintptr, DownloadHelper *> m_downloadHelpers;
};
