#ifndef STATUSQ_SHARE_INTAKE_H
#define STATUSQ_SHARE_INTAKE_H

#include <QString>

namespace Status::ShareIntake
{
    // Directory of the pending intake slot shared with the iOS share extension
    // (a subdirectory of the App Group container). Empty on platforms without
    // an App Group container, or when the container cannot be resolved (e.g.
    // the app-groups entitlement is missing) — an empty dir means the slot is
    // inactive on the Nim side (src/app/core/intake/pending_intake_slot.nim).
    QString pendingIntakeDir();

    // Directory holding the extension-made copies of shared images (the
    // `share-intake` subdirectory of the App Group container — same name as
    // the Android app-private cache dir, so the Nim cache-lifecycle guard in
    // src/app/core/intake/share_intake_cache.nim covers both). Empty on
    // platforms without an App Group container; there the platform layer owns
    // its own cache dir (Android) or no share cache exists.
    QString shareIntakeCacheDir();
}

#endif // STATUSQ_SHARE_INTAKE_H
