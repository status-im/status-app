#include <StatusQ/shareintake.h>

// No App Group container outside iOS: the pending intake slot is inactive and
// there is no shared image cache (Android's share-intake cache is app-private
// and owned by the platform layer).
QString Status::ShareIntake::pendingIntakeDir()
{
    return {};
}

QString Status::ShareIntake::shareIntakeCacheDir()
{
    return {};
}
