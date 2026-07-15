#pragma once

#include <QObject>

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
};
