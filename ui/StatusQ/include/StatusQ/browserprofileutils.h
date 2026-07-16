#pragma once

#include <QHash>
#include <QJSValue>
#include <QObject>
#include <QUrl>

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

private:
    struct TrackedStore;

    TrackedStore *trackedStoreFor(QObject *profile) const;

    // Keyed by cookie store pointer; owned.
    QHash<quintptr, TrackedStore *> m_tracked;
};
