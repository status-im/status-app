#include "StatusQ/browserprofileutils.h"

#include <QtWebEngineQuick/qquickwebengineprofile.h>
#include <QtWebEngineCore/QWebEngineCookieStore>

#include <QLoggingCategory>

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
