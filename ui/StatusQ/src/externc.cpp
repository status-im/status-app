#include <QtGlobal>
#include <QDebug>

#include <StatusQ/typesregistration.h>
#include <MobileUI>

#ifdef Q_OS_ANDROID
#include <StatusQ/pushnotification_android.h>
#endif

extern "C" {

Q_DECL_EXPORT void statusq_registerQmlTypes() {
    registerStatusQTypes();
}

Q_DECL_EXPORT float statusq_getMobileUIScaleFactor(float baseWidth, float baseDpi, float baseScale) {
    return MobileUI::getSmartScaleFactor(baseWidth, baseDpi, baseScale);
}

// ============================================================================
// Android Push Notifications C API
// ============================================================================

Q_DECL_EXPORT void statusq_initPushNotifications(
    PushNotificationTokenCallback tokenCallback,
    PushNotificationReceivedCallback receivedCallback)
{
#ifdef Q_OS_ANDROID
    qDebug() << "[StatusQ C API] Initializing Android push notifications...";
    PushNotificationAndroid::instance()->initialize(tokenCallback, receivedCallback);
#else
    Q_UNUSED(tokenCallback);
    Q_UNUSED(receivedCallback);
    qDebug() << "[StatusQ C API] Push notifications not available on this platform";
#endif
}

Q_DECL_EXPORT void statusq_requestNotificationPermission()
{
#ifdef Q_OS_ANDROID
    qDebug() << "[StatusQ C API] Requesting notification permission...";
    PushNotificationAndroid::instance()->requestNotificationPermission();
#else
    qDebug() << "[StatusQ C API] Permission request not needed on this platform";
#endif
}

Q_DECL_EXPORT bool statusq_hasNotificationPermission()
{
#ifdef Q_OS_ANDROID
    return PushNotificationAndroid::instance()->hasNotificationPermission();
#else
    return true; // Other platforms don't require permission
#endif
}

Q_DECL_EXPORT void statusq_showAndroidNotification(
    const char* title,
    const char* message,
    const char* identifier)
{
#ifdef Q_OS_ANDROID
    if (!title || !message || !identifier) {
        qWarning() << "[StatusQ C API] Invalid notification parameters";
        return;
    }

    PushNotificationAndroid::instance()->showNotification(
        QString::fromUtf8(title),
        QString::fromUtf8(message),
        QString::fromUtf8(identifier)
    );
#else
    Q_UNUSED(title);
    Q_UNUSED(message);
    Q_UNUSED(identifier);
    qDebug() << "[StatusQ C API] showNotification not available on this platform";
#endif
}

} // extern "C"
