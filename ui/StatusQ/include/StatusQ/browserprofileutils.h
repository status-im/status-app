#pragma once

#include <QObject>
#include <QUrl>

// Desktop-only helper exposing WebEngineProfile clearing that the QML
// WebEngineProfile type does not expose (cookie store). Registered only when
// StatusQ is built with Qt WebEngine (STATUSQ_HAS_QTWEBENGINE).
class BrowserProfileUtils : public QObject
{
    Q_OBJECT

public:
    explicit BrowserProfileUtils(QObject *parent = nullptr);

    // Clears profile-wide browsing data: HTTP cache and all cookies.
    // `profile` must be a QML WebEngineProfile (QQuickWebEngineProfile);
    // no-op with a warning otherwise. The profile's clearHttpCacheCompleted
    // signal still fires, so QML can drive completion/reload handling.
    // Note: global DOM storage / visited links are not clearable via Qt's
    // public API and are therefore left untouched.
    Q_INVOKABLE void clearBrowsingData(QObject *profile);

    // Clears cookies that belong to `siteUrl`'s host (including Domain-scoped
    // cookies that cover it, e.g. .example.com for www.example.com). Emits
    // clearSiteDataCompleted when the cookie store load+delete settles.
    // Pair with injected site_utils.js on the page for DOM storage; WebEngine
    // has no public per-site HTTP cache / DOM storage API in C++.
    Q_INVOKABLE void clearSiteData(QObject *profile, const QUrl &siteUrl);

signals:
    void clearSiteDataCompleted();
};
