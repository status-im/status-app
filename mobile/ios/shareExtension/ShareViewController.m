// Share extension: text, links & images (fork issues #14/#15, iOS
// share-integration slices 2 and 3, on the hand-off plumbing from #13).
//
// Thin hand-off, the extension stays a dumb platform layer (fork issue #12):
//   1. extract the shared text/URL/images from the extension context
//      (asynchronous NSItemProvider loads); image data is copied into the App
//      Group `share-intake` cache immediately at receipt — the provider's
//      file representation is only valid during the load handler, the same
//      expiring-access rule as Android's content-URI read grants;
//   2. write a {"type":"share","text":...,"imagePaths":[...]} payload into
//      the App Group container (the pending intake slot — see
//      src/app/core/intake/pending_intake_slot.nim for the host side);
//   3. wake the host app via the responder-chain openURL workaround;
//   4. complete the extension request.
//
// App Group layout (one team-scoped group shared by the Status / Status PR
// variants, so everything is scoped under a per-variant root named after the
// HOST bundle id — the host resolves the same root from its own bundle id in
// ui/StatusQ/src/shareintake_ios.mm; without it the other variant would
// consume the slot on foreground and its launch sweep would delete this
// variant's in-flight copies):
//   <container>/<host bundle id>/pending-intake/share.json   the slot
//   <container>/<host bundle id>/share-intake/share-*.<ext>  image copies
//
// The wake in step 3 is UNSUPPORTED API (extensions officially cannot launch
// their host app). Ordering encodes the required fallback: the payload is on
// disk before the wake is attempted, so if the wake fails or is killed the
// slot survives and the host delivers it on the next manual app open.
//
// Cache hygiene (the extension's side of the two-process lifecycle; the host
// releases copies after send/cancel and sweeps leftovers on a fresh launch):
//   - overwriting the slot (last-wins) deletes the replaced payload's cached
//     copies — they were never delivered and nothing references them anymore;
//   - a failed hand-off deletes the copies this share just made;
//   - deletion only ever touches files directly inside a `share-intake`
//     directory, mirroring the host-side guard (share_intake_cache.nim).

#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

// Must match ui/StatusQ/src/shareintake_ios.mm and the entitlements files
// (mobile/ios/*.entitlements, ShareExtension.entitlements). One team-scoped
// group id serves both bundle-id variants; see the layout above for how the
// variants are kept apart inside it.
static NSString *const kAppGroupId = @"group.app.status.mobile";
static NSString *const kPendingIntakeDirName = @"pending-intake";
static NSString *const kPendingIntakeFileName = @"share.json";
// Cache dir for the receipt-time image copies. Must match
// kShareIntakeCacheDirName in ui/StatusQ/src/shareintake_ios.mm and
// ShareIntakeCacheDirName in src/app/core/intake/share_intake_cache.nim (the
// host-side cache lifecycle only owns files inside a dir of this name).
static NSString *const kShareIntakeCacheDirName = @"share-intake";
// Authority of the wake ping. Must match ShareIntakeWakeHost in
// src/app/core/intake/pending_intake_slot.nim — the host recognizes a wake by
// this authority, whatever the scheme.
static NSString *const kWakeHost = @"share-intake";

// The HOST app's bundle id, recovered from this extension's: the extension's
// bundle id is forced to `<host>.ShareExtension` (buildShareExtension.sh), so
// stripping the last component yields the host's — one derivation, nothing to
// keep in sync at build time. It names both the wake scheme and the
// per-variant root inside the App Group container. nil only for an unsigned
// bundle without an identifier, which can't happen for a real extension.
static NSString *HostBundleId(void)
{
    NSString *extensionBundleId = NSBundle.mainBundle.bundleIdentifier;
    if (extensionBundleId.length == 0)
        return nil;
    NSRange lastDot = [extensionBundleId rangeOfString:@"." options:NSBackwardsSearch];
    return lastDot.location != NSNotFound
        ? [extensionBundleId substringToIndex:lastDot.location]
        : extensionBundleId;
}

// The wake URL's scheme is the HOST app's bundle id — variant-unique, so a
// co-installed variant (Status / Status PR) can't hijack the wake; iOS keeps
// ONE global handler per URL scheme, which is why the shared status-app
// scheme couldn't be used (fork issue #48). Each variant registers its bundle
// id as a scheme (mobile/ios/Info.plist.template).
static NSString *WakeUrlString(void)
{
    NSString *hostBundleId = HostBundleId();
    if (hostBundleId == nil) {
        // Degrade to the legacy shared scheme rather than an unparseable
        // nil-scheme URL.
        return [NSString stringWithFormat:@"status-app://%@", kWakeHost];
    }
    return [NSString stringWithFormat:@"%@://%@", hostBundleId, kWakeHost];
}

// `<App Group container>/<host bundle id>` — the root both the slot and the
// image cache live under (must mirror variantRootUrl() in
// ui/StatusQ/src/shareintake_ios.mm). nil when the container can't be
// resolved (entitlement missing) or the host id is unknown.
static NSURL *VariantRootUrl(void)
{
    NSURL *container = [[NSFileManager defaultManager]
        containerURLForSecurityApplicationGroupIdentifier:kAppGroupId];
    if (container == nil) {
        NSLog(@"StatusShareExtension: no App Group container for %@ (entitlement missing?)", kAppGroupId);
        return nil;
    }
    NSString *hostBundleId = HostBundleId();
    if (hostBundleId == nil) {
        NSLog(@"StatusShareExtension: extension bundle has no identifier; cannot scope the hand-off");
        return nil;
    }
    return [container URLByAppendingPathComponent:hostBundleId isDirectory:YES];
}

// Attachment types accepted (matches the activation rule in Info.plist:
// text, at most one web URL, and images up to the in-app send limit).
static NSString *const kTypeImage = @"public.image";
static NSString *const kTypeUrl = @"public.url";
static NSString *const kTypePlainText = @"public.plain-text";
// Per-share ceiling on preparing image copies; past it the share goes out with what was copied.
static const NSTimeInterval kImageLoadDeadlineSeconds = 120.0;
// Camera originals (12 MP+) are downscaled to this longest edge on copy: the
// chat compresses image messages to ~350 KB anyway, so nothing visible is
// lost and the host is spared decoding full-size photos.
static const CGFloat kMaxImageEdgePx = 2048.0;

@interface ShareViewController : UIViewController
@property (nonatomic, retain) UILabel *progressLabel;
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

    [self extractSharedContentWithCompletion:^(NSString *text, NSArray<NSString *> *imagePaths) {
        BOOL hasText = [text stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
        // Empty extraction writes nothing: an empty payload could only launch
        // an empty share flow (the host seam drops it) or clobber a share
        // still waiting in the slot — and the wake would bounce the user into
        // Status for nothing.
        if (!hasText && imagePaths.count == 0) {
            NSLog(@"StatusShareExtension: nothing extractable was shared; no hand-off");
            [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
            return;
        }
        if (![self writePendingIntakeWithText:text imagePaths:imagePaths]) {
            // The hand-off failed after the copies were made: don't leak them
            // into the shared container.
            [ShareViewController deleteCachedCopies:imagePaths];
            [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
            return;
        }
        [self wakeHostApp];
        // Defer completion: completing the request tears down the extension's
        // view-service connection in the same runloop turn, which cancels the
        // still-in-flight async openURL dispatch before it reaches SpringBoard.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
        });
    }];
}

// Collects the image, plain-text and web-URL attachments across all input
// items — the iOS counterpart of the Android layer's decision-free intent
// extraction (StatusQtActivity.java). Shared links travel as text too,
// matching the seam's share{text, imagePaths} payload: text parts are joined,
// the URL is appended unless the text already contains it (apps commonly put
// the link inside the shared text themselves). Image data is copied into the
// App Group cache inside the load handler — the provided file URL expires
// with the handler. Attachment loads are asynchronous; the completion runs
// once, on the main queue, with the composed text ("" when nothing usable was
// shared) and the cached copies' paths in the share's attachment order.
- (void)extractSharedContentWithCompletion:(void (^)(NSString *text,
                                                     NSArray<NSString *> *imagePaths))completion
{
    NSMutableArray<NSItemProvider *> *imageProviders = [NSMutableArray array];
    NSMutableArray<NSItemProvider *> *urlProviders = [NSMutableArray array];
    NSMutableArray<NSItemProvider *> *textProviders = [NSMutableArray array];
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *provider in item.attachments) {
            // Image first: an image attachment commonly also advertises URL
            // (its file location) or text representations, but the image is
            // the content being shared. URL before plain-text: a URL provider
            // may also advertise plain-text, and the link (with scheme
            // intact) is the content the user is sharing.
            if ([provider hasItemConformingToTypeIdentifier:kTypeImage])
                [imageProviders addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:kTypeUrl])
                [urlProviders addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:kTypePlainText])
                [textProviders addObject:provider];
        }
    }

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSString *> *texts = [NSMutableArray array];
    NSMutableArray<NSString *> *urls = [NSMutableArray array];
    // One pre-claimed slot per image attachment (filled by index, compacted
    // at the end) so the copies keep the share's order.
    NSMutableArray *orderedImagePaths = [NSMutableArray array];
    for (NSUInteger i = 0; i < imageProviders.count; i++)
        [orderedImagePaths addObject:[NSNull null]];

    for (NSItemProvider *provider in urlProviders) {
        dispatch_group_enter(group);
        [provider loadItemForTypeIdentifier:kTypeUrl
                                    options:nil
                          completionHandler:^(id<NSSecureCoding> loaded, NSError *__unused error) {
            NSString *url = nil;
            if ([(NSObject *)loaded isKindOfClass:[NSURL class]]) {
                NSURL *u = (NSURL *)loaded;
                // File URLs are not shareable text; non-image files
                // are not accepted by this extension.
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
    }

    for (NSItemProvider *provider in textProviders) {
        dispatch_group_enter(group);
        [provider loadItemForTypeIdentifier:kTypePlainText
                                    options:nil
                          completionHandler:^(id<NSSecureCoding> loaded, NSError *__unused error) {
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

    // Images load one after another: the host materializes each file
    // representation (often a HEIC->JPEG transcode) and an extension has a
    // small memory ceiling, so dozens of concurrent loads get it killed.
    // Chained through completions rather than a blocked thread, so a load
    // that never calls back can't wedge the extension: the deadline below
    // hands off whatever was copied by then.
    if (imageProviders.count > 0)
        dispatch_group_enter(group);
    __block BOOL finished = NO;
    // The block references itself through the __block variable; the cycle is
    // broken once the chain ends or the deadline fires.
    __block void (^loadImage)(NSUInteger) = nil;
    loadImage = ^(NSUInteger index) {
        if (finished) {
            loadImage = nil;
            return;
        }
        if (index >= imageProviders.count) {
            finished = YES;
            loadImage = nil;
            dispatch_group_leave(group);
            return;
        }
        [self showProgress:index + 1 of:imageProviders.count];
        [imageProviders[index] loadFileRepresentationForTypeIdentifier:kTypeImage
                                                    completionHandler:^(NSURL *fileUrl, NSError *error) {
            @autoreleasepool {
                // fileUrl is only valid during this handler: copy now.
                NSString *copied = fileUrl != nil
                    ? [self copyImageToCache:fileUrl index:index]
                    : nil;
                if (copied != nil) {
                    @synchronized (orderedImagePaths) {
                        orderedImagePaths[index] = copied;
                    }
                } else {
                    // Skip this attachment; the rest of the share still
                    // goes through (mirrors the Android copy loop).
                    NSLog(@"StatusShareExtension: cannot copy shared image %lu: %@",
                          (unsigned long)index, error);
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (loadImage != nil)
                    loadImage(index + 1);
            });
        }];
    };
    if (imageProviders.count > 0) {
        loadImage(0);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kImageLoadDeadlineSeconds * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (finished)
                return;
            NSLog(@"StatusShareExtension: image loads exceeded %.0fs; handing off the copies made so far",
                  kImageLoadDeadlineSeconds);
            finished = YES;
            loadImage = nil;
            dispatch_group_leave(group);
        });
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
        NSMutableArray<NSString *> *imagePaths = [NSMutableArray array];
        for (id path in orderedImagePaths) {
            if ([path isKindOfClass:[NSString class]])
                [imagePaths addObject:path];
        }
        completion(text, imagePaths);
    });
}

// The sheet would otherwise stay blank while a large share is copied.
- (void)showProgress:(NSUInteger)current of:(NSUInteger)total
{
    if (self.progressLabel == nil) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [spinner startAnimating];
        UILabel *label = [[UILabel alloc] init];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.textColor = [UIColor secondaryLabelColor];
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        [self.view addSubview:spinner];
        [self.view addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-16],
            [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [label.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:12],
        ]];
        self.progressLabel = label;
    }
    self.progressLabel.text = [NSString stringWithFormat:@"Preparing %lu of %lu\u2026",
                               (unsigned long)current, (unsigned long)total];
}

// Only photo formats larger than the cap are downscaled; gif/png/webp keep
// their bytes (animation, transparency).
+ (BOOL)shouldDownscale:(NSURL *)fileUrl
{
    static NSSet<NSString *> *photoExtensions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        photoExtensions = [NSSet setWithArray:@[@"jpg", @"jpeg", @"heic", @"heif"]];
    });
    if (![photoExtensions containsObject:fileUrl.pathExtension.lowercaseString])
        return NO;
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)fileUrl, NULL);
    if (source == NULL)
        return NO;
    CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    CFRelease(source);
    if (props == NULL)
        return NO;
    CGFloat width = [((__bridge NSDictionary *)props)[(id)kCGImagePropertyPixelWidth] doubleValue];
    CGFloat height = [((__bridge NSDictionary *)props)[(id)kCGImagePropertyPixelHeight] doubleValue];
    CFRelease(props);
    return MAX(width, height) > kMaxImageEdgePx;
}

+ (BOOL)writeDownscaledJpegFrom:(NSURL *)fileUrl to:(NSURL *)dest
{
    BOOL wrote = NO;
    @autoreleasepool {
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)fileUrl, NULL);
        if (source == NULL)
            return NO;
        NSDictionary *options = @{
            (id)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
            (id)kCGImageSourceThumbnailMaxPixelSize : @(kMaxImageEdgePx),
            (id)kCGImageSourceCreateThumbnailWithTransform : @YES,
        };
        CGImageRef scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
        CFRelease(source);
        if (scaled == NULL)
            return NO;
        CGImageDestinationRef out = CGImageDestinationCreateWithURL((__bridge CFURLRef)dest, CFSTR("public.jpeg"), 1, NULL);
        if (out != NULL) {
            CGImageDestinationAddImage(out, scaled,
                (__bridge CFDictionaryRef)@{ (id)kCGImageDestinationLossyCompressionQuality : @0.85 });
            wrote = CGImageDestinationFinalize(out);
            CFRelease(out);
        }
        CGImageRelease(scaled);
    }
    return wrote;
}

// Copies one shared image file into the App Group `share-intake` cache and
// returns the copy's absolute path (nil on failure). Names are unique per
// receipt (epoch-ms + attachment index, extension preserved) so a new share's
// copies can never collide with copies a still-pending payload references.
- (NSString *)copyImageToCache:(NSURL *)fileUrl index:(NSUInteger)index
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *root = VariantRootUrl();
    if (root == nil)
        return nil;
    NSURL *dir = [root URLByAppendingPathComponent:kShareIntakeCacheDirName isDirectory:YES];
    NSError *error = nil;
    if (![fm createDirectoryAtURL:dir
        withIntermediateDirectories:YES
                         attributes:@{NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication}
                              error:&error]) {
        NSLog(@"StatusShareExtension: cannot create share-intake cache dir: %@", error);
        return nil;
    }

    long long epochMs = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSString *base = [NSString stringWithFormat:@"share-%lld-%lu", epochMs, (unsigned long)index];
    NSURL *dest = nil;
    if ([ShareViewController shouldDownscale:fileUrl]) {
        dest = [dir URLByAppendingPathComponent:[base stringByAppendingString:@".jpg"]];
        if (![ShareViewController writeDownscaledJpegFrom:fileUrl to:dest]) {
            NSLog(@"StatusShareExtension: downscale failed for image %lu; copying the original", (unsigned long)index);
            [fm removeItemAtURL:dest error:nil];
            dest = nil;
        }
    }
    if (dest == nil) {
        NSString *ext = fileUrl.pathExtension;
        dest = [dir URLByAppendingPathComponent:
                [base stringByAppendingString:ext.length > 0 ? [@"." stringByAppendingString:ext] : @""]];
        if (![fm copyItemAtURL:fileUrl toURL:dest error:&error]) {
            NSLog(@"StatusShareExtension: cannot copy shared image into the cache: %@", error);
            return nil;
        }
    }
    // Same protection class as the slot file: the host must be able to read
    // the copy shortly after a reboot-while-locked (fork issue #12, downside 5).
    [fm setAttributes:@{NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication}
         ofItemAtPath:dest.path
                error:nil];
    return dest.path;
}

// Last-wins by design: an atomic overwrite of the single slot file. The
// replaced payload's cached image copies are deleted with it — they were
// never delivered and nothing references them anymore. Returns NO when the
// hand-off could not be written (the caller then releases this share's own
// copies).
- (BOOL)writePendingIntakeWithText:(NSString *)text imagePaths:(NSArray<NSString *> *)imagePaths
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *root = VariantRootUrl();
    if (root == nil)
        return NO;

    NSURL *dir = [root URLByAppendingPathComponent:kPendingIntakeDirName isDirectory:YES];
    NSError *error = nil;
    if (![fm createDirectoryAtURL:dir
        withIntermediateDirectories:YES
                         attributes:@{NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication}
                              error:&error]) {
        NSLog(@"StatusShareExtension: cannot create pending-intake dir: %@", error);
        return NO;
    }

    // Payload contract with the host (urls_manager.consumePendingIntake):
    // {"type": "share", "text": ..., "imagePaths": [...]} — imagePaths
    // optional; unknown extra keys are ignored there.
    NSMutableDictionary *payload = [@{
        @"type" : @"share",
        @"text" : text,
        @"receivedAt" : @([[NSDate date] timeIntervalSince1970]),
    } mutableCopy];
    if (imagePaths.count > 0)
        payload[@"imagePaths"] = imagePaths;
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (json == nil) {
        NSLog(@"StatusShareExtension: cannot serialize payload: %@", error);
        return NO;
    }

    NSURL *file = [dir URLByAppendingPathComponent:kPendingIntakeFileName];
    // The replaced payload's copies are released only after the new payload
    // is safely on disk: the write is atomic, so a failed write leaves the
    // old payload pending — its copies must stay valid with it.
    NSArray<NSString *> *replacedCopies = [ShareViewController copiesReferencedByPayloadAt:file];
    // CompleteUntilFirstUserAuthentication: the extension must be able to
    // write (and the host read) shortly after a reboot-while-locked; anything
    // stricter can fail in locked-ish states (see fork issue #12, downside 5).
    NSDataWritingOptions options = NSDataWritingAtomic |
        NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication;
    if (![json writeToURL:file options:options error:&error]) {
        NSLog(@"StatusShareExtension: cannot write pending intake slot: %@", error);
        return NO;
    }
    // Last-wins took effect: the replaced payload was never delivered and
    // nothing references its copies anymore.
    [ShareViewController deleteCachedCopies:replacedCopies];
    NSLog(@"StatusShareExtension: pending intake written to %@", file.path);
    return YES;
}

// The cached image copies an undelivered slot payload references (empty for
// a missing or broken payload).
+ (NSArray<NSString *> *)copiesReferencedByPayloadAt:(NSURL *)file
{
    NSData *data = [NSData dataWithContentsOfURL:file];
    if (data == nil)
        return @[];
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![payload isKindOfClass:[NSDictionary class]])
        return @[];
    id paths = payload[@"imagePaths"];
    return [paths isKindOfClass:[NSArray class]] ? paths : @[];
}

// Best-effort deletion, guarded to files directly inside a `share-intake`
// directory — the extension-side mirror of the host guard in
// src/app/core/intake/share_intake_cache.nim.
+ (void)deleteCachedCopies:(NSArray<NSString *> *)paths
{
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if (![path isKindOfClass:[NSString class]])
            continue;
        NSString *parent = path.stringByDeletingLastPathComponent.lastPathComponent;
        if (![parent isEqualToString:kShareIntakeCacheDirName])
            continue;
        [fm removeItemAtPath:path error:nil];
    }
}

// Responder-chain openURL workaround: walk up to the hidden UIApplication
// responder and invoke -openURL: on it. Unsupported API; when it stops
// working the share degrades to slot-only delivery (next manual app open).
- (void)wakeHostApp
{
    NSURL *url = [NSURL URLWithString:WakeUrlString()];
    UIResponder *responder = self;
    while (responder != nil) {
        // Modern UIKit routes app-extension opens through the 3-argument
        // variant; the bare openURL: is accepted but silently dropped.
        if ([responder respondsToSelector:@selector(openURL:options:completionHandler:)]) {
            // UIScene's variant takes UISceneOpenExternalURLOptions (an object,
            // not a dictionary); nil is accepted by every known implementor.
            void (*openUrl)(id, SEL, NSURL *, id, void (^)(BOOL)) =
                (void (*)(id, SEL, NSURL *, id, void (^)(BOOL)))objc_msgSend;
            openUrl(responder, @selector(openURL:options:completionHandler:), url, nil,
                    ^(BOOL success) {
                NSLog(@"StatusShareExtension: host wake completion success=%d", success);
            });
            NSLog(@"StatusShareExtension: host wake requested via responder chain (3-arg)");
            return;
        }
        if ([responder respondsToSelector:@selector(openURL:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [responder performSelector:@selector(openURL:) withObject:url];
#pragma clang diagnostic pop
            NSLog(@"StatusShareExtension: host wake requested via responder chain (legacy)");
            return;
        }
        responder = responder.nextResponder;
    }
    NSLog(@"StatusShareExtension: no openURL responder found; payload stays in the slot");
}

@end
