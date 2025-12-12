#import <StatusQ/statusappdelegate_ios.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

#include <QDebug>
#include <QString>
#include <StatusQ/pushnotification_ios.h>

/**
 * Dummy function to prevent LTO from stripping this file
 * CRITICAL: This must be called from somewhere to force linker to include the category code!
 */
extern "C" void statusq_initIOSAppDelegateCategory()
{   
    // Force a reference to the category class to prevent LTO optimization
    [QIOSApplicationDelegate class];
}

/**
 * Category implementation that extends Qt's QIOSApplicationDelegate
 * 
 * These methods will be automatically called by iOS when the app delegate
 * receives push notification events. No need to replace Qt's delegate!
 */

@implementation QIOSApplicationDelegate (StatusPushNotifications)

/**
 * Called when the category is loaded
 * Uses method swizzling to replace Qt's app delegate methods
 * Based on: vendor/DOtherSide/lib/src/Status/AppDelegate.mm (macOS version)
 */
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class originalClass = NSClassFromString(@"QIOSApplicationDelegate");
        Class swizzledClass = [self class];
        
        if (!originalClass) {
            NSLog(@"[StatusPushNotifications] ERROR: QIOSApplicationDelegate class not found!");
            return;
        }
        // Add or swizzle didFinishLaunchingWithOptions
        SEL originalSelector = @selector(application:didFinishLaunchingWithOptions:);
        SEL swizzledSelector = @selector(statusSwizzled_application:didFinishLaunchingWithOptions:);
        
        Method originalMethod = class_getInstanceMethod(originalClass, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(swizzledClass, swizzledSelector);
        
        if (!originalMethod && swizzledMethod) {
            // Method doesn't exist in Qt's delegate - add it directly
            class_addMethod(originalClass, originalSelector,
                           method_getImplementation(swizzledMethod),
                           method_getTypeEncoding(swizzledMethod));
        } else if (originalMethod && swizzledMethod) {
            // Method exists - swizzle it
            method_exchangeImplementations(originalMethod, swizzledMethod);
        } else {
            NSLog(@"[StatusPushNotifications] ERROR: Could not add/swizzle didFinishLaunchingWithOptions");
            NSLog(@"[StatusPushNotifications] originalMethod: %p, swizzledMethod: %p", originalMethod, swizzledMethod);
        }
        
        // Swizzle didRegisterForRemoteNotificationsWithDeviceToken
        SEL tokenSelector = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
        SEL swizzledTokenSelector = @selector(statusSwizzled_application:didRegisterForRemoteNotificationsWithDeviceToken:);
        
        Method tokenMethod = class_getInstanceMethod(originalClass, tokenSelector);
        Method swizzledTokenMethod = class_getInstanceMethod(swizzledClass, swizzledTokenSelector);
        
        if (swizzledTokenMethod) {
            if (!tokenMethod) {
                // Method doesn't exist in Qt's delegate, add it
                class_addMethod(originalClass, tokenSelector, 
                               method_getImplementation(swizzledTokenMethod),
                               method_getTypeEncoding(swizzledTokenMethod));
            } else {
                // Method exists, swizzle it
                method_exchangeImplementations(tokenMethod, swizzledTokenMethod);
            }
        }
        
        // Add notification reception method
        SEL notificationSelector = @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
        SEL swizzledNotificationSelector = @selector(statusSwizzled_application:didReceiveRemoteNotification:fetchCompletionHandler:);
        
        Method notificationMethod = class_getInstanceMethod(originalClass, notificationSelector);
        Method swizzledNotificationMethod = class_getInstanceMethod(swizzledClass, swizzledNotificationSelector);
        
        if (swizzledNotificationMethod) {
            if (!notificationMethod) {
                // Method doesn't exist in Qt's delegate, add it
                class_addMethod(originalClass, notificationSelector,
                               method_getImplementation(swizzledNotificationMethod),
                               method_getTypeEncoding(swizzledNotificationMethod));
            } else {
                // Method exists, swizzle it
                method_exchangeImplementations(notificationMethod, swizzledNotificationMethod);
            }
        }
    });
}

/**
 * Implementation of didFinishLaunchingWithOptions
 * Since Qt doesn't have this method, we add it directly (no swizzling needed)
 */
- (BOOL)statusSwizzled_application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Check if app was launched from a notification tap
    if (launchOptions) {
        NSDictionary *notification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
        if (notification) {
            NSDictionary *data = notification[@"data"];
            if (data) {
                NSString *encryptedMessage = data[@"encryptedMessage"];
                NSString *chatId = data[@"chatId"];
                NSString *publicKey = data[@"publicKey"];
                
                if (encryptedMessage && chatId && publicKey) {
                    // Note: This will be called before the app is fully initialized
                    // The notification will be queued and processed once status-go is ready
                    PushNotificationIOS::instance()->onPushNotificationReceived(
                        QString::fromNSString(encryptedMessage),
                        QString::fromNSString(chatId),
                        QString::fromNSString(publicKey)
                    );
                }
            }
        }
    }
    
    // Set ourselves as the UNUserNotificationCenter delegate
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;    
    // Request notification authorization
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    
    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError *error) {
        if (error) {
            NSLog(@"[StatusPushNotifications] Permission error: %@", error.localizedDescription);
            return;
        }
        
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [application registerForRemoteNotifications];
            });
        }
    }];
    
    return YES;
}

#pragma mark - Push Notification Delegate Methods

/**
 * Swizzled version of didRegisterForRemoteNotificationsWithDeviceToken
 * This is our implementation that will be called when iOS delivers the token
 */
- (void)statusSwizzled_application:(UIApplication *)application 
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // Convert NSData token to hex string
    const unsigned char *bytes = (const unsigned char *)[deviceToken bytes];
    NSMutableString *hexToken = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [hexToken appendFormat:@"%02x", bytes[i]];
    }    
    // Forward to C++ layer
    PushNotificationIOS::instance()->onAPNSTokenReceived(
        QString::fromNSString(hexToken)
    );
}

/**
 * Called if APNS token registration fails
 */
- (void)application:(UIApplication *)application 
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"[StatusPushNotifications] Failed to register for remote notifications: %@", error.localizedDescription);
}

/**
 * Called when a remote notification is received
 * Works both when app is in foreground and background
 */
- (void)statusSwizzled_application:(UIApplication *)application 
    didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    // Extract encrypted data from push notification
    NSDictionary *data = userInfo[@"data"];
    
    if (data) {
        NSString *encryptedMessage = data[@"encryptedMessage"];
        NSString *chatId = data[@"chatId"];
        NSString *publicKey = data[@"publicKey"];
        
        if (encryptedMessage && chatId && publicKey) {            
            // Forward to C++ layer
            PushNotificationIOS::instance()->onPushNotificationReceived(
                QString::fromNSString(encryptedMessage),
                QString::fromNSString(chatId),
                QString::fromNSString(publicKey)
            );
            
            completionHandler(UIBackgroundFetchResultNewData);
            return;
        }
    }
    
    NSLog(@"[StatusPushNotifications] No valid data in notification");
    completionHandler(UIBackgroundFetchResultNoData);
}

#pragma mark - UNUserNotificationCenterDelegate

/**
 * Called when a notification is received while app is in foreground
 */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    NSLog(@"[StatusPushNotifications] Notification received in foreground");
    
    // Show notification even when app is in foreground
    if (@available(iOS 14.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner | 
                         UNNotificationPresentationOptionSound |
                         UNNotificationPresentationOptionBadge);
    } else {
        completionHandler(UNNotificationPresentationOptionAlert | 
                         UNNotificationPresentationOptionSound |
                         UNNotificationPresentationOptionBadge);
    }
}

/**
 * Called when user taps a notification
 */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    NSLog(@"[StatusPushNotifications] User tapped notification");
    
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSString *identifier = userInfo[@"identifier"];
    
    if (identifier) {
        NSLog(@"[StatusPushNotifications] Notification identifier: %@", identifier);
        // TODO: Handle notification tap
        // emit PushNotificationIOS::instance()->notificationTapped(QString::fromNSString(identifier));
    }
    
    completionHandler();
}

@end

