// Do-nothing share extension (fork issue #13, iOS share-integration slice 1).
//
// Proves the full hand-off chain before any real share logic exists:
//   1. write a dummy payload into the App Group container (the pending intake
//      slot — see src/app/core/intake/pending_intake_slot.nim for the host
//      side and CONTEXT.md for the vocabulary);
//   2. wake the host app via the responder-chain openURL workaround;
//   3. complete the extension request immediately.
//
// The wake in step 2 is UNSUPPORTED API (extensions officially cannot launch
// their host app). Ordering encodes the required fallback: the payload is on
// disk before the wake is attempted, so if the wake fails or is killed the
// slot survives and the host delivers it on the next manual app open.

#import <UIKit/UIKit.h>

// Must match ui/StatusQ/src/shareintake_ios.mm and the entitlements files
// (mobile/ios/*.entitlements, ShareExtension.entitlements). One team-scoped
// group id serves both bundle-id variants.
static NSString *const kAppGroupId = @"group.app.status.mobile";
static NSString *const kPendingIntakeDirName = @"pending-intake";
static NSString *const kPendingIntakeFileName = @"share.json";
// Must match ShareIntakeWakeUrl in src/app/core/intake/pending_intake_slot.nim.
static NSString *const kWakeUrl = @"status-app://share-intake";

@interface ShareViewController : UIViewController
@end

@implementation ShareViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self writePendingIntake];
    [self wakeHostApp];

    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

// Last-wins by design: an atomic overwrite of the single slot file.
- (void)writePendingIntake
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *container = [fm containerURLForSecurityApplicationGroupIdentifier:kAppGroupId];
    if (container == nil) {
        NSLog(@"StatusShareExtension: no App Group container for %@ (entitlement missing?)", kAppGroupId);
        return;
    }

    NSURL *dir = [container URLByAppendingPathComponent:kPendingIntakeDirName isDirectory:YES];
    NSError *error = nil;
    if (![fm createDirectoryAtURL:dir
        withIntermediateDirectories:YES
                         attributes:@{NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication}
                              error:&error]) {
        NSLog(@"StatusShareExtension: cannot create pending-intake dir: %@", error);
        return;
    }

    NSDictionary *payload = @{
        @"type" : @"share",
        @"text" : @"dummy payload from StatusShareExtension",
        @"receivedAt" : @([[NSDate date] timeIntervalSince1970]),
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (json == nil) {
        NSLog(@"StatusShareExtension: cannot serialize payload: %@", error);
        return;
    }

    NSURL *file = [dir URLByAppendingPathComponent:kPendingIntakeFileName];
    // CompleteUntilFirstUserAuthentication: the extension must be able to
    // write (and the host read) shortly after a reboot-while-locked; anything
    // stricter can fail in locked-ish states (see fork issue #12, downside 5).
    NSDataWritingOptions options = NSDataWritingAtomic |
        NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication;
    if (![json writeToURL:file options:options error:&error]) {
        NSLog(@"StatusShareExtension: cannot write pending intake slot: %@", error);
        return;
    }
    NSLog(@"StatusShareExtension: pending intake written to %@", file.path);
}

// Responder-chain openURL workaround: walk up to the hidden UIApplication
// responder and invoke -openURL: on it. Unsupported API; when it stops
// working the share degrades to slot-only delivery (next manual app open).
- (void)wakeHostApp
{
    NSURL *url = [NSURL URLWithString:kWakeUrl];
    UIResponder *responder = self;
    while (responder != nil) {
        if ([responder respondsToSelector:@selector(openURL:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [responder performSelector:@selector(openURL:) withObject:url];
#pragma clang diagnostic pop
            NSLog(@"StatusShareExtension: host wake requested via responder chain");
            return;
        }
        responder = responder.nextResponder;
    }
    NSLog(@"StatusShareExtension: no openURL responder found; payload stays in the slot");
}

@end
