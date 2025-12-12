#pragma once

#include <QObject>
#include <QString>

#ifdef Q_OS_ANDROID
#include <jni.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// C API for Nim integration
typedef void (*PushNotificationTokenCallback)(const char* token);
typedef void (*PushNotificationReceivedCallback)(const char* encryptedMessage, const char* chatId, const char* publicKey);

/**
 * Initialize push notifications with callbacks
 * This is called from Nim code with cdecl callback functions
 * 
 * @param tokenCallback Function to call when FCM token is received
 * @param receivedCallback Function to call when push notification is received
 */
void statusq_initPushNotifications(
    PushNotificationTokenCallback tokenCallback,
    PushNotificationReceivedCallback receivedCallback
);

/**
 * Show a notification (called from Nim via existing OSNotification)
 * 
 * @param title Notification title
 * @param message Notification message  
 * @param identifier JSON metadata
 */
void statusq_showAndroidNotification(const char* title, const char* message, const char* identifier);

#ifdef __cplusplus
}
#endif

#ifdef Q_OS_ANDROID

/**
 * Android Push Notification Bridge
 * 
 * This class bridges between:
 * - Java Android code (FCM, NotificationManager)
 * - Qt/C++ layer
 * - Nim backend
 * 
 * It handles:
 * - FCM token registration
 * - Notification display
 * - JNI callbacks from Java
 */
class PushNotificationAndroid : public QObject
{
    Q_OBJECT

public:
    /**
     * Get singleton instance
     */
    static PushNotificationAndroid* instance();
    
    /**
     * Initialize push notifications with callbacks
     * - Stores Nim callbacks
     * - Registers JNI native methods
     * - Requests FCM token
     * 
     * @param tokenCallback Callback for FCM token reception
     * @param receivedCallback Callback for push notification reception
     */
    void initialize(PushNotificationTokenCallback tokenCallback,
                   PushNotificationReceivedCallback receivedCallback);
    
    /**
     * Check if notification permission is granted (Android 13+ only)
     * @return true if permission granted or not required (Android 12-)
     */
    bool hasNotificationPermission();
    
    /**
     * Request notification permission (Android 13+ only)
     * Shows system permission dialog on Android 13+
     * Does nothing on Android 12 and below
     */
    void requestNotificationPermission();
    
    /**
     * Request FCM token from Firebase
     * The token will be delivered via tokenReceived() signal
     */
    void requestFCMToken();
    
    /**
     * Show a notification (called from Nim layer)
     * 
     * @param title Notification title
     * @param message Notification message
     * @param identifier JSON string with metadata (chatId, etc.)
     */
    void showNotification(const QString& title, const QString& message, const QString& identifier);
    
    /**
     * Clear notifications for a specific chat
     * 
     * @param chatId The chat identifier
     */
    void clearNotifications(const QString& chatId);

signals:
    /**
     * Emitted when FCM token is received from Firebase
     * 
     * @param token The FCM device token
     */
    void tokenReceived(const QString& token);
    
    /**
     * Emitted when a push notification is received (via FCM)
     * This is for the encrypted payload that needs to be processed by status-go
     * 
     * @param encryptedMessage The encrypted message data
     * @param chatId The chat identifier
     * @param publicKey The sender's public key
     */
    void pushNotificationReceived(const QString& encryptedMessage, 
                                  const QString& chatId,
                                  const QString& publicKey);
    
    /**
     * Emitted when user taps a notification
     * 
     * @param identifier The notification identifier (contains chatId, etc.)
     */
    void notificationTapped(const QString& identifier);

private:
    PushNotificationAndroid(QObject* parent = nullptr);
    ~PushNotificationAndroid() = default;
    
    /**
     * Register JNI native methods
     * This allows Java code to call C++ methods
     */
    void registerNativeMethods();
    
    /**
     * Check if Google Play Services is available
     */
    bool isGooglePlayServicesAvailable();
    
    // JNI callback handlers (called from Java)
    friend void jni_onFCMTokenReceived(JNIEnv* env, jobject obj, jstring token);
    friend void jni_onPushNotificationReceived(JNIEnv* env, jobject obj, 
                                               jstring encryptedMessage,
                                               jstring chatId,
                                               jstring publicKey);
    
    static PushNotificationAndroid* s_instance;
    bool m_initialized;
};

// JNI callback functions (implemented in .cpp)
// Note: These are C++ functions, not extern "C", because they're registered via JNI RegisterNatives
// which handles the calling convention. They're declared as friends above.
void jni_onFCMTokenReceived(JNIEnv* env, jobject obj, jstring token);
void jni_onPushNotificationReceived(JNIEnv* env, jobject obj, 
                                    jstring encryptedMessage,
                                    jstring chatId,
                                    jstring publicKey);

#endif // Q_OS_ANDROID

