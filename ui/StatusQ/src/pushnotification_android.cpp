#include "StatusQ/pushnotification_android.h"

#ifdef Q_OS_ANDROID

#include <QJniObject>
#include <QJniEnvironment>
#include <QDebug>
#include <QCoreApplication>

// Static instance and callbacks
PushNotificationAndroid* PushNotificationAndroid::s_instance = nullptr;
static PushNotificationTokenCallback s_tokenCallback = nullptr;
static PushNotificationReceivedCallback s_receivedCallback = nullptr;

PushNotificationAndroid::PushNotificationAndroid(QObject* parent)
    : QObject(parent)
    , m_initialized(false)
{
}

PushNotificationAndroid* PushNotificationAndroid::instance()
{
    if (!s_instance) {
        s_instance = new PushNotificationAndroid(qApp);
    }
    return s_instance;
}

void PushNotificationAndroid::initialize(PushNotificationTokenCallback tokenCallback,
                                         PushNotificationReceivedCallback receivedCallback)
{
    if (m_initialized) {
        qDebug() << "[PushNotificationAndroid] Already initialized";
        return;
    }
    
    qDebug() << "[PushNotificationAndroid] Initializing...";
    
    // Store callbacks
    s_tokenCallback = tokenCallback;
    s_receivedCallback = receivedCallback;
    
    // Check if Google Play Services is available
    if (!isGooglePlayServicesAvailable()) {
        qWarning() << "[PushNotificationAndroid] Google Play Services not available";
        return;
    }
    
    // Register JNI native methods
    registerNativeMethods();

    // Ensure Java helper has an application context set
    {
        QJniEnvironment env;
        if (env.isValid()) {
            QJniObject context = QNativeInterface::QAndroidApplication::context();
            if (context.isValid()) {
                QJniObject::callStaticMethod<void>(
                    "app/status/mobile/PushNotificationHelper",
                    "initialize",
                    "(Landroid/content/Context;)V",
                    context.object()
                );
                if (env->ExceptionCheck()) {
                    env->ExceptionDescribe();
                    env->ExceptionClear();
                    qWarning() << "[PushNotificationAndroid] Exception calling PushNotificationHelper.initialize";
                }
            } else {
                qWarning() << "[PushNotificationAndroid] Failed to get Android context for PushNotificationHelper.initialize";
            }
        }
    }
    
    // Request FCM token
    requestFCMToken();
    
    m_initialized = true;
    qDebug() << "[PushNotificationAndroid] Initialization complete";
}

bool PushNotificationAndroid::hasNotificationPermission()
{
    QJniEnvironment env;
    if (!env.isValid()) {
        qWarning() << "[PushNotificationAndroid] Invalid JNI environment";
        return false;
    }
    
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        qWarning() << "[PushNotificationAndroid] Failed to get Android context";
        return false;
    }
    
    jboolean result = QJniObject::callStaticMethod<jboolean>(
        "app/status/mobile/PushNotificationHelper",
        "hasNotificationPermission",
        "(Landroid/content/Context;)Z",
        activity.object()
    );
    
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return false;
    }
    
    return result;
}

void PushNotificationAndroid::requestNotificationPermission()
{
    qDebug() << "[PushNotificationAndroid] Requesting notification permission...";
    
    QJniEnvironment env;
    if (!env.isValid()) {
        qWarning() << "[PushNotificationAndroid] Invalid JNI environment";
        return;
    }
    
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        qWarning() << "[PushNotificationAndroid] Failed to get Android context";
        return;
    }
    
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/PushNotificationHelper",
        "requestNotificationPermission",
        "(Landroid/content/Context;)V",
        activity.object()
    );
    
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        qWarning() << "[PushNotificationAndroid] Exception requesting permission";
        return;
    }
    
    qDebug() << "[PushNotificationAndroid] Permission request sent";
}

void PushNotificationAndroid::requestFCMToken()
{
    qDebug() << "[PushNotificationAndroid] Requesting FCM token via Java layer...";
    
    QJniEnvironment env;
    if (!env.isValid()) {
        qWarning() << "[PushNotificationAndroid] Invalid JNI environment";
        return;
    }
    
    // Get Android application context
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        qWarning() << "[PushNotificationAndroid] Failed to get Android context";
        return;
    }
    
    // Check permission first
    if (!hasNotificationPermission()) {
        qWarning() << "[PushNotificationAndroid] Notification permission not granted!";
        qWarning() << "[PushNotificationAndroid] Call requestNotificationPermission() first";
    }
    
    // Call PushNotificationHelper.requestFCMToken() which handles the Task listener
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/PushNotificationHelper",
        "requestFCMToken",
        "(Landroid/content/Context;)V",
        activity.object()
    );
    
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        qWarning() << "[PushNotificationAndroid] Exception requesting FCM token";
        return;
    }
    
    qDebug() << "[PushNotificationAndroid] FCM token request sent, waiting for callback...";
}

void PushNotificationAndroid::showNotification(const QString& title, 
                                               const QString& message, 
                                               const QString& identifier)
{
    qDebug() << "[PushNotificationAndroid] Showing notification:" << title;
    
    QJniEnvironment env;
    if (!env.isValid()) {
        qWarning() << "[PushNotificationAndroid] Invalid JNI environment";
        return;
    }
    
    // Call Java helper method to display notification
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/PushNotificationHelper",
        "showNotification",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V",
        QJniObject::fromString(title).object<jstring>(),
        QJniObject::fromString(message).object<jstring>(),
        QJniObject::fromString(identifier).object<jstring>()
    );
    
    // Check for exceptions
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        qWarning() << "[PushNotificationAndroid] Exception showing notification";
    }
}

void PushNotificationAndroid::clearNotifications(const QString& chatId)
{
    qDebug() << "[PushNotificationAndroid] Clearing notifications for chat:" << chatId;
    
    QJniEnvironment env;
    if (!env.isValid()) {
        return;
    }
    
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/PushNotificationHelper",
        "clearNotifications",
        "(Ljava/lang/String;)V",
        QJniObject::fromString(chatId).object<jstring>()
    );
    
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
    }
}

void PushNotificationAndroid::registerNativeMethods()
{
    qDebug() << "[PushNotificationAndroid] Registering JNI native methods...";
    
    QJniEnvironment env;
    if (!env.isValid()) {
        qWarning() << "[PushNotificationAndroid] Invalid JNI environment";
        return;
    }
    
    // Find the PushNotificationHelper class
    jclass helperClass = env->FindClass("app/status/mobile/PushNotificationHelper");
    if (!helperClass) {
        qWarning() << "[PushNotificationAndroid] Could not find PushNotificationHelper class";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return;
    }
    
    // Define native methods
    JNINativeMethod methods[] = {
        {
            const_cast<char*>("nativeOnFCMTokenReceived"),
            const_cast<char*>("(Ljava/lang/String;)V"),
            reinterpret_cast<void*>(jni_onFCMTokenReceived)
        },
        {
            const_cast<char*>("nativeOnPushNotificationReceived"),
            const_cast<char*>("(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V"),
            reinterpret_cast<void*>(jni_onPushNotificationReceived)
        }
    };
    
    // Register methods
    jint result = env->RegisterNatives(helperClass, methods, 2);
    if (result != JNI_OK) {
        qWarning() << "[PushNotificationAndroid] Failed to register native methods:" << result;
        env->ExceptionDescribe();
        env->ExceptionClear();
    } else {
        qDebug() << "[PushNotificationAndroid] Native methods registered successfully";
    }
    
    env->DeleteLocalRef(helperClass);
}

bool PushNotificationAndroid::isGooglePlayServicesAvailable()
{
    QJniEnvironment env;
    if (!env.isValid()) {
        return false;
    }
    
    // Check if Google Play Services is available
    // This is a simplified check - in production, you might want more thorough checking
    try {
        QJniObject context = QJniObject::callStaticObjectMethod(
            "org/qtproject/qt/android/QtNative",
            "activity",
            "()Landroid/app/Activity;"
        );
        
        if (!context.isValid()) {
            return false;
        }
        
        // Try to get FirebaseApp - if this works, Firebase is available
        QJniObject firebaseApp = QJniObject::callStaticObjectMethod(
            "com/google/firebase/FirebaseApp",
            "getInstance",
            "()Lcom/google/firebase/FirebaseApp;"
        );
        
        return firebaseApp.isValid();
        
    } catch (...) {
        qWarning() << "[PushNotificationAndroid] Exception checking Play Services";
        return false;
    }
}

// ============================================================================
// JNI Callback Implementations
// ============================================================================

void jni_onFCMTokenReceived(JNIEnv* env, jobject obj, jstring token)
{
    Q_UNUSED(obj);
    
    if (!env || !token) {
        qWarning() << "[PushNotificationAndroid] Invalid parameters in onFCMTokenReceived";
        return;
    }
    
    // Convert jstring to QString and const char*
    const char* tokenChars = env->GetStringUTFChars(token, nullptr);
    QString tokenStr = QString::fromUtf8(tokenChars);
    
    qDebug() << "[PushNotificationAndroid] FCM Token received:" << tokenStr;
    
    // Call Nim callback if registered
    if (s_tokenCallback != nullptr) {
        qDebug() << "[PushNotificationAndroid] Calling Nim callback with token";
        s_tokenCallback(tokenChars);
    } else {
        qWarning() << "[PushNotificationAndroid] No callback registered for token!";
    }
    
    env->ReleaseStringUTFChars(token, tokenChars);
    
    // Also emit signal for backward compatibility
    if (PushNotificationAndroid::s_instance) {
        emit PushNotificationAndroid::s_instance->tokenReceived(tokenStr);
    }
}

void jni_onPushNotificationReceived(JNIEnv* env, jobject obj, 
                                   jstring encryptedMessage,
                                   jstring chatId,
                                   jstring publicKey)
{
    Q_UNUSED(obj);
    
    if (!env || !encryptedMessage || !chatId || !publicKey) {
        qWarning() << "[PushNotificationAndroid] Invalid parameters in onPushNotificationReceived";
        return;
    }
    
    // Convert jstrings to const char*
    const char* encMsgChars = env->GetStringUTFChars(encryptedMessage, nullptr);
    const char* chatIdChars = env->GetStringUTFChars(chatId, nullptr);
    const char* pubKeyChars = env->GetStringUTFChars(publicKey, nullptr);
    
    qDebug() << "[PushNotificationAndroid] Push notification received for chat:" << chatIdChars;
    
    // Call Nim callback if registered
    if (s_receivedCallback != nullptr) {
        qDebug() << "[PushNotificationAndroid] Calling Nim callback with notification data";
        s_receivedCallback(encMsgChars, chatIdChars, pubKeyChars);
    } else {
        qWarning() << "[PushNotificationAndroid] No callback registered for notifications!";
    }
    
    env->ReleaseStringUTFChars(encryptedMessage, encMsgChars);
    env->ReleaseStringUTFChars(chatId, chatIdChars);
    env->ReleaseStringUTFChars(publicKey, pubKeyChars);
    
    // Also emit signal for backward compatibility
    if (PushNotificationAndroid::s_instance) {
        emit PushNotificationAndroid::s_instance->pushNotificationReceived(
            QString::fromUtf8(encMsgChars),
            QString::fromUtf8(chatIdChars),
            QString::fromUtf8(pubKeyChars)
        );
    }
}

#endif // Q_OS_ANDROID

