// Workaround for a Qt 6.11 iOS crash (#21450): destroying a Qt Quick Control
// while an assistive technology (VoiceOver etc.) is active kills the app with
// SIGBUS.
//
// Root cause (Qt bug, present in 6.11.0/6.11.1/6.12.0): QQuickItem::~QQuickItem()
// emits QAccessible::ObjectDestroyed after the base destructor has already reset
// the object's vptr to QQuickItem's vtable. The iOS platform plugin is the only
// one that answers this event by calling iface->role(). For a Control whose
// accessibleRole() is NoRole, that reaches QQuickControlPrivate::accessibleRole()
// -> q->accessibleRole(): a virtual call through vtable slot 56, past the end of
// QQuickItem's 46-entry vtable. It lands on QObjectPrivate::flagsForDumping(),
// which returns std::string through the sret register x8 -- still holding the
// vtable pointer -- and stores 24 bytes into the read-only vtable. SIGBUS.
//
// Minimal reproducer: https://github.com/alexjba/qtbug-ios-a11y
//
// Mechanism: QAccessible::installUpdateHandler() intercepts every accessibility
// event BEFORE it reaches the platform plugin (qaccessible.cpp:
// updateAccessibility() returns right after calling the handler). We swallow
// ObjectDestroyed and replicate the plugin's safe half -- cache invalidation and
// the layout-changed notification -- then forward every other event to the
// platform plugin unchanged.
//
// Notes:
//  * installUpdateHandler is documented \internal but is exported from QtGui's
//    public headers and the only other installer in all of Qt is QTestLib.
//  * Swallowing ObjectDestroyed leaks nothing: QAccessibleCache deletes the
//    interface through its own QObject::destroyed connection, independently of
//    this event.
//  * The plugin would post ScreenChanged when the destroyed object's role() is
//    Window/Dialog and LayoutChanged otherwise. Choosing requires calling
//    role() on the dying object -- which is exactly the bug -- so we always post
//    LayoutChanged: VoiceOver re-reads the layout instead of doing a full reset.

#import <UIKit/UIKit.h>

#include <QtGui/QAccessible>
#include <QtGui/QGuiApplication>
#include <QtGui/QWindow>

#include <QtGui/private/qguiapplication_p.h>
#include <qpa/qplatformaccessibility.h>
#include <qpa/qplatformintegration.h>

#include <QtCore/QDebug>

static void forwardToPlatform(QAccessibleEvent *event)
{
    QPlatformIntegration *pi = QGuiApplicationPrivate::platformIntegration();
    if (QPlatformAccessibility *pa = pi ? pi->accessibility() : nullptr)
        pa->notifyAccessibilityUpdate(event);
}

static void accessibilityUpdateHandler(QAccessibleEvent *event)
{
    if (event->type() != QAccessible::ObjectDestroyed) {
        forwardToPlatform(event);
        return;
    }

    // Replicate QIOSPlatformAccessibility's invalidateCache() with public API:
    // on iOS QWindow::winId() returns the QUIView*, whose (Accessibility)
    // category has -clearAccessibleCache. The respondsToSelector guard turns a
    // future Qt rename into a logged no-op instead of a crash.
    const auto windows = QGuiApplication::topLevelWindows();
    for (QWindow *win : windows) {
        if (!win || !win->handle())
            continue;
        UIView *view = reinterpret_cast<UIView *>(win->winId());
        if ([view respondsToSelector:@selector(clearAccessibleCache)])
            [view performSelector:@selector(clearAccessibleCache)];
        else
            qWarning("ios a11y crash filter: QUIView no longer responds to "
                     "clearAccessibleCache; accessible cache not invalidated");
    }

    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

void installIosAccessibilityCrashFilter()
{
    QAccessible::installUpdateHandler(accessibilityUpdateHandler);
}
