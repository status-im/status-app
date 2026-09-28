#include <StatusQ/shareintake.h>

#import <Foundation/Foundation.h>

// Must match the group declared in mobile/ios/*.entitlements,
// mobile/ios/shareExtension/ShareExtension.entitlements and the constants in
// mobile/ios/shareExtension/ShareViewController.m. One group id serves both
// bundle-id variants (app.status.mobile / app.status.mobile.pr) — App Groups
// are team-scoped, not bundle-id-scoped — so everything inside the container
// lives under a per-variant root named after the host bundle id: a
// co-installed variant must never consume this app's slot on foreground or
// sweep its in-flight image copies on launch. The extension derives the same
// root from its own bundle id (`<host>.ShareExtension`).
static NSString *const kAppGroupId = @"group.app.status.mobile";
static NSString *const kPendingIntakeDirName = @"pending-intake";
// Must match kShareIntakeCacheDirName in ShareViewController.m and
// ShareIntakeCacheDirName in src/app/core/intake/share_intake_cache.nim.
static NSString *const kShareIntakeCacheDirName = @"share-intake";

// `<App Group container>/<host bundle id>`; nil without a container.
static NSURL *variantRootUrl()
{
    NSURL *container = [[NSFileManager defaultManager]
        containerURLForSecurityApplicationGroupIdentifier:kAppGroupId];
    if (container == nil)
        return nil;

    NSString *bundleId = NSBundle.mainBundle.bundleIdentifier;
    if (bundleId.length == 0)
        return nil;
    return [container URLByAppendingPathComponent:bundleId isDirectory:YES];
}

QString Status::ShareIntake::pendingIntakeDir()
{
    NSURL *root = variantRootUrl();
    if (root == nil)
        return {};

    NSURL *dir = [root URLByAppendingPathComponent:kPendingIntakeDirName isDirectory:YES];
    return QString::fromNSString(dir.path);
}

QString Status::ShareIntake::shareIntakeCacheDir()
{
    NSURL *root = variantRootUrl();
    if (root == nil)
        return {};

    NSURL *dir = [root URLByAppendingPathComponent:kShareIntakeCacheDirName isDirectory:YES];
    return QString::fromNSString(dir.path);
}
