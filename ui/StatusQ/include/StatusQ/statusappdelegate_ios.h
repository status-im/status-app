#pragma once

// C API - Safe to include from C++ files
#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize iOS app delegate category
 * CRITICAL: This MUST be called to prevent LTO from stripping the category code!
 */
void statusq_initIOSAppDelegateCategory();

#ifdef __cplusplus
}
#endif

// Objective-C API - Only for .mm files
#ifdef __OBJC__

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

/**
 * Category on Qt's QIOSApplicationDelegate to add push notification support
 * 
 * Qt already creates its own UIApplication and app delegate (QIOSApplicationDelegate).
 * Instead of replacing it (which causes "There can only be one UIApplication instance"),
 * we extend it using an Objective-C category to add push notification methods.
 * 
 * This approach is based on: https://gist.github.com/shigmas/62e9cf023303c03be49c4f1646e37051
 */

// Forward declare Qt's hidden app delegate
@interface QIOSApplicationDelegate : NSObject
@end

/**
 * Category that adds push notification support to Qt's app delegate
 */
@interface QIOSApplicationDelegate (StatusPushNotifications) <UNUserNotificationCenterDelegate>
@end

#endif // __OBJC__

