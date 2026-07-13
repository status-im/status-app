#include "StatusQ/lifecycleutils.h"

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QtCore/qnativeinterface.h>

extern "C" Q_DECL_EXPORT void statusq_stopBackgroundService()
{
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/StatusGoStub",
        "stopService",
        "()V"
    );
}

// Logout hygiene: direct-share shortcuts carry chat names and avatars on OS
// surfaces outside the app process, so they are removed unconditionally when
// the profile logs out (called from the Nim main module; also backs
// SystemUtilsInternal::clearShareShortcuts), not only when QML happens to
// republish.
extern "C" Q_DECL_EXPORT void statusq_clearShareShortcuts()
{
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return;

    QJniObject::callStaticMethod<void>(
        "app/status/mobile/ShareShortcutsHelper",
        "clear",
        "(Landroid/content/Context;)V",
        context.object()
    );
}

#else // non-Android stubs

extern "C" Q_DECL_EXPORT void statusq_stopBackgroundService() {}
extern "C" Q_DECL_EXPORT void statusq_clearShareShortcuts() {}

#endif
