// Workarounds for Qt 6.11 accessibility crashes, installed via
// QAccessible::installUpdateHandler() so events are filtered before they reach
// the platform plugin (see qaccessible.cpp updateAccessibility()).
//
// Shared libStatusQ: constructor below runs when the dylib is mapped (before
// main). Static StatusQ (STATUSQ_STATIC_LIB): the linker may drop this TU unless
// a symbol is referenced — statusq_linkAccessibilityCrashFilter() is called from
// typesregistration.cpp (always-linked) to force this object into the final
// binary; the constructor then still runs before main.
//
// iOS (#21450): destroying a QQuickControl while VoiceOver (etc.) is active
// SIGBUS-es in the iOS plugin's ObjectDestroyed path (role() on a half-destroyed
// Control). Minimal reproducer: https://github.com/alexjba/qtbug-ios-a11y
//
// macOS (#21491): Qt WebEngine HTML datepicker / table-like popups SIGSEGV in
// QMacAccessibilityElement initWithId:role: when a table cell's table() is null.
// Minimal reproducer: https://github.com/friofry/qtbug-macos-webengine-datepicker
//
// installUpdateHandler is documented \internal but exported from QtGui public
// headers (also used by QTestLib). Define STATUS_DISABLE_A11Y_CRASH_FILTER to
// build a negative-test binary that reproduces the Qt crash.

#include <QtGui/QAccessible>
#include <QtGui/QGuiApplication>
#include <QtGui/QWindow>

#include <QtGui/private/qguiapplication_p.h>
#include <qpa/qplatformaccessibility.h>
#include <qpa/qplatformintegration.h>

#if defined(Q_OS_IOS)
#import <UIKit/UIKit.h>
#include <QtCore/QDebug>
#endif

#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)

static void forwardToPlatform(QAccessibleEvent *event)
{
    QPlatformIntegration *pi = QGuiApplicationPrivate::platformIntegration();
    if (QPlatformAccessibility *pa = pi ? pi->accessibility() : nullptr)
        pa->notifyAccessibilityUpdate(event);
}

static void accessibilityUpdateHandler(QAccessibleEvent *event)
{
    if (!event)
        return;

#if defined(Q_OS_IOS)
    // #21450: swallow ObjectDestroyed — the iOS plugin would call role() on a
    // half-destroyed QQuickControl (SIGBUS). Replicate the safe half instead.
    if (event->type() == QAccessible::ObjectDestroyed) {
        // Replicate QIOSPlatformAccessibility's invalidateCache() with public
        // API: on iOS QWindow::winId() returns the QUIView*, whose
        // (Accessibility) category has -clearAccessibleCache.
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
        return;
    }
#elif defined(Q_OS_MACOS)
    // #21491: Cocoa crashes creating AX elements for table cells whose table()
    // is null (HTML datepicker via WebEngine). Drop only those updates; let the
    // platform handle missing/invalid interfaces (e.g. ObjectDestroyed teardown).
    if (QAccessibleInterface *iface = event->accessibleInterface()) {
        if (iface->isValid()) {
            if (const auto *cell = iface->tableCellInterface()) {
                QAccessibleInterface *table = cell->table();
                if (!table || !table->isValid() || !table->tableInterface())
                    return;
            }
        }
    }
#endif

    forwardToPlatform(event);
}

static void installAccessibilityCrashFilter()
{
#if !defined(STATUS_DISABLE_A11Y_CRASH_FILTER)
    QAccessible::installUpdateHandler(accessibilityUpdateHandler);
#endif
}

// Referenced from typesregistration.cpp so static archives keep this TU.
// Idempotent if the constructor already installed the handler.
extern "C" Q_DECL_EXPORT void statusq_linkAccessibilityCrashFilter()
{
    installAccessibilityCrashFilter();
}

__attribute__((constructor))
static void statusq_autoInstallAccessibilityCrashFilter()
{
    installAccessibilityCrashFilter();
}

#endif // Q_OS_IOS || Q_OS_MACOS
