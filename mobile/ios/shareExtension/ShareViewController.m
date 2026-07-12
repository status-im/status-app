// Share extension: text & links (fork issue #14, iOS share-integration slice 2,
// on the hand-off plumbing from #13).
//
// Thin hand-off, the extension stays a dumb platform layer (fork issue #12):
//   1. extract the shared text/URL from the extension context (asynchronous
//      NSItemProvider loads);
//   2. write a {"type":"share","text":...} payload into the App Group container
//      (the pending intake slot — see src/app/core/intake/pending_intake_slot.nim
//      for the host side and CONTEXT.md for the vocabulary);
//   3. wake the host app via the responder-chain openURL workaround;
//   4. complete the extension request.
//
// The wake in step 3 is UNSUPPORTED API (extensions officially cannot launch
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

// Attachment types accepted by this slice (matches the activation rule in
// Info.plist: text + at most one web URL). Images are the next slice (#15).
static NSString *const kTypeUrl = @"public.url";
static NSString *const kTypePlainText = @"public.plain-text";

@interface ShareViewController : UIViewController
@end

@implementation ShareViewController {
    BOOL _handled;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (_handled)
        return;
    _handled = YES;

    [self extractSharedTextWithCompletion:^(NSString *text) {
        // Blank extraction writes nothing: an empty payload could only launch
        // an empty share flow (the host seam drops it) or clobber a share
        // still waiting in the slot — and the wake would bounce the user into
        // Status for nothing.
        if ([text stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
            [self writePendingIntakeWithText:text];
            [self wakeHostApp];
        } else {
            NSLog(@"StatusShareExtension: nothing extractable was shared; no hand-off");
        }
        [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    }];
}

// Collects the plain-text and web-URL attachments across all input items —
// the iOS counterpart of the Android layer's decision-free intent extraction
// (StatusQtActivity.java: EXTRA_TEXT with EXTRA_SUBJECT fallback). Shared
// links travel as text too, matching the seam's single share{text} payload:
// text parts are joined, the URL is appended unless the text already contains
// it (apps commonly put the link inside the shared text themselves).
// Attachment loads are asynchronous; the completion runs once, on the main
// queue, with the composed text ("" when nothing usable was shared).
- (void)extractSharedTextWithCompletion:(void (^)(NSString *text))completion
{
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSString *> *texts = [NSMutableArray array];
    NSMutableArray<NSString *> *urls = [NSMutableArray array];

    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *provider in item.attachments) {
            // URL first: a URL provider may also advertise plain-text, and the
            // link (with scheme intact) is the content the user is sharing.
            if ([provider hasItemConformingToTypeIdentifier:kTypeUrl]) {
                dispatch_group_enter(group);
                [provider loadItemForTypeIdentifier:kTypeUrl
                                            options:nil
                                  completionHandler:^(id<NSSecureCoding> loaded, NSError *error) {
                    NSString *url = nil;
                    if ([(NSObject *)loaded isKindOfClass:[NSURL class]]) {
                        NSURL *u = (NSURL *)loaded;
                        // File URLs are not shareable text; images/files are
                        // later slices with their own payload kinds.
                        url = u.isFileURL ? nil : u.absoluteString;
                    } else if ([(NSObject *)loaded isKindOfClass:[NSString class]]) {
                        url = (NSString *)loaded;
                    }
                    if (url.length > 0) {
                        @synchronized (urls) {
                            [urls addObject:url];
                        }
                    }
                    dispatch_group_leave(group);
                }];
            } else if ([provider hasItemConformingToTypeIdentifier:kTypePlainText]) {
                dispatch_group_enter(group);
                [provider loadItemForTypeIdentifier:kTypePlainText
                                            options:nil
                                  completionHandler:^(id<NSSecureCoding> loaded, NSError *error) {
                    NSString *text = nil;
                    if ([(NSObject *)loaded isKindOfClass:[NSString class]]) {
                        text = (NSString *)loaded;
                    } else if ([(NSObject *)loaded isKindOfClass:[NSAttributedString class]]) {
                        text = ((NSAttributedString *)loaded).string;
                    } else if ([(NSObject *)loaded isKindOfClass:[NSData class]]) {
                        text = [[NSString alloc] initWithData:(NSData *)loaded
                                                     encoding:NSUTF8StringEncoding];
                    }
                    if (text.length > 0) {
                        @synchronized (texts) {
                            [texts addObject:text];
                        }
                    }
                    dispatch_group_leave(group);
                }];
            }
        }
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSString *text = [texts componentsJoinedByString:@"\n"];
        if (text.length == 0) {
            // Some apps put the shared text only in the item body, not in a
            // plain-text attachment.
            for (NSExtensionItem *item in self.extensionContext.inputItems) {
                NSString *body = item.attributedContentText.string;
                if (body.length > 0) {
                    text = body;
                    break;
                }
            }
        }
        for (NSString *url in urls) {
            if ([text containsString:url])
                continue;
            text = text.length > 0 ? [NSString stringWithFormat:@"%@\n%@", text, url] : url;
        }
        completion(text);
    });
}

// Last-wins by design: an atomic overwrite of the single slot file.
- (void)writePendingIntakeWithText:(NSString *)text
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

    // Payload contract with the host (urls_manager.consumePendingIntake):
    // {"type": "share", "text": ...}; unknown extra keys are ignored there.
    NSDictionary *payload = @{
        @"type" : @"share",
        @"text" : text,
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
