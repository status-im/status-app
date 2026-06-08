#include "StatusQ/lifecycleutils.h"

#ifdef Q_OS_ANDROID
#include <QJniObject>

extern "C" Q_DECL_EXPORT void statusq_stopBackgroundService()
{
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/StatusGoStub",
        "stopService",
        "()V"
    );
}

#else // non-Android stub

extern "C" Q_DECL_EXPORT void statusq_stopBackgroundService() {}

#endif
