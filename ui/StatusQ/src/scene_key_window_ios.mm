// Qt's iOS scene delegate never makes the QUIWindow key. On iOS 27, after a
// Spotlight launch, the scene then has no key window and the on-screen
// keyboard stays with the system shell (#22952).

#import <UIKit/UIKit.h>

#include <QtCore/qglobal.h>

#include <dispatch/dispatch.h>

static void makeQtWindowKeyIfNone(UIWindowScene *scene)
{
    if (scene.keyWindow)
        return;

    Class qtWindowClass = NSClassFromString(@"QUIWindow");
    for (UIWindow *window in scene.windows) {
        if ([window isKindOfClass:qtWindowClass]) {
            [window makeKeyWindow];
            return;
        }
    }
}

static void installSceneKeyWindowFix()
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSNotificationCenter.defaultCenter addObserverForName:UISceneDidActivateNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *notification) {
            if ([notification.object isKindOfClass:UIWindowScene.class])
                makeQtWindowKeyIfNone((UIWindowScene *)notification.object);
        }];
    });
}

extern "C" Q_DECL_EXPORT void statusq_linkSceneKeyWindowFix()
{
    installSceneKeyWindowFix();
}

__attribute__((constructor))
static void statusq_autoInstallSceneKeyWindowFix()
{
    installSceneKeyWindowFix();
}
