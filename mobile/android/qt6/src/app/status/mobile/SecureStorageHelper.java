package app.status.mobile;

import android.content.Context;
import android.util.Base64;
import android.util.Log;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.UnrecoverableKeyException;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyPermanentlyInvalidatedException;
import android.security.keystore.KeyProperties;

/**
 * Framework-only silent secure storage used from Qt via JNI (SecureStorage QML type).
 *
 * Counterpart of SecureAndroidAuthentication with the OPPOSITE authentication contract:
 * the AES/GCM key in AndroidKeyStore is generated with user authentication NOT required,
 * so every operation is synchronous and never shows any system UI — this backs features
 * like "Stay logged in" where a credential must be readable silently at app startup.
 * The key never leaves the Keystore (hardware-backed where available); SharedPreferences
 * hold only {iv, ciphertext} per account and are excluded from all backups/transfers
 * (see res/xml/backup_rules.xml and data_extraction_rules.xml), keeping the credential
 * strictly device-local.
 *
 * Every operation returns an explicit STATUS_* code (kept in sync with
 * securestorage_android.cpp) — absence and backend failure are never conflated:
 * STATUS_NOT_FOUND is returned only for genuine absence or corruption whose cleanup has
 * VERIFIABLY succeeded; failed cleanup or any backend error reports STATUS_ERROR, so
 * corrupted state can never linger behind a "does not exist" answer.
 *
 * All methods are synchronous and must not throw across JNI.
 */
public final class SecureStorageHelper {

    private static final String TAG = "SecureStorageHelper";

    // Deliberately distinct from SecureAndroidAuthentication's alias/prefs — the two
    // stores must never interfere (different keys, different auth requirements).
    private static final String ALIAS = "StatusSS_AES";
    private static final String PREFS_NAME = "StatusSecureStorage";
    private static final String KEY_CT_PREFIX = "ct_"; // ciphertext
    private static final String KEY_IV_PREFIX = "iv_"; // iv

    // Status codes (kept in sync with securestorage_android.cpp).
    public static final int STATUS_OK = 0;
    public static final int STATUS_NOT_FOUND = 1;
    public static final int STATUS_ERROR = -1;

    // Android Keystore-generated AES/GCM IVs are exactly this long; any other decoded
    // length is a corrupted blob, not something cipher init could ever accept.
    private static final int GCM_IV_LENGTH = 12;

    private static SecureStorageHelper sInst;

    public static synchronized SecureStorageHelper getInstance(Context ctx) {
        if (sInst == null) sInst = new SecureStorageHelper(ctx.getApplicationContext());
        return sInst;
    }

    private final Context mContext;

    private SecureStorageHelper(Context ctx) {
        this.mContext = ctx;
    }

    /** Keystore reachable and usable (never prompts, never throws). */
    public boolean isAvailable() {
        try {
            KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
            ks.load(null);
            return true;
        } catch (Throwable t) {
            Log.w(TAG, "isAvailable: Keystore unusable", t);
            return false;
        }
    }

    /** Encrypt and persist synchronously. */
    public int setCredential(String account, String secret) {
        try {
            Cipher enc;
            try {
                enc = newEncryptCipher();
            } catch (KeyPermanentlyInvalidatedException | UnrecoverableKeyException e) {
                // The key is dead (e.g. secure lock screen removed with policies that kill
                // keys, or a corrupted Keystore entry). Every stored blob is undecryptable
                // dead data — wipe consistently, then encrypt under a fresh key. A failed
                // wipe leaves the alias untouched so the next attempt retries.
                Log.w(TAG, "setCredential: key unusable, regenerating", e);
                if (!wipeAll()) return STATUS_ERROR;
                enc = newEncryptCipher();
            }
            byte[] ct = enc.doFinal(secret.getBytes(StandardCharsets.UTF_8));
            boolean stored = prefs().edit()
                    .putString(KEY_IV_PREFIX + account, Base64.encodeToString(enc.getIV(), Base64.NO_WRAP))
                    .putString(KEY_CT_PREFIX + account, Base64.encodeToString(ct, Base64.NO_WRAP))
                    .commit();
            return stored ? STATUS_OK : STATUS_ERROR;
        } catch (Throwable t) {
            Log.w(TAG, "setCredential failed", t);
            return STATUS_ERROR;
        }
    }

    /**
     * Decrypt synchronously; on STATUS_OK the secret is written to out[0].
     *
     * Corruption (incomplete pair, malformed Base64, unusable key, undecryptable blob) is
     * wiped before STATUS_NOT_FOUND is returned; when the wipe itself fails, STATUS_ERROR
     * is returned instead so hasCredential() cannot keep reporting ghost entries behind a
     * "does not exist" answer.
     */
    public int getCredential(String account, String[] out) {
        try {
            if (out == null || out.length < 1) return STATUS_ERROR;
            out[0] = null;

            final boolean hasIv = prefs().contains(KEY_IV_PREFIX + account);
            final boolean hasCt = prefs().contains(KEY_CT_PREFIX + account);
            if (!hasIv && !hasCt) return STATUS_NOT_FOUND;
            if (!hasIv || !hasCt) {
                // Half a pair is corruption — remove the remaining half, verified.
                Log.w(TAG, "getCredential: incomplete blob pair, wiping entry");
                return wipeEntry(account) ? STATUS_NOT_FOUND : STATUS_ERROR;
            }

            byte[] iv;
            byte[] ct;
            try {
                iv = loadBytes(KEY_IV_PREFIX + account);
                ct = loadBytes(KEY_CT_PREFIX + account);
            } catch (IllegalArgumentException e) {
                // Malformed Base64 — corruption, not absence.
                Log.w(TAG, "getCredential: malformed blob, wiping entry", e);
                return wipeEntry(account) ? STATUS_NOT_FOUND : STATUS_ERROR;
            }

            // Valid Base64 can still decode to an unusable payload; cipher init would
            // throw a non-recoverable exception on a wrong-length IV. That is corruption
            // too — wipe it (verified) instead of letting it reach the generic error
            // path and linger forever.
            if (iv == null || iv.length != GCM_IV_LENGTH || ct == null || ct.length == 0) {
                Log.w(TAG, "getCredential: invalid blob payload, wiping entry");
                return wipeEntry(account) ? STATUS_NOT_FOUND : STATUS_ERROR;
            }

            Cipher dec;
            try {
                dec = newDecryptCipher(iv);
            } catch (KeyPermanentlyInvalidatedException | UnrecoverableKeyException e) {
                // Key-level failure: every blob in this store is dead data.
                Log.w(TAG, "getCredential: key unusable, wiping store", e);
                return wipeAll() ? STATUS_NOT_FOUND : STATUS_ERROR;
            }

            try {
                out[0] = new String(dec.doFinal(ct), StandardCharsets.UTF_8);
                return STATUS_OK;
            } catch (Exception e) {
                // Wrong key for this blob (e.g. restored from another device despite the
                // backup exclusions) or corrupted data — unusable either way.
                Log.w(TAG, "getCredential: undecryptable blob, wiping entry", e);
                return wipeEntry(account) ? STATUS_NOT_FOUND : STATUS_ERROR;
            }
        } catch (Throwable t) {
            // Transient backend failure — NOT "does not exist".
            Log.w(TAG, "getCredential failed", t);
            return STATUS_ERROR;
        }
    }

    /**
     * Presence-at-rest check (no prompt, no decryption). An incomplete pair is treated as
     * corruption: wiped (verified) and reported absent, or STATUS_ERROR when the wipe
     * fails.
     */
    public int hasCredential(String account) {
        try {
            final boolean hasIv = prefs().contains(KEY_IV_PREFIX + account);
            final boolean hasCt = prefs().contains(KEY_CT_PREFIX + account);
            if (hasIv && hasCt) return STATUS_OK;
            if (!hasIv && !hasCt) return STATUS_NOT_FOUND;

            Log.w(TAG, "hasCredential: incomplete blob pair, wiping entry");
            return wipeEntry(account) ? STATUS_NOT_FOUND : STATUS_ERROR;
        } catch (Throwable t) {
            Log.w(TAG, "hasCredential failed", t);
            return STATUS_ERROR;
        }
    }

    /** Remove the stored blob for an account. */
    public int deleteCredential(String account) {
        try {
            final boolean hasIv = prefs().contains(KEY_IV_PREFIX + account);
            final boolean hasCt = prefs().contains(KEY_CT_PREFIX + account);
            if (!hasIv && !hasCt) return STATUS_NOT_FOUND;
            return wipeEntry(account) ? STATUS_OK : STATUS_ERROR;
        } catch (Throwable t) {
            Log.w(TAG, "deleteCredential failed", t);
            return STATUS_ERROR;
        }
    }

    // ====== Keystore helpers ======

    private SecretKey ensureKey() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        if (!ks.containsAlias(ALIAS)) {
            KeyGenParameterSpec spec = new KeyGenParameterSpec.Builder(
                    ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    // The whole point of this store: silently readable, no prompt ever.
                    .setUserAuthenticationRequired(false)
                    .build();
            KeyGenerator kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            kg.init(spec);
            kg.generateKey();
        }
        KeyStore.SecretKeyEntry e = (KeyStore.SecretKeyEntry) ks.getEntry(ALIAS, null);
        return e.getSecretKey();
    }

    /**
     * Removes every stored blob and then the unusable AES key. Blobs are cleared first
     * (synchronously, result checked): if the alias were deleted first and the process
     * stopped before the prefs write, the next use would silently generate a fresh key
     * and the leftover ciphertext would become permanent ghost entries. Mirrors
     * SecureAndroidAuthentication.handleInvalidatedKey().
     *
     * @return true when the state is verifiably consistent again (blobs gone). Alias
     *         removal afterwards is best-effort: with the blobs gone no ghosts are
     *         possible, and a surviving dead alias merely re-triggers this cleanup.
     */
    private boolean wipeAll() {
        if (!prefs().edit().clear().commit()) {
            Log.w(TAG, "wipeAll: failed to clear credential blobs");
            return false;
        }
        try {
            KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
            ks.load(null);
            if (ks.containsAlias(ALIAS)) ks.deleteEntry(ALIAS);
        } catch (Exception e) {
            Log.w(TAG, "wipeAll: failed to delete key alias", e);
        }
        return true;
    }

    /** Removes one account's blobs; the commit result is the verification. */
    private boolean wipeEntry(String account) {
        boolean ok = prefs().edit()
                .remove(KEY_IV_PREFIX + account)
                .remove(KEY_CT_PREFIX + account)
                .commit();
        if (!ok) Log.w(TAG, "wipeEntry: failed to remove blobs");
        return ok;
    }

    private Cipher newEncryptCipher() throws Exception {
        Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.ENCRYPT_MODE, ensureKey());
        return c;
    }

    private Cipher newDecryptCipher(byte[] iv) throws Exception {
        Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.DECRYPT_MODE, ensureKey(), new GCMParameterSpec(128, iv));
        return c;
    }

    // ====== Storage helpers ======

    private android.content.SharedPreferences prefs() {
        return mContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    /** @throws IllegalArgumentException on malformed Base64 (handled as corruption). */
    private byte[] loadBytes(String key) {
        String b64 = prefs().getString(key, null);
        return b64 == null ? null : Base64.decode(b64, Base64.NO_WRAP);
    }
}
