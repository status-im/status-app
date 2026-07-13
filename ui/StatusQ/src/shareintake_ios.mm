#include <StatusQ/shareintake.h>

#import <Foundation/Foundation.h>

// Must match the group declared in mobile/ios/*.entitlements,
// mobile/ios/shareExtension/ShareExtension.entitlements and the constants in
// mobile/ios/shareExtension/ShareViewController.m. One group id serves both
// bundle-id variants (app.status.mobile / app.status.mobile.pr) — App Groups
// are team-scoped, not bundle-id-scoped.
static NSString *const kAppGroupId = @"group.app.status.mobile";
static NSString *const kPendingIntakeDirName = @"pending-intake";
// Must match kShareIntakeCacheDirName in ShareViewController.m and
// ShareIntakeCacheDirName in src/app/core/intake/share_intake_cache.nim.
static NSString *const kShareIntakeCacheDirName = @"share-intake";

QString Status::ShareIntake::pendingIntakeDir()
{
    NSURL *container = [[NSFileManager defaultManager]
        containerURLForSecurityApplicationGroupIdentifier:kAppGroupId];
    if (container == nil)
        return {};

    NSURL *dir = [container URLByAppendingPathComponent:kPendingIntakeDirName isDirectory:YES];
    return QString::fromNSString(dir.path);
}

QString Status::ShareIntake::shareIntakeCacheDir()
{
    NSURL *container = [[NSFileManager defaultManager]
        containerURLForSecurityApplicationGroupIdentifier:kAppGroupId];
    if (container == nil)
        return {};

    NSURL *dir = [container URLByAppendingPathComponent:kShareIntakeCacheDirName isDirectory:YES];
    return QString::fromNSString(dir.path);
}
