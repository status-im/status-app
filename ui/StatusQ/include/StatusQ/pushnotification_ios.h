#pragma once

#include <QObject>
#include <QString>

#ifdef __cplusplus
extern "C" {
#endif

// C API for Nim integration (same as Android for consistency)
#ifndef PUSH_NOTIFICATION_CALLBACKS_DEFINED
#define PUSH_NOTIFICATION_CALLBACKS_DEFINED
typedef void (*PushNotificationTokenCallback)(const char* token);
typedef void (*PushNotificationReceivedCallback)(const char* encryptedMessage, const char* chatId, const char* publicKey);
#endif

void statusq_initPushNotifications(
    PushNotificationTokenCallback tokenCallback,
    PushNotificationReceivedCallback receivedCallback
);

void statusq_requestNotificationPermission();
bool statusq_hasNotificationPermission();

void statusq_showIOSNotification(const char* title, const char* message, const char* identifier);

#ifdef __cplusplus
}
#endif

#ifdef Q_OS_IOS

#include <QObject>

/**
 * iOS Push Notification Manager
 * Handles APNS token registration and push notification reception
 */
class PushNotificationIOS : public QObject
{
    Q_OBJECT

public:
    /**
     * Get singleton instance
     */
    static PushNotificationIOS* instance();
    
    /**
     * Initialize push notifications with callbacks
     * - Stores Nim callbacks
     * - Requests notification permissions
     * - Registers for remote notifications (APNS)
     * 
     * @param tokenCallback Callback for APNS token reception
     * @param receivedCallback Callback for push notification reception
     */
    void initialize(PushNotificationTokenCallback tokenCallback,
                   PushNotificationReceivedCallback receivedCallback);
    
    /**
     * Check if notification permission is granted
     * @return true if permission granted
     */
    bool hasNotificationPermission();
    
    /**
     * Request notification permission
     * Shows iOS system permission dialog
     */
    void requestNotificationPermission();
    
    /**
     * Request APNS token from Apple
     * The token will be delivered via tokenReceived() signal
     */
    void requestAPNSToken();
    
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
    
    /**
     * Called from iOS delegate when APNS token is received
     * @param token The device token (hex string)
     */
    void onAPNSTokenReceived(const QString& token);
    
    /**
     * Called from iOS delegate when push notification is received
     * @param encryptedMessage Encrypted message data
     * @param chatId Chat identifier
     * @param publicKey Sender's public key
     */
    void onPushNotificationReceived(const QString& encryptedMessage,
                                   const QString& chatId,
                                   const QString& publicKey);

signals:
    /**
     * Emitted when APNS token is received
     * @param token The APNS device token
     */
    void tokenReceived(const QString& token);
    
    /**
     * Emitted when a push notification is received
     * @param encryptedMessage The encrypted message data
     * @param chatId The chat identifier
     * @param publicKey The sender's public key
     */
    void pushNotificationReceived(const QString& encryptedMessage, 
                                  const QString& chatId,
                                  const QString& publicKey);
    
    /**
     * Emitted when user taps a notification
     * @param identifier The notification identifier
     */
    void notificationTapped(const QString& identifier);

private:
    explicit PushNotificationIOS(QObject* parent = nullptr);
    ~PushNotificationIOS() = default;
    
    static PushNotificationIOS* s_instance;
    bool m_initialized;
    PushNotificationTokenCallback m_tokenCallback = nullptr;
    PushNotificationReceivedCallback m_receivedCallback = nullptr;
};

#endif // Q_OS_IOS

