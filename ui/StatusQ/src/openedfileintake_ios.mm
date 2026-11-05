#include <StatusQ/openedfileintake.h>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>

#include <QCoreApplication>
#include <QTimer>

// Manual retain/release, like the rest of the StatusQ Objective-C++.

namespace {

// Our own copies, made when the security scope of an in-place file does not start.
NSString *const kCopiesDirName = @"opened-files";

std::function<void(const QString &, bool)> &receiver()
{
    static std::function<void(const QString &, bool)> instance;
    return instance;
}

// Files that came before the receiver: {url, copied}.
NSMutableArray<NSDictionary *> *pending()
{
    static NSMutableArray<NSDictionary *> *files = [[NSMutableArray alloc] init];
    return files;
}

// In-place originals whose security scope is held, by path.
NSMutableDictionary<NSString *, NSURL *> *scopedFiles()
{
    static NSMutableDictionary<NSString *, NSURL *> *files = [[NSMutableDictionary alloc] init];
    return files;
}

NSString *copiesDir()
{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:kCopiesDirName];
}

// Where iOS puts the copies other apps hand over: Documents/Inbox, and
// tmp/<bundle id>-Inbox on newer systems.
NSArray<NSString *> *inboxDirs()
{
    NSMutableArray<NSString *> *dirs = [NSMutableArray array];
    NSString *documents =
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (documents)
        [dirs addObject:[documents stringByAppendingPathComponent:@"Inbox"]];
    for (NSString *name in [[NSFileManager defaultManager]
             contentsOfDirectoryAtPath:NSTemporaryDirectory() error:nil]) {
        if ([name hasSuffix:@"-Inbox"])
            [dirs addObject:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    }
    return dirs;
}

// "/private/var/..." and "/var/..." name the same file.
NSString *comparablePath(NSString *path)
{
    return [path hasPrefix:@"/private/"] ? [path substringFromIndex:8] : path;
}

bool isCopyPath(NSString *path)
{
    NSString *file = comparablePath(path);
    NSMutableArray<NSString *> *dirs = [NSMutableArray arrayWithArray:inboxDirs()];
    [dirs addObject:copiesDir()];
    for (NSString *dir in dirs) {
        if ([file hasPrefix:[comparablePath(dir) stringByAppendingString:@"/"]])
            return true;
    }
    return false;
}

void deliver(NSURL *url, bool copied)
{
    NSString *fileUrl = url.absoluteString;
    if (receiver())
        receiver()(QString::fromNSString(fileUrl), copied);
    else
        [pending() addObject:@{@"url": fileUrl, @"copied": @(copied)}];
}

// A coordinated copy, so an iCloud file is downloaded first; nil on failure.
NSURL *copyOf(NSURL *source)
{
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *dirPath = [copiesDir() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    NSURL *dir = [NSURL fileURLWithPath:dirPath isDirectory:YES];
    NSURL *destination = [dir URLByAppendingPathComponent:source.lastPathComponent];
    if (![files createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil])
        return nil;

    __block BOOL copied = NO;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateReadingItemAtURL:source
                                    options:NSFileCoordinatorReadingWithoutChanges
                                      error:nil
                                 byAccessor:^(NSURL *readUrl) {
                                     copied = [files copyItemAtURL:readUrl toURL:destination error:nil];
                                 }];
    [coordinator release];
    return copied ? destination : nil;
}

void receive(UIOpenURLContext *context)
{
    NSURL *url = context.URL;
    if (!url.isFileURL)
        return;
    if (!context.options.openInPlace) {
        deliver(url, true);
        return;
    }
    if ([url startAccessingSecurityScopedResource]) {
        scopedFiles()[comparablePath(url.path)] = url;
        deliver(url, false);
        return;
    }
    // Without the scope the original cannot be read; a copy can.
    if (NSURL *copy = copyOf(url))
        deliver(copy, true);
    else
        deliver(url, false);
}

// A fresh launch has no Tab showing a copy: drop what an earlier run left,
// except the files this launch was opened with.
void sweepCopies(NSSet<UIOpenURLContext *> *launchContexts)
{
    NSMutableSet<NSString *> *keep = [NSMutableSet set];
    for (UIOpenURLContext *context in launchContexts)
        if (context.URL.isFileURL)
            [keep addObject:comparablePath(context.URL.path)];

    NSFileManager *files = [NSFileManager defaultManager];
    [files removeItemAtPath:copiesDir() error:nil];
    for (NSString *dir in inboxDirs()) {
        for (NSString *name in [files contentsOfDirectoryAtPath:dir error:nil]) {
            NSString *path = [dir stringByAppendingPathComponent:name];
            if (![keep containsObject:comparablePath(path)])
                [files removeItemAtPath:path error:nil];
        }
    }
}

IMP originalOpenUrlContexts = nullptr;
IMP originalWillConnect = nullptr;
bool launched = false;
NSSet<UIOpenURLContext *> *connectingContexts = nil;

void hookedOpenUrlContexts(id self, SEL cmd, UIScene *scene, NSSet<UIOpenURLContext *> *contexts)
{
    for (UIOpenURLContext *context in contexts) {
        if (![connectingContexts containsObject:context])
            receive(context);
    }
    reinterpret_cast<void (*)(id, SEL, UIScene *, NSSet *)>(originalOpenUrlContexts)(
        self, cmd, scene, contexts);
}

void hookedWillConnect(id self, SEL cmd, UIScene *scene, UISceneSession *session,
                       UISceneConnectionOptions *options)
{
    if (!launched) {
        launched = true;
        sweepCopies(options.URLContexts);
    }
    for (UIOpenURLContext *context in options.URLContexts)
        receive(context);
    // Qt passes the launch contexts on to scene:openURLContexts:, already received above.
    connectingContexts = options.URLContexts;
    reinterpret_cast<void (*)(id, SEL, UIScene *, UISceneSession *, UISceneConnectionOptions *)>(
        originalWillConnect)(self, cmd, scene, session, options);
    connectingContexts = nil;
}

// Qt turns these URLs into QUrls and the security scope does not survive that,
// so the scene delegate is wrapped to see the NSURL objects UIKit delivers.
__attribute__((constructor)) void installSceneHooks()
{
    Class delegateClass = objc_getClass("QIOSWindowSceneDelegate");
    if (!delegateClass)
        return;
    Method openUrl = class_getInstanceMethod(delegateClass, @selector(scene:openURLContexts:));
    if (openUrl)
        originalOpenUrlContexts =
            method_setImplementation(openUrl, reinterpret_cast<IMP>(hookedOpenUrlContexts));
    Method willConnect = class_getInstanceMethod(
        delegateClass, @selector(scene:willConnectToSession:options:));
    if (willConnect)
        originalWillConnect =
            method_setImplementation(willConnect, reinterpret_cast<IMP>(hookedWillConnect));
}

} // namespace

void Status::OpenedFileIntake::setReceiver(std::function<void(const QString &, bool)> newReceiver)
{
    receiver() = std::move(newReceiver);
    if (!receiver() || pending().count == 0)
        return;
    // Later, so whoever connects to the receiver's signal does it first.
    QTimer::singleShot(0, QCoreApplication::instance(), [] {
        NSArray<NSDictionary *> *files = [[pending() copy] autorelease];
        [pending() removeAllObjects];
        for (NSDictionary *file in files)
            receiver()(QString::fromNSString(file[@"url"]), [file[@"copied"] boolValue]);
    });
}

void Status::OpenedFileIntake::release(const QString &localPath)
{
    NSString *path = comparablePath(localPath.toNSString());
    if (NSURL *scoped = scopedFiles()[path]) {
        [scoped stopAccessingSecurityScopedResource];
        [scopedFiles() removeObjectForKey:path];
        return;
    }
    if (isCopyPath(path))
        [[NSFileManager defaultManager] removeItemAtPath:localPath.toNSString() error:nil];
}
