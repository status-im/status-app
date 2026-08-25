# Profile DEK Encryption & Biometric Login

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
  - Device syncing / keystore export (pairing) requires the typed password — the DEK cannot substitute for it (the password itself is validated against and transferred with the keystore). A biometric attempt that yields a DEK must fall back to manual password entry.

- **Lifecycle**
  - Disabling biometrics must delete the keychain item and record the `never` preference, while failure-triggered deletions record `notNow`.
  - Converting a profile to/from Keycard must not leave a usable stale biometric credential behind.

----

**Supportability / Security**

- Platforms: macOS, iOS, Android. Windows/Linux have no biometric support.
- The raw DEK crosses the client/backend boundary only in the dedicated login field and the `ExportProfileDEK` response, both are masked (`***`) in request logs.
- The client-hashed DEK grants nothing outside an unlocked session, at the end only the KEK can unwrap the envelope.
- Compromise of a stored DEK affects only that one profile on that one device, it reveals no reusable password and cannot be transferred to another device.
