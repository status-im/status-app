#include "StatusQ/osnotification.h"

#ifdef Q_OS_MACOS

#import <AppKit/AppKit.h>
#import <UserNotifications/UserNotifications.h>

using namespace Status;

@interface StatusQNotificationDelegate : NSObject <UNUserNotificationCenterDelegate>
@property (nonatomic, assign) OSNotification* owner;
@end

@implementation StatusQNotificationDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    Q_UNUSED(center) Q_UNUSED(notification)
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    Q_UNUSED(center)
    NSString* identifier = response.notification.request.identifier;
    if (self.owner)
        emit self.owner->notificationClicked(QString::fromNSString(identifier));
    completionHandler();
}

@end

void OSNotification::initNotificationMacOs()
{
    if (m_delegate)
        return;
    StatusQNotificationDelegate* delegate = [[StatusQNotificationDelegate alloc] init];
    delegate.owner = this;
    m_delegate = delegate;

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = delegate;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                             UNAuthorizationOptionSound |
                                             UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError* _Nullable error) {
        Q_UNUSED(granted) Q_UNUSED(error)
    }];
}

void OSNotification::showNotificationMacOs(QString title, QString message, QString identifier)
{
    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
    content.title = title.toNSString();
    content.body = message.toNSString();
    content.sound = [UNNotificationSound defaultSound];

    UNNotificationRequest* request =
        [UNNotificationRequest requestWithIdentifier:identifier.toNSString()
                                             content:content
                                             trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                          withCompletionHandler:nil];
    [content release];
}

void OSNotification::showIconBadgeNotificationMacOs(int notificationsCount)
{
    QString s; // empty clears the badge
    if (notificationsCount > 0 && notificationsCount < 10)
        s = QString::number(notificationsCount);
    else if (notificationsCount >= 10)
        s = "9+";
    [[NSApp dockTile] setBadgeLabel:s.toNSString()];
}

// Destructor lives here so it can release the Obj-C delegate (non-ARC).
OSNotification::~OSNotification()
{
    if (m_delegate) {
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        StatusQNotificationDelegate* delegate = (StatusQNotificationDelegate*)m_delegate;
        delegate.owner = nullptr; // stop a late callback from touching a freed OSNotification
        if (center.delegate == delegate)
            center.delegate = nil;
        [delegate release];
        m_delegate = nullptr;
    }
}

#endif
