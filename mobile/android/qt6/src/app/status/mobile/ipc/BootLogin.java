package app.status.mobile.ipc;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Boot login: after a phone restart the service process logs the last-used profile in by
 * itself, so notifications resume without opening the app.
 *
 * <p>The UI writes the boot-login record (the init and login requests of its last login with
 * "Stay logged in" on, without the DEK). This class only replays it: it adds the DEK from the
 * prompt-free secure store and calls status-go's InitializeApplication and LoginAccount. It
 * never builds a login request itself.
 *
 * <p>It also owns the pause rule: logged in with no visible UI means paused, the same state
 * as a backgrounded app (messaging stays on).
 */
final class BootLogin {
    private static final String DEK_PREFIX = "dek:";
    private static final int DEK_HEX_LENGTH = 64;

    interface RecordStore {
        /** The boot-login record JSON, or null when there is none. */
        String read();

        /** Whether a record is stored, without decrypting it. */
        boolean exists();

        void delete();
    }

    interface CredentialSource {
        /** The account's "Stay logged in" credential, or null when there is none. */
        String credential(String keyUid);
    }

    interface StatusGo {
        /** Calls status-go with a JSON array of string arguments; returns its response. */
        String call(String method, String argsJson);
    }

    interface Condition {
        boolean holds();
    }

    interface Pauser {
        /** Pauses the services unless stillHidden no longer holds when the pause runs. */
        void pauseServices(Condition stillHidden);
    }

    interface Ui {
        boolean visible();

        boolean bound();
    }

    interface Stopper {
        void stop();
    }

    interface Notifier {
        void bootLoginFailed();
    }

    private final boolean enabled;
    private final RecordStore records;
    private final CredentialSource credentials;
    private final StatusGo statusGo;
    private final Pauser pauser;
    private final Ui ui;
    private final Stopper stopper;
    @SuppressWarnings("unused")
    private final Notifier notifier;
    // The login request was accepted: the next node.login is the boot login's outcome
    private volatile boolean awaitingNodeLogin;

    BootLogin(boolean enabled, RecordStore records, CredentialSource credentials, StatusGo statusGo, Pauser pauser,
            Ui ui, Stopper stopper, Notifier notifier) {
        this.enabled = enabled;
        this.records = records;
        this.credentials = credentials;
        this.statusGo = statusGo;
        this.pauser = pauser;
        this.ui = ui;
        this.stopper = stopper;
        this.notifier = notifier;
    }

    /**
     * BOOT_COMPLETED: whether to start the service for a boot login. Without a record nothing
     * starts; with the feature off (RESUME_AFTER_RESTART_ENABLED) any record is removed.
     */
    static boolean startsOnBoot(boolean enabled, RecordStore records) {
        if (!records.exists()) return false;
        if (!enabled) {
            records.delete();
            return false;
        }
        return true;
    }

    /**
     * Whether a service start runs the boot login: the boot action, or the system recreating
     * the service (START_STICKY, null intent) with no UI bound to log in again.
     */
    static boolean runsOnStart(boolean bootAction, boolean stickyRestart, boolean uiBound) {
        return bootAction || (stickyRestart && !uiBound);
    }

    /**
     * Replays the boot-login record. Returns true when status-go accepted the login request;
     * the outcome arrives later as node.login. With nothing to replay, or when the login fails,
     * the service stops unless a UI is bound.
     */
    boolean run() {
        if (!enabled) {
            records.delete();
            stopUnlessUiBound();
            return false;
        }
        final JSONObject record = parse(records.read());
        final String keyUid = record == null ? "" : record.optString("keyUid", "");
        final JSONObject initRequest = record == null ? null : record.optJSONObject("initRequest");
        final JSONObject loginRequest = record == null ? null : record.optJSONObject("loginRequest");
        final String dek = keyUid.isEmpty() ? null : dekFrom(credentials.credential(keyUid));
        if (initRequest == null || loginRequest == null || dek == null) {
            stopUnlessUiBound();
            return false;
        }

        if (!succeeded(statusGo.call("InitializeApplication", args(initRequest.toString())))) {
            stopUnlessUiBound();
            return false;
        }
        try {
            loginRequest.put("dek", dek);
        } catch (Exception e) {
            stopUnlessUiBound();
            return false;
        }
        awaitingNodeLogin = true;
        if (!succeeded(statusGo.call("LoginAccount", args(loginRequest.toString())))) {
            awaitingNodeLogin = false;
            stopUnlessUiBound();
            return false;
        }
        return true;
    }

    /**
     * For every node.login. The pause rule: logged in with no visible UI means paused. A failed
     * boot login stops the service unless a UI is bound.
     */
    void onNodeLogin(String signalJson) {
        final boolean bootLoginOutcome = awaitingNodeLogin;
        awaitingNodeLogin = false;
        final JSONObject signal = parse(signalJson);
        final JSONObject event = signal == null ? null : signal.optJSONObject("event");
        if (event == null || !event.optString("error", "").isEmpty()) {
            if (bootLoginOutcome) stopUnlessUiBound();
            return;
        }
        if (!ui.visible()) pauser.pauseServices(() -> !ui.visible());
    }

    private void stopUnlessUiBound() {
        if (!ui.bound()) stopper.stop();
    }

    private static String dekFrom(String credential) {
        if (credential == null || !credential.startsWith(DEK_PREFIX)) return null;
        final String hex = credential.substring(DEK_PREFIX.length());
        if (hex.length() != DEK_HEX_LENGTH) return null;
        for (int i = 0; i < hex.length(); i++) {
            final char c = hex.charAt(i);
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return null;
        }
        return hex;
    }

    private static JSONObject parse(String json) {
        if (json == null || json.isEmpty()) return null;
        try {
            return new JSONObject(json);
        } catch (Exception e) {
            return null;
        }
    }

    private static String args(String singleArg) {
        return new JSONArray().put(singleArg).toString();
    }

    private static boolean succeeded(String response) {
        final JSONObject parsed = parse(response);
        return parsed != null && parsed.optString("error", "").isEmpty();
    }
}
