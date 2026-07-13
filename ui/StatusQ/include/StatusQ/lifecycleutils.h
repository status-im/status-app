#pragma once

#include <QtGlobal>

extern "C" {

// Stop the separate Android status-go service process. No-op if not Android.
Q_DECL_EXPORT void statusq_stopBackgroundService();

// Remove every published direct-share shortcut, including system-cached
// copies (logout hygiene). No-op if not Android.
Q_DECL_EXPORT void statusq_clearShareShortcuts();

// Delete every donated send-message interaction, and with them the iOS
// share-sheet suggestion chips they power (logout hygiene — the iOS
// counterpart of statusq_clearShareShortcuts). No-op if not iOS.
// Implemented in externc.cpp via MobileUI::deleteAllDonatedInteractions().
Q_DECL_EXPORT void statusq_deleteDonatedInteractions();

}
