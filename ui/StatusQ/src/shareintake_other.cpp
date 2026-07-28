#include <StatusQ/shareintake.h>

// No App Group container outside iOS: the pending intake slot is inactive.
QString Status::ShareIntake::pendingIntakeDir()
{
    return {};
}
