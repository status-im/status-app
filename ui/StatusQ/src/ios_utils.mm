#include "ios_utils.h"
#include <QStringList>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <objc/runtime.h>
#include <atomic>
#include <cmath>
#include <QString>
#include <QUrl>

void saveImageToPhotosAlbum(const QByteArray &data)
{
    NSData *imageData = [NSData dataWithBytes:data.constData() length:data.length()];
    UIImage *image = [UIImage imageWithData:imageData];
    if (image) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    } else {
        NSLog(@"Failed to save image");
    }
}
QString resolveIOSPhotoAsset(const QUrl &assetUrl) {
    @autoreleasepool {
        if (!assetUrl.isValid()) {
            NSLog(@"resolveIOSPhotoAsset: Invalid URL provided");
            return {};
        }

        QString urlStringQt = assetUrl.toString();
        NSString *urlString = urlStringQt.toNSString();

        __block NSString *tempPath = nil;
        __block BOOL success = NO;

        dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        void (^handleResult)(NSData *) = ^(NSData *imageData) {
            if (imageData) {
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"resolved.jpg"];
                if ([imageData writeToFile:path atomically:YES]) {
                    tempPath = path;
                    success = YES;
                } else {
                    NSLog(@"resolveIOSPhotoAsset: Failed to write data to file");
                }
            } else {
                NSLog(@"resolveIOSPhotoAsset: No image data received");
            }
            dispatch_semaphore_signal(sema);
        };

        PHAsset *asset = nil;

        if ([urlString hasPrefix:@"ph://"]) {
            NSString *localId = [urlString substringFromIndex:5];
            PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
            if (result.count > 0) {
                asset = result.firstObject;
            } else {
                NSLog(@"resolveIOSPhotoAsset: No asset found for ph:// URL");
            }
        } else if ([urlString hasPrefix:@"assets-library://"]) {
            NSURL *assetURL = [NSURL URLWithString:urlString];
            // Use the modern API instead of deprecated fetchAssetsWithALAssetURLs
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
            #pragma clang diagnostic pop
            if (result.count > 0) {
                asset = result.firstObject;
            } else {
                NSLog(@"resolveIOSPhotoAsset: No asset found for assets-library:// URL");
            }
        } else {
            NSLog(@"resolveIOSPhotoAsset: URL does not match known formats (ph:// or assets-library://)");
        }

        if (asset) {
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.synchronous = YES;
            options.networkAccessAllowed = YES;

            [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:asset
                                                                           options:options
                                                                     resultHandler:^(NSData *imageData, NSString *dataUTI, CGImagePropertyOrientation orientation, NSDictionary *info) {
                handleResult(imageData);
            }];

            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        } else {
            NSLog(@"resolveIOSPhotoAsset: No valid asset found");
        }

        return success ? QString::fromNSString(tempPath) : assetUrl.toString();
    }
}

// Keyboard tracking variables
static int g_keyboardHeight = 0;
static bool g_keyboardVisible = false;
static UIView *g_rootView = nil;

void setupIOSKeyboardTracking() {
    @autoreleasepool {
        // Qt scrolls the view when the keyboard appears by listening to UIKeyboardWillShowNotification
        // and then calling scrollToCursor() which applies a CATransform3D.
        //
        // Our strategy: Listen to the keyboard notifications AFTER Qt does, and immediately
        // undo any transform that was applied. We add our observer with a delay to ensure
        // it runs after Qt's observer.
        
        // First, find and store the root view reference
        // Use a timer to repeatedly try finding the window until it exists
        NSTimer *findWindowTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
            UIWindow *keyWindow = nil;
            
            // Use modern API for getting windows
            if (@available(iOS 15.0, *)) {
                NSSet<UIScene *> *connectedScenes = [UIApplication sharedApplication].connectedScenes;
                for (UIScene *scene in connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *windowScene = (UIWindowScene *)scene;
                        for (UIWindow *window in windowScene.windows) {
                            if (window.isKeyWindow) {
                                keyWindow = window;
                                break;
                            }
                        }
                        if (keyWindow) break;
                    }
                }
            } else {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                #pragma clang diagnostic pop
            }
            
            if (keyWindow && keyWindow.rootViewController && keyWindow.rootViewController.view) {
                g_rootView = keyWindow.rootViewController.view;
                NSLog(@"[iOS Keyboard] Found root view: %@, class: %@", g_rootView, [keyWindow.rootViewController class]);
                [timer invalidate]; // Stop the timer once we found the view
            }
        }];
        
        // Listen to keyboard show notification and reset any transform
        // Use WillShow instead of DidShow to prevent the flash
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *notification) {
            NSDictionary *userInfo = notification.userInfo;
            CGRect keyboardFrameScreen = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
            
            // Get screen and window info for debugging
            UIScreen *mainScreen = [UIScreen mainScreen];
            CGFloat screenScale = mainScreen.scale;
            CGFloat screenHeight = mainScreen.bounds.size.height;
            CGRect screenBounds = mainScreen.bounds;
            
            // Log screen coordinate frame
            NSLog(@"[iOS Keyboard] Keyboard frame (screen coords): origin(%f, %f) size(%f, %f)", 
                  keyboardFrameScreen.origin.x, keyboardFrameScreen.origin.y,
                  keyboardFrameScreen.size.width, keyboardFrameScreen.size.height);
            NSLog(@"[iOS Keyboard] Screen: scale=%f, bounds=(%f, %f, %f, %f)", 
                  screenScale, screenBounds.origin.x, screenBounds.origin.y,
                  screenBounds.size.width, screenBounds.size.height);
            
            // Calculate how much of the screen the keyboard actually covers
            // The keyboard Y position tells us where it starts
            CGFloat keyboardVisibleHeight = screenHeight - keyboardFrameScreen.origin.y;
            NSLog(@"[iOS Keyboard] Keyboard top edge at Y=%f, visible height from bottom=%f", 
                  keyboardFrameScreen.origin.y, keyboardVisibleHeight);
            
            // Calculate keyboard coverage in iOS native coordinates
            CGFloat keyboardCoverageNative = screenHeight - keyboardFrameScreen.origin.y;
            
            // Convert to Qt's logical coordinate system
            // iOS uses native screen scale (e.g., 3.0x), but Qt uses its own devicePixelRatio (e.g., 2.4x)
            // We need to convert: qtPoints = (nativePoints × nativeScale) / qtDevicePixelRatio
            // However, we can't access Qt's DPR from here, so we'll use a different approach:
            // Send the coverage in pixels, and let QML divide by its devicePixelRatio
            CGFloat keyboardCoveragePixels = keyboardCoverageNative * screenScale;
            
            NSLog(@"[iOS Keyboard] Keyboard coverage: %f native points = %f pixels (scale %f)",
                  keyboardCoverageNative, keyboardCoveragePixels, screenScale);
            NSLog(@"[iOS Keyboard] QML will need to divide by its devicePixelRatio to get logical points");
            
            // Store as pixels - QML will convert to its logical points
            g_keyboardHeight = (int)keyboardCoveragePixels;
            
            g_keyboardVisible = true;
            NSLog(@"[iOS Keyboard] Final keyboard height (in pixels): %d", g_keyboardHeight);
            
            // Reset transform immediately in the same run loop to prevent flash
            // This runs before Qt's scrollToCursor animation begins
            if (g_rootView) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [CATransaction setAnimationDuration:0];
                g_rootView.layer.sublayerTransform = CATransform3DIdentity;
                [CATransaction commit];
                
                // Also schedule another reset slightly after to catch Qt's delayed animation
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (g_rootView && !CATransform3DIsIdentity(g_rootView.layer.sublayerTransform)) {
                        NSLog(@"[iOS Keyboard] Resetting transform after Qt animation");
                        [CATransaction begin];
                        [CATransaction setDisableActions:YES];
                        [CATransaction setAnimationDuration:0];
                        g_rootView.layer.sublayerTransform = CATransform3DIdentity;
                        [CATransaction commit];
                    }
                });
            }
        }];
        
        // Also listen to DidShow for a final cleanup
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardDidShowNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *notification) {
            // Final cleanup - ensure transform is identity
            if (g_rootView && !CATransform3DIsIdentity(g_rootView.layer.sublayerTransform)) {
                NSLog(@"[iOS Keyboard] Final transform reset in DidShow");
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [CATransaction setAnimationDuration:0];
                g_rootView.layer.sublayerTransform = CATransform3DIdentity;
                [CATransaction commit];
            }
        }];
        
        // Monitor for transform changes continuously while keyboard is visible
        // Qt can apply transforms at any time (focus changes, cursor moves, etc.)
        NSTimer *transformMonitor = [NSTimer scheduledTimerWithTimeInterval:0.016 repeats:YES block:^(NSTimer *timer) {
            if (g_keyboardVisible && g_rootView && !CATransform3DIsIdentity(g_rootView.layer.sublayerTransform)) {
                NSLog(@"[iOS Keyboard] Detected Qt transform while keyboard visible - resetting");
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [CATransaction setAnimationDuration:0];
                g_rootView.layer.sublayerTransform = CATransform3DIdentity;
                [CATransaction commit];
            }
        }];
        // Keep the timer alive
        [[NSRunLoop currentRunLoop] addTimer:transformMonitor forMode:NSRunLoopCommonModes];
        
        // Track keyboard hide notifications
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *notification) {
            g_keyboardHeight = 0;
            g_keyboardVisible = false;
            NSLog(@"[iOS Keyboard] Keyboard will hide");
            
            // Reset transform when keyboard hides
            if (g_rootView) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [CATransaction setAnimationDuration:0];
                g_rootView.layer.sublayerTransform = CATransform3DIdentity;
                [CATransaction commit];
            }
        }];
    }
}

int getIOSKeyboardHeight() {
    return g_keyboardHeight;
}

bool isIOSKeyboardVisible() {
    return g_keyboardVisible;
}

// -----------------------------------------------------------------------------
// Shake detection
// -----------------------------------------------------------------------------

static std::atomic<bool> g_shakeDetectionStarted{false};
static CMMotionManager* g_motionManager = nil;
static IOSShakeCallback g_shakeCallback = nullptr;

void setIOSShakeCallback(IOSShakeCallback callback) {
    g_shakeCallback = callback;
}

void setIOSShakeToEditEnabled(bool enabled) {
    auto apply = ^{
        UIApplication* app = [UIApplication sharedApplication];
        if ([app respondsToSelector:@selector(setApplicationSupportsShakeToEdit:)]) {
            app.applicationSupportsShakeToEdit = enabled;
            NSLog(@"[iOS Shake] applicationSupportsShakeToEdit=%s", enabled ? "YES" : "NO");
        }
    };

    if ([NSThread isMainThread]) {
        apply();
    } else {
        dispatch_async(dispatch_get_main_queue(), apply);
    }
}

void setupIOSShakeDetection() {
    @autoreleasepool {
        // Idempotent setup
        bool expected = false;
        if (!g_shakeDetectionStarted.compare_exchange_strong(expected, true)) {
            NSLog(@"[iOS Shake] setupIOSShakeDetection: already started");
            return;
        }

        g_motionManager = [[CMMotionManager alloc] init];
        if (!g_motionManager || !g_motionManager.accelerometerAvailable) {
            NSLog(@"[iOS Shake] Accelerometer not available");
            return;
        }

        // 50Hz sampling
        g_motionManager.accelerometerUpdateInterval = 0.02;
        NSOperationQueue* queue = [[NSOperationQueue alloc] init];
        queue.qualityOfService = NSQualityOfServiceUserInitiated;

        __block NSTimeInterval lastShakeTs = 0.0;
        NSLog(@"[iOS Shake] setupIOSShakeDetection: started accelerometer updates");

        [g_motionManager startAccelerometerUpdatesToQueue:queue withHandler:^(CMAccelerometerData* data, NSError* error) {
            if (error) {
                // Don't spam logs; just ignore occasional errors.
                return;
            }
            if (!data) return;

            const double ax = data.acceleration.x;
            const double ay = data.acceleration.y;
            const double az = data.acceleration.z;

            // At rest, magnitude is ~1g. Detect spikes well above that.
            const double mag = std::sqrt(ax*ax + ay*ay + az*az);
            const double deltaFrom1g = std::fabs(mag - 1.0);

            // Threshold tuned to reduce false positives. Cooldown prevents rapid repeats.
            constexpr double kShakeThreshold = 1.35; // ~1.35g deviation from 1g
            constexpr NSTimeInterval kCooldownSec = 1.0;

            if (deltaFrom1g < kShakeThreshold) return;

            const NSTimeInterval nowTs = [NSDate date].timeIntervalSince1970;
            if (nowTs - lastShakeTs < kCooldownSec) return;

            lastShakeTs = nowTs;
            NSLog(@"[iOS Shake] detected: mag=%f deltaFrom1g=%f", mag, deltaFrom1g);
            if (g_shakeCallback) {
                g_shakeCallback();
            }
        }];
    }
}

// -----------------------------------------------------------------------------
// Share sheet
// -----------------------------------------------------------------------------

static UIViewController* topMostViewController(UIViewController* root) {
    if (!root) return nil;
    UIViewController* vc = root;
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    return vc;
}

static UIViewController* currentRootViewController() {
    UIWindow* keyWindow = nil;
    UIWindow* anyWindowWithRoot = nil;

    // Use modern API for getting windows
    if (@available(iOS 15.0, *)) {
        NSSet<UIScene*>* connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene* scene in connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene* windowScene = (UIWindowScene*)scene;
            for (UIWindow* window in windowScene.windows) {
                if (!anyWindowWithRoot && window.rootViewController)
                    anyWindowWithRoot = window;
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
            if (keyWindow) break;
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow* window in [[UIApplication sharedApplication] windows]) {
            if (!anyWindowWithRoot && window.rootViewController)
                anyWindowWithRoot = window;
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        #pragma clang diagnostic pop
    }

    if (keyWindow && keyWindow.rootViewController) {
        return keyWindow.rootViewController;
    }

    if (anyWindowWithRoot && anyWindowWithRoot.rootViewController) {
        return anyWindowWithRoot.rootViewController;
    }

    // Fallback: try app delegate's window (some Qt setups don't mark a keyWindow)
    id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;
    if (delegate && [delegate respondsToSelector:@selector(window)]) {
        UIWindow* w = [delegate window];
        if (w && w.rootViewController) {
            return w.rootViewController;
        }
    }

    NSLog(@"[iOS Share] currentRootViewController: unable to find a window/rootViewController");
    return nil;
}

static void presentShareSheetWithRetry(UIActivityViewController* activityVC, NSInteger attempt, NSString* logLabel) {
    static std::atomic<bool> s_firstSharePresentation{true};
    if (attempt == 0) {
        // Give the UI a moment to settle on first presentation.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            presentShareSheetWithRetry(activityVC, attempt + 1, logLabel);
        });
        return;
    }

    UIViewController* rootVC = currentRootViewController();
    UIViewController* vc = topMostViewController(rootVC);
    if (!vc) {
        NSLog(@"[iOS Share] No root view controller");
        return;
    }
    if (!vc.view) {
        NSLog(@"[iOS Share] No view on view controller: %@", vc);
        return;
    }

    [vc.view layoutIfNeeded];
    UIWindow* presentingWindow = vc.view.window ? vc.view.window : (rootVC ? rootVC.view.window : nil);
    if (presentingWindow) {
        [presentingWindow layoutIfNeeded];
        if (!presentingWindow.isKeyWindow) {
            [presentingWindow makeKeyAndVisible];
            if (attempt < 4) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    presentShareSheetWithRetry(activityVC, attempt + 1, logLabel);
                });
                return;
            }
        }
    }

    const CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    const CGFloat viewWidth = vc.view.bounds.size.width;
    const CGFloat windowWidth = presentingWindow ? presentingWindow.bounds.size.width : 0.0;
    const bool needsRetry = (!presentingWindow) ||
                            (screenWidth > 0.0 && windowWidth > 0.0 && windowWidth < screenWidth * 0.95) ||
                            (screenWidth > 0.0 && viewWidth > 0.0 && viewWidth < screenWidth * 0.95);

    if (needsRetry && attempt < 4) {
        const double delay = 0.15 + (0.05 * attempt);
        NSLog(@"[iOS Share] VC not ready (window=%@ viewWidth=%.1f windowWidth=%.1f screenWidth=%.1f), retrying...",
              vc.view.window, (double)viewWidth, (double)windowWidth, (double)screenWidth);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            presentShareSheetWithRetry(activityVC, attempt + 1, logLabel);
        });
        return;
    }

    if (screenWidth > 0.0 && viewWidth > 0.0 && viewWidth < screenWidth * 0.95 && rootVC && rootVC != vc) {
        vc = rootVC;
    }

    const bool isFirstPresentation = s_firstSharePresentation.exchange(false);
    activityVC.preferredContentSize = vc.view.bounds.size;
    if (isFirstPresentation) {
        activityVC.modalPresentationStyle = UIModalPresentationFullScreen;
    } else {
        activityVC.modalPresentationStyle = UIModalPresentationPageSheet;
    }

    if (!isFirstPresentation && @available(iOS 15.0, *)) {
        UISheetPresentationController* sheet = activityVC.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible = YES;
        }
    }

    UIPopoverPresentationController* popover = activityVC.popoverPresentationController;
    if (popover) {
        popover.sourceView = vc.view;
        CGRect b = vc.view.bounds;
        popover.sourceRect = CGRectMake(CGRectGetMidX(b), CGRectGetMidY(b), 1, 1);
        popover.permittedArrowDirections = 0;
    }

    NSLog(@"[iOS Share] Presenting UIActivityViewController (%@) mode=%@ root=%@ top=%@ state=%ld",
          logLabel, isFirstPresentation ? @"full" : @"sheet", rootVC, vc,
          (long)[UIApplication sharedApplication].applicationState);
    [vc presentViewController:activityVC animated:YES completion:nil];
}

void presentIOSShareSheetForFilePath(const QString& filePath) {
    @autoreleasepool {
        if (filePath.isEmpty()) return;
        const QString pathCopy = filePath; // copy for async block safety

        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                @try {
                    NSString* nsPath = pathCopy.toNSString();
                    NSURL* url = [NSURL fileURLWithPath:nsPath];
                    if (!url) return;

                    UIActivityViewController* activityVC =
                        [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
                    presentShareSheetWithRetry(activityVC, 0, @"single");
                }
                @catch (NSException* e) {
                    NSLog(@"[iOS Share] Exception presenting share sheet (single): %@ %@", e.name, e.reason);
                }
            }
        });
    }
}

void presentIOSShareSheetForFilePaths(const QStringList& filePaths) {
    @autoreleasepool {
        if (filePaths.isEmpty()) return;
        const QStringList pathsCopy = filePaths; // copy for async block safety

        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                @try {
                    NSMutableArray* items = [NSMutableArray arrayWithCapacity:(NSUInteger)pathsCopy.size()];
                    for (const auto& p : pathsCopy) {
                        if (p.isEmpty()) continue;
                        NSURL* url = [NSURL fileURLWithPath:p.toNSString()];
                        if (url) [items addObject:url];
                    }
                    if (items.count == 0) return;

                    UIActivityViewController* activityVC =
                        [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
                    presentShareSheetWithRetry(activityVC, 0, @"multi");
                }
                @catch (NSException* e) {
                    NSLog(@"[iOS Share] Exception presenting share sheet (multi): %@ %@", e.name, e.reason);
                }
            }
        });
    }
}
