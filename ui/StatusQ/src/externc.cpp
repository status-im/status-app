#include <QtGlobal>
#include <QDebug>

#include <StatusQ/typesregistration.h>
#include <MobileUI>

#ifdef Q_OS_ANDROID
#include <StatusQ/pushnotification_android.h>
#endif

#ifdef Q_OS_IOS
#include <cstdlib>
#include <cstring>
#include <CoreFoundation/CoreFoundation.h>
#include <StatusQ/pushnotification_ios.h>
#include <StatusQ/statusappdelegate_ios.h>
#endif

// ============================================================================
// Push Notification Callback Types (cross-platform)
// ============================================================================
// Define these outside platform-specific blocks so they're available on all platforms
// Use include guard to prevent duplicate definitions with platform headers
#ifndef PUSH_NOTIFICATION_CALLBACKS_DEFINED
#define PUSH_NOTIFICATION_CALLBACKS_DEFINED
typedef void (*PushNotificationTokenCallback)(const char* token);
typedef void (*PushNotificationReceivedCallback)(const char* encryptedMessage, const char* chatId, const char* publicKey);
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
#elif defined(Q_OS_IOS)
    qDebug() << "[StatusQ C API] Initializing iOS push notifications...";
    
    // CRITICAL: Initialize app delegate category to prevent LTO from stripping it!
    statusq_initIOSAppDelegateCategory();
    
    PushNotificationIOS::instance()->initialize(tokenCallback, receivedCallback);
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
#elif defined(Q_OS_IOS)
    qDebug() << "[StatusQ C API] Requesting notification permission...";
    PushNotificationIOS::instance()->requestNotificationPermission();
#else
    qDebug() << "[StatusQ C API] Permission request not needed on this platform";
#endif
}

Q_DECL_EXPORT bool statusq_hasNotificationPermission()
{
#ifdef Q_OS_ANDROID
    return PushNotificationAndroid::instance()->hasNotificationPermission();
#elif defined(Q_OS_IOS)
    return PushNotificationIOS::instance()->hasNotificationPermission();
#else
    return true; // Other platforms don't require permission
#endif
}

#ifdef Q_OS_IOS
// Returns a heap-allocated C string; caller must free with statusq_freeCString.
Q_DECL_EXPORT const char* statusq_getIOSBundleIdentifier()
{
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    if (!mainBundle) {
        return strdup("");
    }

    CFStringRef bundleId = CFBundleGetIdentifier(mainBundle);
    if (!bundleId) {
        return strdup("");
    }

    // CFBundle identifier strings are small; this buffer is intentionally generous.
    char buffer[1024] = {0};
    if (!CFStringGetCString(bundleId, buffer, sizeof(buffer), kCFStringEncodingUTF8)) {
        return strdup("");
    }
    return strdup(buffer);
}

Q_DECL_EXPORT void statusq_freeCString(const char* s)
{
    if (s) {
        std::free((void*)s);
    }
}
#endif

Q_DECL_EXPORT void statusq_showMobileNotification(
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
#elif defined(Q_OS_IOS)
    if (!title || !message || !identifier) {
        qWarning() << "[StatusQ C API] Invalid notification parameters";
        return;
    }

    PushNotificationIOS::instance()->showNotification(
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

// Deprecated: Use statusq_showMobileNotification instead
Q_DECL_EXPORT void statusq_showAndroidNotification(
    const char* title,
    const char* message,
    const char* identifier)
{
    statusq_showMobileNotification(title, message, identifier);
}

} // extern "C"
