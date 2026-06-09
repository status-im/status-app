#include "ios_utils.h"
#include <QStringList>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <objc/runtime.h>
#include <atomic>
#include <cmath>
#include <QString>
#include <QUrl>

static IOSFilePickerAcceptedCallback g_filePickerAcceptedCallback = nullptr;
static IOSFilePickerRejectedCallback g_filePickerRejectedCallback = nullptr;

@interface StatusQDocumentPickerDelegate : NSObject<UIDocumentPickerDelegate>
@end

@interface StatusQPhotoLibraryPickerDelegate : NSObject<UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate>
@end

static UIViewController *statusqActiveRootViewController()
{
    UIWindow *keyWindow = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive)
                continue;

            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }

            if (keyWindow)
                break;
        }
    }

    if (!keyWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }

    if (!keyWindow)
        return nil;

    UIViewController *viewController = keyWindow.rootViewController;
    while (viewController.presentedViewController)
        viewController = viewController.presentedViewController;

    return viewController;
}

@implementation StatusQDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    Q_UNUSED(controller);

    QStringList selectedUrls;
    selectedUrls.reserve(urls.count);

    for (NSURL *url in urls) {
        if (url.absoluteString.length > 0)
            selectedUrls.push_back(QString::fromNSString(url.absoluteString));
    }

    if (g_filePickerAcceptedCallback)
        g_filePickerAcceptedCallback(selectedUrls);
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    Q_UNUSED(controller);

    if (g_filePickerRejectedCallback)
        g_filePickerRejectedCallback();
}

@end

static StatusQDocumentPickerDelegate *g_documentPickerDelegate = nil;
static StatusQPhotoLibraryPickerDelegate *g_photoLibraryPickerDelegate = nil;

void setIOSFilePickerCallbacks(IOSFilePickerAcceptedCallback acceptedCallback,
                               IOSFilePickerRejectedCallback rejectedCallback)
{
    g_filePickerAcceptedCallback = acceptedCallback;
    g_filePickerRejectedCallback = rejectedCallback;
}

void presentIOSDocumentPicker(bool selectMultiple, const QStringList& nameFilters)
{
    Q_UNUSED(nameFilters);

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presentingViewController = statusqActiveRootViewController();
        if (!presentingViewController) {
            NSLog(@"presentIOSDocumentPicker: no active root view controller");
            if (g_filePickerRejectedCallback)
                g_filePickerRejectedCallback();
            return;
        }

        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeOpen];
        #pragma clang diagnostic pop

        g_documentPickerDelegate = [[StatusQDocumentPickerDelegate alloc] init];
        picker.delegate = g_documentPickerDelegate;
        picker.allowsMultipleSelection = selectMultiple;
        picker.modalPresentationStyle = UIModalPresentationFullScreen;

        [presentingViewController presentViewController:picker animated:YES completion:nil];
    });
}

static UIImage *statusqScaledImageForTemporaryFile(UIImage *image)
{
    if (!image)
        return nil;

    const CGFloat maxDimension = 4096.0;
    const CGFloat longestSide = MAX(image.size.width, image.size.height);
    if (longestSide <= maxDimension)
        return image;

    const CGFloat scale = maxDimension / longestSide;
    const CGSize targetSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        Q_UNUSED(context);
        [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    }];
}

static NSURL *statusqWriteImageToTemporaryFile(UIImage *image)
{
    if (!image)
        return nil;

    UIImage *imageToWrite = statusqScaledImageForTemporaryFile(image);
    if (!imageToWrite)
        return nil;

    NSData *imageData = UIImageJPEGRepresentation(imageToWrite, 0.9);
    NSString *extension = @"jpg";

    if (!imageData) {
        imageData = UIImagePNGRepresentation(imageToWrite);
        extension = @"png";
    }

    if (!imageData)
        return nil;

    NSString *fileName = [NSString stringWithFormat:@"%@.%@", [NSUUID UUID].UUIDString, extension];
    NSURL *destinationUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];

    return [imageData writeToURL:destinationUrl atomically:YES] ? destinationUrl : nil;
}

static void statusqCompletePhotoLibraryPicker(UIViewController *picker, NSArray<NSURL *> *urls)
{
    [picker dismissViewControllerAnimated:YES completion:^{
        g_photoLibraryPickerDelegate = nil;
        if (urls.count > 0 && g_filePickerAcceptedCallback) {
            QStringList selectedUrls;
            selectedUrls.reserve(urls.count);
            for (NSURL *url in urls) {
                if (url.absoluteString.length > 0)
                    selectedUrls.push_back(QString::fromNSString(url.absoluteString));
            }
            g_filePickerAcceptedCallback(selectedUrls);
        } else if (g_filePickerRejectedCallback) {
            g_filePickerRejectedCallback();
        }
    }];
}

@implementation StatusQPhotoLibraryPickerDelegate
{
    BOOL _finished;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info
{
    if (_finished)
        return;
    _finished = YES;

    UIImage *image = info[UIImagePickerControllerOriginalImage];
    NSURL *selectedUrl = statusqWriteImageToTemporaryFile(image);
    if (!selectedUrl)
        selectedUrl = info[UIImagePickerControllerImageURL];

    statusqCompletePhotoLibraryPicker(picker, selectedUrl ? @[selectedUrl] : @[]);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    if (_finished)
        return;
    _finished = YES;

    statusqCompletePhotoLibraryPicker(picker, @[]);
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14))
{
    if (_finished)
        return;
    _finished = YES;

    if (results.count == 0) {
        statusqCompletePhotoLibraryPicker(picker, @[]);
        return;
    }

    NSMutableArray *selectedUrls = [NSMutableArray arrayWithCapacity:results.count];
    for (NSUInteger i = 0; i < results.count; i++)
        [selectedUrls addObject:[NSNull null]];
    __block NSInteger pendingResults = results.count;

    void (^finishResult)(NSUInteger, NSURL *) = ^(NSUInteger index, NSURL *url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (url)
                selectedUrls[index] = url;

            pendingResults--;
            if (pendingResults == 0) {
                NSMutableArray<NSURL *> *orderedUrls = [NSMutableArray arrayWithCapacity:selectedUrls.count];
                for (id selectedUrl in selectedUrls) {
                    if ([selectedUrl isKindOfClass:NSURL.class])
                        [orderedUrls addObject:selectedUrl];
                }
                statusqCompletePhotoLibraryPicker(picker, orderedUrls);
            }
        });
    };

    [results enumerateObjectsUsingBlock:^(PHPickerResult *result, NSUInteger index, BOOL *stop) {
        Q_UNUSED(stop);
        NSItemProvider *provider = result.itemProvider;
        if (![provider canLoadObjectOfClass:UIImage.class]) {
            finishResult(index, nil);
            return;
        }

        [provider loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            Q_UNUSED(error);
            finishResult(index, statusqWriteImageToTemporaryFile((UIImage *)object));
        }];
    }];
}

@end

void presentIOSPhotoLibraryPicker(bool selectMultiple)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presentingViewController = statusqActiveRootViewController();
        if (!presentingViewController) {
            NSLog(@"presentIOSPhotoLibraryPicker: no active root view controller");
            if (g_filePickerRejectedCallback)
                g_filePickerRejectedCallback();
            return;
        }

        if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
            NSLog(@"presentIOSPhotoLibraryPicker: photo library source is not available");
            if (g_filePickerRejectedCallback)
                g_filePickerRejectedCallback();
            return;
        }

        if (selectMultiple) {
            if (@available(iOS 14.0, *)) {
                PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
                configuration.filter = [PHPickerFilter imagesFilter];
                configuration.selectionLimit = 0;

                PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
                g_photoLibraryPickerDelegate = [[StatusQPhotoLibraryPickerDelegate alloc] init];
                picker.delegate = g_photoLibraryPickerDelegate;
                picker.modalPresentationStyle = UIModalPresentationFullScreen;

                [presentingViewController presentViewController:picker animated:YES completion:nil];
                return;
            }
        }

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        g_photoLibraryPickerDelegate = [[StatusQPhotoLibraryPickerDelegate alloc] init];
        picker.delegate = g_photoLibraryPickerDelegate;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.modalPresentationStyle = UIModalPresentationFullScreen;

        [presentingViewController presentViewController:picker animated:YES completion:nil];
    });
}

void saveImageToPhotosAlbumAsync(const QByteArray &data, const std::function<void(bool)>& completion)
{
    auto completeOnMain = [completion](bool success) {
        if (!completion)
            return;

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success);
        });
    };

    NSData *imageData = [NSData dataWithBytes:data.constData() length:data.length()];
    UIImage *image = [UIImage imageWithData:imageData];
    if (!image) {
        NSLog(@"Failed to save image");
        completeOnMain(false);
        return;
    }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError *error) {
        if (!success)
            NSLog(@"Failed to save image: %@", error);

        completeOnMain(success);
    }];
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
