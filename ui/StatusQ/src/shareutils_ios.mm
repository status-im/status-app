#include "StatusQ/shareutils.h"

#import <UIKit/UIKit.h>

void ShareUtils::shareText(const QString &text) {
    // Convert QString to NSString
    NSString *message = text.toNSString();
    NSArray *itemsToShare = @[message];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
        initWithActivityItems:itemsToShare
        applicationActivities:nil];

    // --- Modern Way to find the Root View Controller without QPA ---
    UIViewController *rootVC = nil;

    // For iOS 13+, we look for the active scene
    if (@available(iOS 13.0, *)) {
        for (UIScene* scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                rootVC = ((UIWindowScene *)scene).windows.firstObject.rootViewController;
                break;
            }
        }
    }

    // Fallback for older versions or if scene finding fails
    if (!rootVC) {
        rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    }

    if (!rootVC) return;

    // --- iPad Handling (Essential for stability) ---
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = rootVC.view;
        // Center the popover on iPad
        activityVC.popoverPresentationController.sourceRect =
            CGRectMake(rootVC.view.bounds.size.width / 2,
                       rootVC.view.bounds.size.height / 2, 0, 0);
        activityVC.popoverPresentationController.permittedArrowDirections = 0;
    }

    [rootVC presentViewController:activityVC animated:YES completion:nil];
}
