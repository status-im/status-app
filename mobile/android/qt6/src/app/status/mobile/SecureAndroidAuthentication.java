package app.status.mobile;

import android.app.Activity;
import android.content.Context;
import android.content.DialogInterface;
import android.hardware.biometrics.BiometricManager;
import android.hardware.biometrics.BiometricPrompt;
import android.hardware.fingerprint.FingerprintManager;
import android.os.Build;
import android.os.CancellationSignal;
import android.util.Base64;
import android.util.Log;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyPermanentlyInvalidatedException;
import android.security.keystore.KeyProperties;

/**
 * Framework-only (no AndroidX) biometric helper used from Qt via JNI.
 * - AES/GCM key in AndroidKeyStore (user-auth required).
 * - Stores {iv,ciphertext} per account in SharedPreferences.
 * - Exposes beginSaveCredential / beginGetCredential flows guarded by BiometricPrompt.
 *
 * Public API and native callback signatures are kept intact.
 */
public final class SecureAndroidAuthentication {

    // ====== Logging ======
    private static final String TAG = "SecureAndroidAuthentication";

    // ====== Singleton ======
    private static SecureAndroidAuthentication sInst;

    public static synchronized SecureAndroidAuthentication getInstance(Context ctx) {
        if (sInst == null) sInst = new SecureAndroidAuthentication(ctx.getApplicationContext());
        return sInst;
    }

    // ====== Ctor / fields ======
    private final Context mContext;           // application context (safe to keep)
    @SuppressWarnings("FieldCanBeLocal")
    private final Activity mActivityInstance = null; // kept for source compatibility (unused)
    private final Executor mExecutor = Executors.newSingleThreadExecutor();

    // Prompt configuration (non-empty defaults to avoid framework exceptions on API 28)
    private int mAppAuthMask = 0;                   // 1=STRONG, 2=WEAK, 4=DEVICE_CREDENTIAL (from C++)
    private String mTitle = "Authenticate";
    private String mDescription = "";
    private String mNegative = "Cancel";

    // In-flight prompt
    private CancellationSignal mCancel;

    // Pending operation bookkeeping
    private enum PendingType { NONE, SAVE, GET }
    private PendingType pending = PendingType.NONE;
    private String pendingAccount;
    private String pendingPlain;     // for SAVE
    private byte[] pendingIV;        // for SAVE/GET

    private SecureAndroidAuthentication(Context ctx) {
        this.mContext = ctx;
    }

    // ====== Public API called from Qt (unchanged signatures) ======

    public void setAuthenticators(int mask) {
        mAppAuthMask = mask;
    }
    public void setTitle(String title) {
        mTitle = (title != null && !title.trim().isEmpty()) ? title : "Authenticate";
    }
    public void setDescription(String description) {
        mDescription = (description != null) ? description : "";
    }
    public void setNegativeButton(String negativeButton) {
        mNegative = (negativeButton != null && !negativeButton.trim().isEmpty()) ? negativeButton : "Cancel";
    }

    /** Cancel current biometric request, if any. */
    public void cancel() {
        if (mCancel != null && !mCancel.isCanceled()) mCancel.cancel();
        mCancel = null;
    }

    /** Capability check — returns your BIOMETRIC_* codes. */
    public int canAuthenticate() {
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                BiometricManager bm = mContext.getSystemService(BiometricManager.class);
                if (bm == null) return BIOMETRIC_ERROR_NO_HARDWARE;
                final int allowed = toFrameworkAllowedMask();
                switch (bm.canAuthenticate(allowed)) {
                    case BiometricManager.BIOMETRIC_SUCCESS: return BIOMETRIC_SUCCESS;
                    case BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE: return BIOMETRIC_ERROR_NO_HARDWARE;
                    case BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE: return BIOMETRIC_ERROR_HW_UNAVAILABLE;
                    case BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED: return BIOMETRIC_ERROR_NONE_ENROLLED;
                    case BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED: return BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED;
                    default: return BIOMETRIC_STATUS_UNKNOWN;
                }
            } else if (Build.VERSION.SDK_INT >= 29) {
                BiometricManager bm = mContext.getSystemService(BiometricManager.class);
                if (bm == null) return BIOMETRIC_ERROR_NO_HARDWARE;
                switch (bm.canAuthenticate()) { // flags overload not available on 29
                    case BiometricManager.BIOMETRIC_SUCCESS: return BIOMETRIC_SUCCESS;
                    case BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE: return BIOMETRIC_ERROR_NO_HARDWARE;
                    case BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE: return BIOMETRIC_ERROR_HW_UNAVAILABLE;
                    case BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED: return BIOMETRIC_ERROR_NONE_ENROLLED;
                    default: return BIOMETRIC_STATUS_UNKNOWN;
                }
            } else {
                // API 23–28: fingerprint-only exposure
                FingerprintManager fm = mContext.getSystemService(FingerprintManager.class);
                if (fm == null || !fm.isHardwareDetected()) return BIOMETRIC_ERROR_NO_HARDWARE;
                if (!fm.hasEnrolledFingerprints()) return BIOMETRIC_ERROR_NONE_ENROLLED;
                return BIOMETRIC_SUCCESS;
            }
        } catch (Throwable t) {
            Log.w(TAG, "canAuthenticate error", t);
            return BIOMETRIC_STATUS_UNKNOWN;
        }
    }

    /** Start SAVE flow (encrypt & persist). */
    public boolean beginSaveCredential(String account, String password) {
        if (Build.VERSION.SDK_INT < 28) { nativeCredentialError(-10, "BiometricPrompt requires API 28"); return false; }
        try {
            Cipher enc;
            try {
                enc = newEncryptCipher();
            } catch (KeyPermanentlyInvalidatedException e) {
                // Biometric enrollment changed: the old key (and everything it encrypted) is
                // permanently dead. For a SAVE that is recoverable — wipe the dead state and
                // encrypt the new credential under a freshly generated key.
                Log.w(TAG, "beginSave: key invalidated by enrollment change, regenerating", e);
                if (!handleInvalidatedKey()) {
                    // Inconsistent cleanup would leave stale ciphertext under a new key;
                    // the invalidated alias is untouched, so the next attempt retries.
                    nativeCredentialError(-1, "beginSave: invalidated-key cleanup failed");
                    return false;
                }
                enc = newEncryptCipher();
            }
            pending = PendingType.SAVE;
            pendingAccount = account;
            pendingPlain = password;
            pendingIV = enc.getIV();

            mCancel = new CancellationSignal();
            BiometricPrompt prompt = buildPrompt((d, which) -> {
                if (mCancel != null) mCancel.cancel();
                nativeCredentialError(-11, "User cancelled");
            });
            prompt.authenticate(new BiometricPrompt.CryptoObject(enc), mCancel, mExecutor, new Callback());
            return true;
        } catch (Exception e) {
            nativeCredentialError(-1, "beginSave: " + e.getMessage());
            return false;
        }
    }

    /** Start GET flow (decrypt & return). */
    public boolean beginGetCredential(String account) {
        if (Build.VERSION.SDK_INT < 28) { nativeCredentialError(-10, "BiometricPrompt requires API 28"); return false; }
        try {
            byte[] iv = loadIV(account);
            byte[] ct = loadCT(account);
            if (iv == null || ct == null) { nativeCredentialLoaded(account, null); return true; }

            Cipher dec;
            try {
                dec = newDecryptCipher(iv);
            } catch (KeyPermanentlyInvalidatedException e) {
                // Biometric enrollment changed: the stored ciphertext is permanently
                // unreadable. Wipe the dead key and blobs so hasCredential() stops lying,
                // and report the credential as gone (callers fall back to password entry
                // and can re-enable biometrics, which generates a fresh key).
                Log.w(TAG, "beginGet: key invalidated by enrollment change, wiping stored credentials", e);
                if (!handleInvalidatedKey()) {
                    // State is unchanged (alias intact): the next attempt re-triggers the
                    // invalidation and retries the cleanup. Report a plain error, not
                    // not-found — the blobs are still there.
                    nativeCredentialError(-2, "beginGet: invalidated-key cleanup failed");
                    return false;
                }
                nativeCredentialError(-12, "Key invalidated by biometric enrollment change");
                return false;
            }
            pending = PendingType.GET;
            pendingAccount = account;
            pendingPlain = null;
            pendingIV = iv;

            mCancel = new CancellationSignal();
            BiometricPrompt prompt = buildPrompt((d, which) -> {
                if (mCancel != null) mCancel.cancel();
                nativeCredentialError(-11, "User cancelled");
            });
            prompt.authenticate(new BiometricPrompt.CryptoObject(dec), mCancel, mExecutor, new Callback());
            return true;
        } catch (Exception e) {
            nativeCredentialError(-2, "beginGet: " + e.getMessage());
            return false;
        }
    }

    /** Remove stored blob for an account. */
    public boolean deleteCredential(String account) {
        return prefs().edit()
                .remove(KEY_IV_PREFIX + account)
                .remove(KEY_CT_PREFIX + account)
                .commit();
    }

    /** Check presence-at-rest (no prompt). */
    public boolean hasCredential(String account) {
        return prefs().contains(KEY_IV_PREFIX + account) && prefs().contains(KEY_CT_PREFIX + account);
    }

    // ====== Prompt building ======

    private BiometricPrompt buildPrompt(DialogInterface.OnClickListener onNeg) {
        // Framework Builder accepts any Context (no need for Activity)
        BiometricPrompt.Builder b = new BiometricPrompt.Builder(mContext)
                .setTitle((mTitle == null || mTitle.trim().isEmpty()) ? "Authenticate" : mTitle)
                .setDescription(mDescription == null ? "" : mDescription);

        // On API 29 you *could* use device credential instead of a negative; keeping negative for consistency
        b.setNegativeButton((mNegative == null || mNegative.trim().isEmpty()) ? "Cancel" : mNegative,
                mExecutor, onNeg);

        return b.build();
    }

    // ====== Keystore helpers ======

    private static final String KC_ALIAS = "QtAT_Keychain_AES";
    private static final String PREFS_NAME = "QtAT_Keychain";
    private static final String KEY_CT_PREFIX = "ct_"; // ciphertext
    private static final String KEY_IV_PREFIX = "iv_"; // iv

    private SecretKey ensureKey() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        if (!ks.containsAlias(KC_ALIAS)) {
            KeyGenParameterSpec spec = new KeyGenParameterSpec.Builder(
                    KC_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setUserAuthenticationRequired(true)
                    // Keep this behavior for compatibility (key invalidated on enroll changes)
                    .setInvalidatedByBiometricEnrollment(true)
                    .build();
            KeyGenerator kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            kg.init(spec);
            kg.generateKey();
        }
        KeyStore.SecretKeyEntry e = (KeyStore.SecretKeyEntry) ks.getEntry(KC_ALIAS, null);
        return e.getSecretKey();
    }

    /**
     * Removes every stored blob and then the invalidated AES key. All accounts share the
     * one key, so after an enrollment change every ciphertext is undecryptable dead data.
     *
     * Order matters: the blobs are cleared first (synchronously, result checked), because
     * if the alias were deleted first and the process stopped before the prefs write, the
     * next use would silently generate a fresh key and the leftover ciphertext would turn
     * into permanent ghost entries — hasCredential() true, decryption always failing.
     *
     * @return true when the state is consistent again (blobs verifiably gone). Alias
     *         removal afterwards is best-effort: with the blobs gone no ghosts are
     *         possible, and a surviving invalidated alias merely re-triggers this cleanup
     *         on the next use.
     */
    private boolean handleInvalidatedKey() {
        // The prefs file holds nothing but our iv_/ct_ blobs — clear it entirely.
        if (!prefs().edit().clear().commit()) {
            Log.w(TAG, "handleInvalidatedKey: failed to clear credential blobs");
            return false;
        }
        try {
            KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
            ks.load(null);
            if (ks.containsAlias(KC_ALIAS)) ks.deleteEntry(KC_ALIAS);
        } catch (Exception e) {
            Log.w(TAG, "handleInvalidatedKey: failed to delete key alias", e);
        }
        return true;
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

    private void storeBytes(String account, byte[] iv, byte[] ct) {
        prefs().edit()
                .putString(KEY_IV_PREFIX + account, Base64.encodeToString(iv, Base64.NO_WRAP))
                .putString(KEY_CT_PREFIX + account, Base64.encodeToString(ct, Base64.NO_WRAP))
                .apply();
    }

    private byte[] loadIV(String account) {
        String b64 = prefs().getString(KEY_IV_PREFIX + account, null);
        return b64 == null ? null : Base64.decode(b64, Base64.NO_WRAP);
    }

    private byte[] loadCT(String account) {
        String b64 = prefs().getString(KEY_CT_PREFIX + account, null);
        return b64 == null ? null : Base64.decode(b64, Base64.NO_WRAP);
    }

    // ====== Biometric callback ======

    private final class Callback extends BiometricPrompt.AuthenticationCallback {
        @Override public void onAuthenticationError(int code, CharSequence err) {
            try {
                nativeCredentialError(code, String.valueOf(err));
            } finally {
                clearPending();
            }
        }

        @Override public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) {
            try {
                if (pending == PendingType.SAVE) {
                    // Encrypt path already performed; just persist ct + iv
                    Cipher enc = result.getCryptoObject().getCipher();
                    byte[] ct = enc.doFinal(pendingPlain.getBytes(StandardCharsets.UTF_8));
                    storeBytes(pendingAccount, pendingIV, ct);
                    nativeCredentialSaved(true);
                } else if (pending == PendingType.GET) {
                    byte[] ct = loadCT(pendingAccount);
                    Cipher dec = result.getCryptoObject().getCipher();
                    String plain = new String(dec.doFinal(ct), StandardCharsets.UTF_8);
                    nativeCredentialLoaded(pendingAccount, plain);
                } else {
                    nativeCredentialError(-3, "No pending op");
                }
            } catch (Exception e) {
                nativeCredentialError(-4, "onSucceeded: " + e.getMessage());
            } finally {
                clearPending();
            }
        }

        @Override public void onAuthenticationFailed() {
            // Called when a biometric (e.g., fingerprint) is recognized but not matched
            // Do nothing special; the system keeps listening. We only report terminal results.
        }
    }

    private void clearPending() {
        pending = PendingType.NONE;
        pendingAccount = null;
        pendingPlain = null;
        pendingIV = null;
        mCancel = null;
    }

    // ====== App-mask -> framework-mask mapping (API 30+) ======
    // C++ sends: 1=STRONG, 2=WEAK, 4=DEVICE_CREDENTIAL
    private int toFrameworkAllowedMask() {
        if (Build.VERSION.SDK_INT < 30) return 0;
        int fw = 0;
        if ((mAppAuthMask & 0x01) != 0)
            fw |= BiometricManager.Authenticators.BIOMETRIC_STRONG;
        if ((mAppAuthMask & 0x02) != 0)
            fw |= BiometricManager.Authenticators.BIOMETRIC_WEAK;
        if ((mAppAuthMask & 0x04) != 0)
            fw |= BiometricManager.Authenticators.DEVICE_CREDENTIAL;

        if (fw == 0) {
            fw = BiometricManager.Authenticators.BIOMETRIC_STRONG
               | BiometricManager.Authenticators.DEVICE_CREDENTIAL;
        }
        return fw;
    }

    // ====== Native callbacks (kept static) ======
    private static native void nativeCredentialSaved(boolean ok);
    private static native void nativeCredentialLoaded(String account, String secret);
    private static native void nativeCredentialError(int code, String message);

    // ====== Result/status constants (kept as-is) ======
    private final int BIOMETRIC_STRONG = 0x01;
    private final int BIOMETRIC_WEAK = 0x02;
    private final int DEVICE_CREDENTIAL = 0x04;

    private final int BIOMETRIC_STATUS_UNKNOWN = 0;
    private final int BIOMETRIC_SUCCESS = 1;
    private final int BIOMETRIC_ERROR_NO_HARDWARE = 2;
    private final int BIOMETRIC_ERROR_HW_UNAVAILABLE = 3;
    private final int BIOMETRIC_ERROR_NONE_ENROLLED = 4;
    private final int BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED = 5;
}
