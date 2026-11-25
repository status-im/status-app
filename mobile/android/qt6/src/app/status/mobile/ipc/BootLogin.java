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
 * <p>A failed boot login deletes the record, stops the service unless a UI is bound and posts
 * one notification unless a UI is visible. There is no retry, and this class never deletes the
 * "Stay logged in" credential (the store itself may wipe one it cannot decrypt).
 *
 * <p>It also owns the pause rule: logged in with no visible UI means paused, the same state
 * as a backgrounded app (messaging stays on).
 */
final class BootLogin {
    private static final String DEK_PREFIX = "dek:";
    private static final int DEK_HEX_LENGTH = 64;

    /**
     * How long a boot login waits for node.login after LoginAccount. LoginAccount includes
     * opening the database, so the first boot login after an app update runs the migrations,
     * which can take minutes on a low-end device with a large database.
     */
    static final long LOGIN_TIMEOUT_MS = 5 * 60_000L;

    /** The secure store cannot give the entry: a backend error, or a corrupt entry. */
    static final class StoreException extends Exception {
        /** True for a corrupt entry (an incomplete blob pair), false for a store error. */
        final boolean corrupt;

        StoreException(boolean corrupt) {
            this.corrupt = corrupt;
        }
    }

    interface RecordStore {
        /** Whether the record is stored, checked without decrypting it. */
        boolean exists() throws StoreException;

        /** The boot-login record JSON, or null when there is none. */
        String read() throws StoreException;

        void delete();
    }

    /** The prompt-free secure store's presence checks for one entry. */
    interface EntryStore {
        /** Whether only one half of the entry's {iv, ct} pair is stored. Read-only. */
        boolean hasIncompletePair(String account);

        /** Whether the entry is stored; wipes a corrupt entry and reports it absent. */
        boolean exists(String account) throws StoreException;
    }

    /**
     * Presence at rest. The store's own check wipes a half {iv, ct} pair and reports it absent,
     * so a half pair is checked first and reported as corrupt.
     */
    static boolean entryExists(EntryStore store, String account) throws StoreException {
        if (store.hasIncompletePair(account)) throw new StoreException(true);
        return store.exists(account);
    }

    interface CredentialSource {
        /** Whether the credential is stored, checked without decrypting it. */
        boolean exists(String keyUid) throws StoreException;

        /** The account's "Stay logged in" credential, or null when there is none. */
        String credential(String keyUid) throws StoreException;
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

        /** Stops the service and ends its process, as ACTION_STOP does. */
        void endProcess();
    }

    interface Notifier {
        void bootLoginFailed();
    }

    interface Scheduler {
        void schedule(Runnable task, long delayMs);

        void cancel(Runnable task);
    }

    interface Logger {
        void warn(String message);
    }

    private final boolean enabled;
    private final RecordStore records;
    private final CredentialSource credentials;
    private final StatusGo statusGo;
    private final Pauser pauser;
    private final Ui ui;
    private final Stopper stopper;
    private final Notifier notifier;
    private final Scheduler scheduler;
    private final Logger log;

    private final Object lock = new Object();
    /** A boot login sent LoginAccount and its node.login has not arrived yet. */
    private boolean awaitingNodeLogin;
    private final Runnable loginTimeout = () -> {
        if (takeAwaitingNodeLogin()) timedOut();
    };

    BootLogin(boolean enabled, RecordStore records, CredentialSource credentials, StatusGo statusGo, Pauser pauser,
            Ui ui, Stopper stopper, Notifier notifier, Scheduler scheduler, Logger log) {
        this.enabled = enabled;
        this.records = records;
        this.credentials = credentials;
        this.statusGo = statusGo;
        this.pauser = pauser;
        this.ui = ui;
        this.stopper = stopper;
        this.notifier = notifier;
        this.scheduler = scheduler;
        this.log = log;
    }

    /**
     * BOOT_COMPLETED: whether to start the service for a boot login. Without a record nothing
     * starts; with the feature off (RESUME_AFTER_RESTART_ENABLED) any record is removed.
     * A corrupt record (an incomplete blob pair) starts it too, so the failure path deletes
     * the record and notifies instead of the boot doing nothing.
     */
    static boolean startsOnBoot(boolean enabled, RecordStore records) {
        boolean stored;
        try {
            stored = records.exists();
        } catch (StoreException e) {
            stored = e.corrupt;
        }
        if (!stored) return false;
        if (!enabled) {
            records.delete();
            return false;
        }
        return true;
    }

    /**
     * Whether a service start runs the boot login: the boot action, or the system recreating
     * the service (START_STICKY, null intent) with no UI bound to log in again. With the
     * feature off a system restart leaves an idle foreground service, as before boot login.
     */
    static boolean runsOnStart(boolean enabled, boolean bootAction, boolean stickyRestart, boolean uiBound) {
        return bootAction || (enabled && stickyRestart && !uiBound);
    }

    /**
     * Replays the boot-login record. Returns true when status-go accepted the login request;
     * the outcome arrives later as node.login. With nothing to replay, the service stops unless
     * a UI is bound.
     */
    boolean run() {
        if (!enabled) {
            records.delete();
            stopUnlessUiBound();
            return false;
        }
        // The store wipes an entry it cannot decrypt and then reports it absent, so whether
        // there was anything to replay is decided before decrypting.
        final String recordJson;
        try {
            if (!records.exists()) {
                stopUnlessUiBound();
                return false;
            }
            recordJson = records.read();
        } catch (StoreException e) {
            fail("record " + describe(e));
            return false;
        }
        if (recordJson == null) {
            fail("record undecryptable (the store wiped it)");
            return false;
        }

        final JSONObject record = parse(recordJson);
        final String keyUid = record == null ? "" : record.optString("keyUid", "");
        final JSONObject initRequest = record == null ? null : record.optJSONObject("initRequest");
        final JSONObject loginRequest = record == null ? null : record.optJSONObject("loginRequest");
        if (keyUid.isEmpty() || initRequest == null || loginRequest == null) {
            fail("corrupt record");
            return false;
        }

        final String credential;
        try {
            if (!credentials.exists(keyUid)) {
                stopUnlessUiBound();
                return false;
            }
            credential = credentials.credential(keyUid);
        } catch (StoreException e) {
            fail("credential " + describe(e));
            return false;
        }
        if (credential == null) {
            fail("credential undecryptable (the store wiped it)");
            return false;
        }
        final String dek = dekFrom(credential);
        if (dek == null) {
            stopUnlessUiBound();
            return false;
        }

        if (!succeeded(statusGo.call("InitializeApplication", args(initRequest.toString())))) {
            fail("InitializeApplication rejected");
            return false;
        }
        try {
            loginRequest.put("dek", dek);
        } catch (Exception e) {
            fail("cannot add the DEK to the login request");
            return false;
        }

        synchronized (lock) {
            awaitingNodeLogin = true;
        }
        scheduler.schedule(loginTimeout, LOGIN_TIMEOUT_MS);
        if (!succeeded(statusGo.call("LoginAccount", args(loginRequest.toString())))) {
            if (takeAwaitingNodeLogin()) fail("LoginAccount rejected");
            return false;
        }
        return true;
    }

    /**
     * For every node.login: ends a pending boot login (an error fails it), then applies the
     * pause rule: logged in with no visible UI means paused.
     */
    void onNodeLogin(String signalJson) {
        final JSONObject signal = parse(signalJson);
        final JSONObject event = signal == null ? null : signal.optJSONObject("event");
        final boolean loggedIn = event != null && event.optString("error", "").isEmpty();
        if (takeAwaitingNodeLogin() && !loggedIn) {
            fail("node.login error");
            return;
        }
        if (loggedIn && !ui.visible()) pauser.pauseServices(() -> !ui.visible());
    }

    /** Clears the pending boot login; true when there was one. */
    private boolean takeAwaitingNodeLogin() {
        synchronized (lock) {
            if (!awaitingNodeLogin) return false;
            awaitingNodeLogin = false;
        }
        scheduler.cancel(loginTimeout);
        return true;
    }

    private void fail(String reason) {
        log.warn("boot login failed: " + reason);
        records.delete();
        if (!ui.visible()) notifier.bootLoginFailed();
        stopUnlessUiBound();
    }

    /**
     * No node.login in time. status-go may still finish the login inside this process, so
     * with no UI the process ends rather than live on half logged in behind the failure
     * notification. A bound UI gets the late node.login and handles it.
     */
    private void timedOut() {
        log.warn("boot login failed: no node.login within " + LOGIN_TIMEOUT_MS + " ms");
        records.delete();
        if (ui.bound()) return;
        notifier.bootLoginFailed();
        stopper.endProcess();
    }

    private static String describe(StoreException e) {
        return e.corrupt ? "undecryptable (incomplete blob pair)" : "store error";
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
