#pragma once

#include <QtGlobal>

extern "C" {

// Stop the separate Android status-go service process. No-op if not Android.
Q_DECL_EXPORT void statusq_stopBackgroundService();

}
