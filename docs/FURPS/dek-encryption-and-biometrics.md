# Profile DEK Encryption, Biometric Login & Stay Logged In

**Relevant issues/PRs**
- https://github.com/status-im/status-app/issues/21877
  - https://github.com/status-im/status-go/pull/7691
  - https://github.com/status-im/status-app/pull/21878
- https://github.com/status-im/status-app/issues/22036
  - https://github.com/status-im/status-go/pull/7762
  - https://github.com/status-im/status-app/pull/22080

----

**Definitions:**

- **DEK** (data encryption key): a random 32-byte key that encrypts a profile's databases and keystore files. Stored only in the profile's envelope file (<keyUID>-profile.kek), wrapped by the KEK.
- **KEK** (key encryption key): the client-hashed password, or for Keycard profiles the card-exported encryption public key. Unwraps the DEK, encrypts nothing else.
- **Migrated profile**: a profile whose envelope file exists (databases/keystore encrypted with the DEK). Legacy profile: no envelope, databases encrypted directly with the KEK.
- **Silent credential**: the tagged DEK (`dek:<64-hex>`) stored in platform secure storage (`SecureStorage`, service `StatusDesktop.AutoLogin`, account = profile keyUID) for the "Stay logged in" feature. Readable without any user-presence prompt — unlike the biometric item, its only protections are the store's at-rest encryption and device locality.
- **Stay-logged-in preference**: a per-profile boolean (`stayLoggedIn` in the per-account settings file) remembering the toggle position. Deliberately NOT the startup trigger — it governs whether the credential is (re-)stored after an explicit login.
- **Auto-login suppression**: a per-profile marker in the global app settings (`global/auto_login_suppressed/<keyUID>`), readable before login, set when a sign-out could not verifiably remove the silent credential.

----

**Functionality**

- **Encryption scheme**
  - New profiles (created, restored, or received via pairing) must be DEK-encrypted from creation.
  - A legacy profile must be migrated to DEK encryption as a one-time action, and **only** as part of a password change. No other action (enabling biometrics, logging in, syncing) triggers the migration or any database re-encryption.
  - The DEK must be obtainable from the backend only via `ExportProfileDEK`.

- **Password change**
  - For a migrated profile, a password change without rekey only re-wraps the envelope (fast path): databases, keystore, and the running node are untouched, and no app restart is required. The DEK is unchanged.
  - A password change with rekey must generate a new DEK and re-encrypt databases and keystore.
  - A password change on a legacy profile must perform the one-time DEK migration (full re-encryption) using the new password as the KEK.
  - A caller holding only a session credential (e.g. a biometric DEK) may use the fast path; rekey and migration require the typed old password.

- **Biometric credential contents**
  - The OS keychain item (service `StatusDesktop`, account = profile keyUID) must contain, per profile type:
    - migrated password profile → the DEK, tagged `dek:<64-hex>`;
    - legacy password profile → the raw password (untagged; pre-existing behavior preserved until migration);
    - Keycard profile → the 6-digit PIN (untagged). The physical card is always required for Keycard login and signing; the DEK must never be stored for Keycard profiles.
  - A `dek:`-tagged value is stored for a migrated profiles.

- **Enabling biometrics**
  - Enabling biometrics must be instant: it stores the tagged dek and never triggers profile migration or re-encryption.
  - If the credential cannot be prepared or stored, biometrics must remain disabled, means no partial or wrong value may be saved.

- **Biometric login**
  - A `dek:`-tagged secret must be submitted as a raw DEK in the dedicated login field, an untagged secret represents the password (or Keycard PIN).
  - A DEK login is valid only for migrated profiles.
  - A wrong or stale DEK must fail exactly like a wrong password and fall back to manual entry.

- **Credential refresh (migration of stored values)**
  - After any successful authentication where a keychain item exists and the profile is migrated but the item is legacy, the item must be silently refreshed to the tagged DEK. This never re-encrypts anything.
  - After every successful password change with an existing item, the item must be refreshed (fast change: same DEK; rekey: new DEK; legacy→migrated: password replaced by DEK).
  - If the refresh fails, the stale item must be deleted and biometrics disabled with the preference set to `notNow`.

- **In-app authentication & signing**
  - Within an unlocked session, the backend must accept the client-hashed DEK wherever it accepts the hashed password (verification, signing, keystore operations), the stored DEK uses the existing password flows.
  - Keycard transaction signing and authorization always require the card and PIN, biometrics only supplies the PIN.
  - Device syncing / keystore export (pairing) requires the typed password — the DEK cannot substitute for it (the password itself is validated against and transferred with the keystore). Biometrics are not offered at all for this action (manual entry only); the same applies to disabling biometrics, which deliberately requires the typed credential as proof the user still knows it.

- **Lifecycle**
  - Disabling biometrics must delete the keychain item and record the `never` preference, while failure-triggered deletions record `notNow`.
  - Converting a profile to/from Keycard must not leave a usable stale biometric credential behind.

----

**Stay logged in (automatic login)**

- **What is stored where**
  - The silent credential (tagged DEK, never the password, never a Keycard PIN) lives in platform secure storage under service `StatusDesktop.AutoLogin` — a separate namespace from the biometric item's `StatusDesktop`. Backends: macOS/iOS data-protection keychain with device-only, non-migratable accessibility (no legacy-keychain fallback — unlike biometrics, there is no auth gate to compensate for a weaker store); Windows DPAPI per-user blob in local (non-roaming) AppData with identity-bound entropy; Linux Secret Service (GNOME Keyring/KWallet) through a structurally prompt-free client; Android Keystore AES-GCM-wrapped blob in a backup-excluded preferences file.
  - The `stayLoggedIn` preference lives in the per-account settings file (bound only after login). It survives logout by design: with it ON, the next explicit login silently re-stores the credential. Always false in test mode.
  - `global/selected_profile_key_uid` (global app settings, pre-login) records the last logged-in profile — written whenever the main app loads, for every login path including fresh onboarding — and is the only profile auto-login ever targets.
  - The auto-login suppression marker (global app settings, pre-login) — see Sign-out below.

- **Opt-in**
  - Onboarding: the Create Password page offers the opt-in (default ON for new users) next to the biometrics opt-in; both are applied by a post-login task. The task is structurally DEK-only: it converts via the DEK exporter and refuses to store anything that is not a tagged DEK (a raw password can never reach the silent store, even one that happens to look like a DEK).
  - Settings → Password: enabling requires the standard authentication popup (the password is needed to export the DEK), then stores the credential FIRST and flips the preference only on success. An indeterminate store (Linux timeout — the write MAY have committed) first attempts a converging deletion; if even that is unverifiable, the preference is aligned with the worst case (enabled) and reconciled at the next login.
  - Keycard profiles cannot opt in at all: the toggle is disabled with an explanation ("the Keycard is always required to log in") — a silently readable credential would defeat the physical-card requirement.
  - Legacy profiles cannot opt in (there is no DEK): the toggle is disabled with a "Migrate to the new encryption format" button → authentication popup → in-place same-password migration (no rekey) under a non-dismissible progress modal, then the mandatory app restart. The whole migration flow is owned at the application level so it survives navigating away from Settings.

- **Automatic login at startup**
  - The trigger is **credential presence itself**, not the preference (the per-account file is not readable before login, and logout already deleted the credential when auto-login must not fire).
  - One-shot attempt, gated in order: auto-login enabled (false in test mode or while suppressed), secure storage available, a last-selected profile recorded, that profile present in the accounts model and not a Keycard profile, a stored credential retrieved successfully and `dek:`-tagged (anything else is deleted on sight). Every bail reason is logged to the pre-login log.
  - On success the DEK is submitted through the standard DEK-login path (same rails as biometric login — splash screen, no login-screen flash). On a login error, a consume-once fallback deletes that profile's credential and shows the normal login screen; there is no retry loop, and the preference stays ON.
  - After every explicit password login, a post-login task reconciles state: clears any auto-login suppression, re-stores the credential when the preference is ON, or deletes a stale credential when it is OFF.

- **Sign-out and lifecycle cleanup**
  - Sign-out deletes the silent credential FIRST and proceeds on verified removal (deleted, never present, or `NotSupported` — the stub backend where no build could ever have stored one). On any unverified outcome it durably suppresses startup auto-login for the profile (the marker is flushed to disk and verified — mobile logout hard-exits right after) and then signs out; only when NEITHER deletion nor suppression can be confirmed is the session kept for a retry. The preference survives sign-out; the biometric item is untouched.
  - Password change / rekey refresh the stored credential from the new password (a deep rekey mints a new DEK). On refresh failure the stale credential is deleted, and the preference is flipped OFF only when that deletion verifiably succeeded.
  - Converting the profile to Keycard requires verified removal of the silent credential BEFORE the flow may start (the rekey-free conversion keeps the same DEK, so a survivor would keep decrypting the databases without the card).

- **Failure semantics of the store**
  - Reads are synchronous and can never show a system prompt. `NotSupported` means "no backend exists on this platform" and only that; a store this process merely cannot reach (e.g. an unsigned macOS build without keychain entitlements) reports `Unavailable`, which proves nothing about what an entitled build may have stored.
  - On Linux every operation runs under a bounded deadline; a mutation whose outcome cannot be proven reports `StatusIndeterminate`, and the backend converges a possibly-committed write back to absent while blocking follow-up mutations for the account until that cleanup completed.

----

**Supportability / Security**

- Platforms (biometrics): macOS, iOS, Android. Windows/Linux have no biometric support.
- Platforms (stay logged in): all five — macOS/iOS (data-protection keychain), Windows (DPAPI), Linux (Secret Service), Android (Keystore). On macOS the data-protection keychain requires a provisioned code signature; unsigned dev builds report the store as unavailable — see `docs/internal/macos-secure-storage-testing.md` for local testing.
- The silent credential is strictly device-local on every platform (non-migratable keychain accessibility, DPAPI user+machine binding, backup-excluded Android preferences); it is never autofilled into any UI and never logged.
- The raw DEK crosses the client/backend boundary only in the dedicated login field and the `ExportProfileDEK` response, both are masked (`***`) in request logs.
- The client-hashed DEK grants nothing outside an unlocked session, at the end only the KEK can unwrap the envelope.
- Compromise of a stored DEK affects only that one profile on that one device, it reveals no reusable password and cannot be transferred to another device.
