#include <StatusQ/shareintake.h>

#import <Foundation/Foundation.h>

// Must match the group declared in mobile/ios/*.entitlements,
// mobile/ios/shareExtension/ShareExtension.entitlements and the constants in
// mobile/ios/shareExtension/ShareViewController.m. One group id serves both
// bundle-id variants (app.status.mobile / app.status.mobile.pr) — App Groups
// are team-scoped, not bundle-id-scoped.
static NSString *const kAppGroupId = @"group.app.status.mobile";
static NSString *const kPendingIntakeDirName = @"pending-intake";

QString Status::ShareIntake::pendingIntakeDir()
{
    NSURL *container = [[NSFileManager defaultManager]
        containerURLForSecurityApplicationGroupIdentifier:kAppGroupId];
    if (container == nil)
        return {};

    NSURL *dir = [container URLByAppendingPathComponent:kPendingIntakeDirName isDirectory:YES];
    return QString::fromNSString(dir.path);
}
