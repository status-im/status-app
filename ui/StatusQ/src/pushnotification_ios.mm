#include "StatusQ/pushnotification_ios.h"

#ifdef Q_OS_IOS

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>

#include <QDebug>
#include <QCoreApplication>

// Static instance
PushNotificationIOS* PushNotificationIOS::s_instance = nullptr;

PushNotificationIOS::PushNotificationIOS(QObject* parent)
    : QObject(parent)
    , m_initialized(false)
{
}

PushNotificationIOS* PushNotificationIOS::instance()
{
    if (!s_instance) {
        s_instance = new PushNotificationIOS(qApp);
    }
    return s_instance;
}

void PushNotificationIOS::initialize(PushNotificationTokenCallback tokenCallback,
                                     PushNotificationReceivedCallback receivedCallback)
{
    if (m_initialized) {
        qDebug() << "[PushNotificationIOS] Already initialized";
        return;
    }
    
    qDebug() << "[PushNotificationIOS] Initializing...";
    
    // Store callbacks
    m_tokenCallback = tokenCallback;
    m_receivedCallback = receivedCallback;
    
    // Note: Push notification registration is now handled by the QIOSApplicationDelegate category
    // in statusappdelegate_ios.mm via didFinishLaunchingWithOptions override.
    // This ensures proper integration with Qt's app delegate lifecycle.
    
    m_initialized = true;
    qDebug() << "[PushNotificationIOS] Initialization complete";
    qDebug() << "[PushNotificationIOS] Registration will be triggered by app delegate category";
}

bool PushNotificationIOS::hasNotificationPermission()
{
    __block BOOL hasPermission = NO;
    __block BOOL finished = NO;
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings* settings) {
        hasPermission = (settings.authorizationStatus == UNAuthorizationStatusAuthorized);
        finished = YES;
    }];
    
    // Wait for async completion (with timeout)
    NSDate* timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while (!finished && [[NSDate date] compare:timeout] == NSOrderedAscending) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    return hasPermission;
}

void PushNotificationIOS::requestNotificationPermission()
{
    qDebug() << "[PushNotificationIOS] Requesting notification permission...";
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    
    // First check current permission status
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings* settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
            // Already authorized - register for remote notifications immediately
            qDebug() << "[PushNotificationIOS] Permission already granted, registering for remote notifications...";
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] registerForRemoteNotifications];
                qDebug() << "[PushNotificationIOS] Registered for remote notifications";
            });
        } else if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
            // Not determined yet - request permission
            qDebug() << "[PushNotificationIOS] Permission not determined, requesting...";
            UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
            
            [center requestAuthorizationWithOptions:options
                                  completionHandler:^(BOOL granted, NSError* error) {
                if (error) {
                    qWarning() << "[PushNotificationIOS] Permission request error:" 
                              << QString::fromNSString(error.localizedDescription);
                    return;
                }
                
                if (granted) {
                    qDebug() << "[PushNotificationIOS] Notification permission granted";
                    
                    // Register for remote notifications on main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[UIApplication sharedApplication] registerForRemoteNotifications];
                        qDebug() << "[PushNotificationIOS] Registered for remote notifications";
                    });
                } else {
                    qWarning() << "[PushNotificationIOS] Notification permission denied";
                }
            }];
        } else {
            // Permission denied
            qWarning() << "[PushNotificationIOS] Notification permission was denied by user";
            qWarning() << "[PushNotificationIOS] User must enable notifications in Settings";
        }
    }];
}

void PushNotificationIOS::requestAPNSToken()
{
    qDebug() << "[PushNotificationIOS] Requesting APNS token...";
    
    // Check if we have permission first
    if (!hasNotificationPermission()) {
        qWarning() << "[PushNotificationIOS] No notification permission!";
        qWarning() << "[PushNotificationIOS] Call requestNotificationPermission() first";
        return;
    }
    
    // Register for remote notifications
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    });
    
    qDebug() << "[PushNotificationIOS] APNS token request sent";
}

void PushNotificationIOS::showNotification(const QString& title,
                                          const QString& message,
                                          const QString& identifier)
{
    qDebug() << "[PushNotificationIOS] Showing notification:" << title;
    
    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
    content.title = title.toNSString();
    content.body = message.toNSString();
    content.sound = [UNNotificationSound defaultSound];
    content.badge = @([[UIApplication sharedApplication] applicationIconBadgeNumber] + 1);
    
    // Add identifier as userInfo for tap handling
    content.userInfo = @{@"identifier": identifier.toNSString()};
    
    // Create trigger (deliver immediately)
    UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger 
        triggerWithTimeInterval:0.1 repeats:NO];
    
    // Create request
    UNNotificationRequest* request = [UNNotificationRequest 
        requestWithIdentifier:identifier.toNSString()
        content:content
        trigger:trigger];
    
    // Add to notification center
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError* error) {
        if (error) {
            qWarning() << "[PushNotificationIOS] Failed to show notification:"
                      << QString::fromNSString(error.localizedDescription);
        } else {
            qDebug() << "[PushNotificationIOS] Notification displayed successfully";
        }
    }];
}

void PushNotificationIOS::clearNotifications(const QString& chatId)
{
    qDebug() << "[PushNotificationIOS] Clearing notifications for chat:" << chatId;
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    
    // Remove delivered notifications with matching identifier
    [center removeDeliveredNotificationsWithIdentifiers:@[chatId.toNSString()]];
    
    // Also remove pending notifications
    [center removePendingNotificationRequestsWithIdentifiers:@[chatId.toNSString()]];
}

void PushNotificationIOS::onAPNSTokenReceived(const QString& token)
{
    qDebug() << "[PushNotificationIOS] APNS Token received:" << token;
    
    // Call Nim callback if registered
    if (m_tokenCallback != nullptr) {
        qDebug() << "[PushNotificationIOS] Calling Nim callback with token";
        m_tokenCallback(token.toUtf8().constData());
    } else {
        qWarning() << "[PushNotificationIOS] No callback registered for token!";
    }
    
    // Emit signal
    emit tokenReceived(token);
}

void PushNotificationIOS::onPushNotificationReceived(const QString& encryptedMessage,
                                                     const QString& chatId,
                                                     const QString& publicKey)
{
    qDebug() << "[PushNotificationIOS] Push notification received for chat:" << chatId;
    
    // Call Nim callback if registered
    if (m_receivedCallback != nullptr) {
        qDebug() << "[PushNotificationIOS] Calling Nim callback with notification data";
        m_receivedCallback(
            encryptedMessage.toUtf8().constData(),
            chatId.toUtf8().constData(),
            publicKey.toUtf8().constData()
        );
    } else {
        qWarning() << "[PushNotificationIOS] No callback registered for notifications!";
    }
    
    // Emit signal
    emit pushNotificationReceived(encryptedMessage, chatId, publicKey);
}

#endif // Q_OS_IOS

