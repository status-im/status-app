package app.status.mobile.ipc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;

public class BootLoginTest {
    private static final String KEY_UID = "0xkeyuid";
    private static final String RECORD_KEY = "status.bootLoginRecord";
    private static final String ATTEMPT_KEY = "status.bootLoginAttempt";
    private static final String DEK_HEX = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    private static final String CREDENTIAL = "dek:" + DEK_HEX;
    private static final String RECORD = "{\"version\":1,\"keyUid\":\"" + KEY_UID + "\","
            + "\"versionCode\":42,"
            + "\"initRequest\":{\"dataDir\":\"/data/status\",\"logEnabled\":true},"
            + "\"loginRequest\":{\"keyUid\":\"" + KEY_UID + "\",\"kdfIterations\":3200,"
            + "\"walletConnectProjectID\":\"wc-id\"}}";
    private static final String NODE_LOGIN_OK =
            "{\"type\":\"node.login\",\"event\":{\"error\":\"\",\"account\":{}}}";
    private static final String NODE_LOGIN_FAILED =
            "{\"type\":\"node.login\",\"event\":{\"error\":\"wrong dek\"}}";
    private static final String OK = "{\"error\":\"\"}";

    private static final class Call {
        final String method;
        final String argsJson;

        Call(String method, String argsJson) {
            this.method = method;
            this.argsJson = argsJson;
        }

        JSONObject singleArg() throws Exception {
            return new JSONObject(new JSONArray(argsJson).getString(0));
        }
    }

    /** The secure store: the record and the credential side by side, as on the device. */
    private final Map<String, String> store = new HashMap<>();
    private boolean recordUnreadable;
    private boolean credentialUnreadable;
    /** An undecryptable blob: the store wipes that one entry, then reports it absent. */
    private boolean recordBlobCorrupt;
    private boolean credentialBlobCorrupt;
    /** The store key is invalidated: the first decrypt wipes every entry (wipeAll). */
    private boolean keyInvalidated;
    /** Only one half of the {iv, ct} pair is stored. */
    private boolean recordHalfPair;
    private boolean credentialHalfPair;
    private boolean recordWriteFails;
    private final List<String> logs = new ArrayList<>();
    private final Map<String, String> responses = new HashMap<>();
    private boolean uiVisible;
    private boolean uiBound;
    private final List<Call> calls = new ArrayList<>();
    private int pauses;
    private BootLogin.Condition pauseCondition;
    private int recordDeletes;
    private int stops;
    private int processEnds;
    private int notifications;
    private Runnable scheduled;
    private long scheduledDelayMs;
    private BootLogin bootLogin;

    @Before
    public void setUp() {
        store.clear();
        store.put(RECORD_KEY, RECORD);
        store.put(KEY_UID, CREDENTIAL);
        recordUnreadable = false;
        credentialUnreadable = false;
        recordBlobCorrupt = false;
        credentialBlobCorrupt = false;
        keyInvalidated = false;
        recordHalfPair = false;
        credentialHalfPair = false;
        recordWriteFails = false;
        logs.clear();
        responses.clear();
        uiVisible = false;
        uiBound = false;
        calls.clear();
        pauses = 0;
        pauseCondition = null;
        recordDeletes = 0;
        stops = 0;
        processEnds = 0;
        notifications = 0;
        scheduled = null;
        scheduledDelayMs = -1;
        bootLogin = newBootLogin(true);
    }

    /** The boot-login record in the secure store, as on the device. */
    private final BootLogin.RecordStore recordStore = new BootLogin.RecordStore() {
        @Override
        public boolean exists() throws BootLogin.StoreException {
            if (recordHalfPair) throw new BootLogin.StoreException(true);
            return store.containsKey(RECORD_KEY);
        }

        @Override
        public String read() throws BootLogin.StoreException {
            if (recordUnreadable) throw new BootLogin.StoreException(false);
            if (keyInvalidated) store.clear();
            if (recordBlobCorrupt) store.remove(RECORD_KEY);
            return store.get(RECORD_KEY);
        }

        @Override
        public void delete() {
            recordDeletes++;
            store.remove(RECORD_KEY);
        }

        @Override
        public boolean write(String recordJson) {
            if (recordWriteFails) return false;
            store.put(RECORD_KEY, recordJson);
            return true;
        }

        @Override
        public boolean attemptPending() {
            return store.containsKey(ATTEMPT_KEY);
        }

        @Override
        public void markAttempt() {
            store.put(ATTEMPT_KEY, "1");
        }

        @Override
        public void clearAttempt() {
            store.remove(ATTEMPT_KEY);
        }
    };

    private BootLogin newBootLogin(boolean enabled) {
        return new BootLogin(
                enabled,
                recordStore,
                new BootLogin.CredentialSource() {
                    @Override
                    public boolean exists(String keyUid) throws BootLogin.StoreException {
                        if (credentialHalfPair) throw new BootLogin.StoreException(true);
                        return store.containsKey(keyUid);
                    }

                    @Override
                    public String credential(String keyUid) throws BootLogin.StoreException {
                        if (credentialUnreadable) throw new BootLogin.StoreException(false);
                        if (credentialBlobCorrupt) store.remove(keyUid);
                        return store.get(keyUid);
                    }
                },
                (method, argsJson) -> {
                    calls.add(new Call(method, argsJson));
                    return responses.getOrDefault(method, OK);
                },
                stillHidden -> {
                    pauses++;
                    pauseCondition = stillHidden;
                },
                new BootLogin.Ui() {
                    @Override public boolean visible() { return uiVisible; }
                    @Override public boolean bound() { return uiBound; }
                },
                new BootLogin.Stopper() {
                    @Override public void stop() { stops++; }
                    @Override public void endProcess() { processEnds++; }
                },
                () -> notifications++,
                new BootLogin.Scheduler() {
                    @Override
                    public void schedule(Runnable task, long delayMs) {
                        scheduled = task;
                        scheduledDelayMs = delayMs;
                    }

                    @Override
                    public void cancel(Runnable task) {
                        if (scheduled == task) scheduled = null;
                    }
                },
                logs::add);
    }

    private void assertFailedOnce() {
        assertEquals("credential untouched", CREDENTIAL, store.get(KEY_UID));
        assertFailedOnceWhateverTheCredential();
    }

    private void assertFailedOnceWhateverTheCredential() {
        assertNull("boot-login record deleted", store.get(RECORD_KEY));
        assertEquals(1, stops);
        assertEquals(1, notifications);
        assertNull("no timeout left pending", scheduled);
    }

    private void assertTimedOutOnce() {
        assertNull("boot-login record deleted", store.get(RECORD_KEY));
        assertEquals("credential untouched", CREDENTIAL, store.get(KEY_UID));
        assertEquals(1, notifications);
        assertEquals(1, processEnds);
    }

    private void assertLoggedOnce(String phrase) {
        int n = 0;
        for (String line : logs) if (line.contains(phrase)) n++;
        assertEquals(logs.toString(), 1, n);
    }

    private void assertNothingToReplay() {
        assertEquals(0, notifications);
        assertEquals(1, stops);
        assertEquals(0, calls.size());
    }

    // ── Happy path ───────────────────────────────────────────────────────────

    @Test
    public void replaysTheRecordWithTheDekInjected() throws Exception {
        assertTrue(bootLogin.run());

        assertEquals(2, calls.size());
        assertEquals("InitializeApplication", calls.get(0).method);
        assertEquals("/data/status", calls.get(0).singleArg().getString("dataDir"));

        assertEquals("LoginAccount", calls.get(1).method);
        final JSONObject login = calls.get(1).singleArg();
        assertEquals(DEK_HEX, login.getString("dek"));
        assertEquals(KEY_UID, login.getString("keyUid"));
        assertEquals(3200, login.getInt("kdfIterations"));
        assertEquals("wc-id", login.getString("walletConnectProjectID"));
        assertEquals(0, stops);
    }

    @Test
    public void replaysARecordWrittenByAnOlderVersionAsIs() throws Exception {
        store.put(RECORD_KEY, RECORD.replace("\"versionCode\":42", "\"versionCode\":1"));

        assertTrue(bootLogin.run());

        assertEquals(2, calls.size());
        assertEquals("LoginAccount", calls.get(1).method);
        assertEquals(DEK_HEX, calls.get(1).singleArg().getString("dek"));
        assertTrue(store.containsKey(RECORD_KEY));
        assertEquals(0, notifications);
        assertEquals(0, stops);
    }

    @Test
    public void waitsForNodeLoginWithATimeout() {
        bootLogin.run();

        assertEquals(BootLogin.LOGIN_TIMEOUT_MS, scheduledDelayMs);
        assertEquals(5 * 60_000L, BootLogin.LOGIN_TIMEOUT_MS);
    }

    @Test
    public void successfulNodeLoginKeepsTheRecordAndCancelsTheTimeout() {
        bootLogin.run();

        bootLogin.onNodeLogin(NODE_LOGIN_OK);

        assertNull(scheduled);
        assertEquals(RECORD, store.get(RECORD_KEY));
        assertEquals(0, stops);
        assertEquals(0, notifications);
        assertEquals(1, pauses);
    }

    // ── Crash-loop guard: an attempt that never finished ─────────────────────

    /** The process dies (its timer with it); START_STICKY recreates the service. */
    private void dieAndRestart() {
        scheduled = null;
        calls.clear();
        bootLogin = newBootLogin(true);
    }

    @Test
    public void aBootLoginThatKilledTheProcessFailsTheNextReplayInsteadOfLooping() {
        bootLogin.run();
        dieAndRestart();

        assertFalse(bootLogin.run());

        assertEquals("no second login attempt", 0, calls.size());
        assertFailedOnce();
        assertFalse("attempt marker cleared", store.containsKey(ATTEMPT_KEY));
    }

    @Test
    public void aFinishedBootLoginLetsTheNextRestartReplayAgain() {
        bootLogin.run();
        bootLogin.onNodeLogin(NODE_LOGIN_OK);
        dieAndRestart();

        assertTrue(bootLogin.run());

        assertEquals(2, calls.size());
        assertEquals(0, notifications);
        assertEquals(RECORD, store.get(RECORD_KEY));
    }

    @Test
    public void aSecondTriggerWhileTheReplayRunsInThisProcessIsANoOp() {
        bootLogin.run();
        calls.clear();

        assertFalse(bootLogin.run());

        assertEquals("no second login attempt", 0, calls.size());
        assertEquals(0, notifications);
        assertEquals(0, recordDeletes);
        assertEquals(0, stops);
        assertTrue("first replay still pending", store.containsKey(ATTEMPT_KEY));

        bootLogin.onNodeLogin(NODE_LOGIN_OK);
        assertFalse(store.containsKey(ATTEMPT_KEY));
        assertEquals(RECORD, store.get(RECORD_KEY));
    }

    @Test
    public void aTriggerAfterTheReplayFailedInThisProcessReplaysAgain() {
        bootLogin.run();
        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);
        store.put(RECORD_KEY, RECORD);
        calls.clear();

        assertTrue(bootLogin.run());

        assertEquals(2, calls.size());
    }

    @Test
    public void aDeliberateStopDuringTheReplayIsNotACrash() {
        bootLogin.run();

        bootLogin.onStop();
        dieAndRestart();

        assertFalse(store.containsKey(ATTEMPT_KEY));
        assertTrue(bootLogin.run());
        assertEquals(0, notifications);
        assertEquals(RECORD, store.get(RECORD_KEY));
    }

    @Test
    public void aStopWithNoReplayInThisProcessKeepsALeftoverAttempt() {
        bootLogin.run();
        dieAndRestart();

        bootLogin.onStop();

        assertTrue(store.containsKey(ATTEMPT_KEY));
    }

    @Test
    public void aFailedNodeLoginClearsTheAttempt() {
        bootLogin.run();

        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertFalse(store.containsKey(ATTEMPT_KEY));
    }

    @Test
    public void aRejectedInitializeApplicationClearsTheAttempt() {
        responses.put("InitializeApplication", "{\"error\":\"bad\"}");

        bootLogin.run();

        assertFalse(store.containsKey(ATTEMPT_KEY));
    }

    @Test
    public void aTimedOutBootLoginClearsTheAttempt() {
        bootLogin.run();

        scheduled.run();

        assertTimedOutOnce();
        assertFalse(store.containsKey(ATTEMPT_KEY));
    }

    @Test
    public void aNewRecordWriteClearsAnUnfinishedAttempt() {
        bootLogin.run();
        dieAndRestart();

        assertTrue(BootLogin.writeRecord(recordStore, RECORD));

        assertTrue(bootLogin.run());
        assertEquals(0, notifications);
    }

    @Test
    public void aFailedRecordWriteKeepsTheAttempt() {
        bootLogin.run();
        recordWriteFails = true;

        assertFalse(BootLogin.writeRecord(recordStore, RECORD));

        assertTrue(store.containsKey(ATTEMPT_KEY));
    }

    // ── Nothing to replay: stop, no notification ─────────────────────────────

    @Test
    public void noRecordDoesNothingAndStops() {
        store.remove(RECORD_KEY);

        assertFalse(bootLogin.run());

        assertNothingToReplay();
    }

    @Test
    public void noCredentialDoesNothingAndStops() {
        store.remove(KEY_UID);

        assertFalse(bootLogin.run());

        assertNothingToReplay();
    }

    @Test
    public void credentialThatIsNotADekDoesNothing() {
        store.put(KEY_UID, "my password");

        assertFalse(bootLogin.run());

        assertNothingToReplay();
        assertEquals("my password", store.get(KEY_UID));
    }

    @Test
    public void recordFromAnOlderAppVersionIsReplayedNotFailed() {
        store.put(RECORD_KEY, RECORD.replace("\"versionCode\":42", "\"versionCode\":1"));

        assertTrue(bootLogin.run());

        assertEquals(0, notifications);
        assertEquals(0, stops);
    }

    @Test
    public void doesNotStopWhileAUiIsBound() {
        store.remove(RECORD_KEY);
        uiBound = true;

        assertFalse(bootLogin.run());

        assertEquals(0, stops);
    }

    // ── Failures: delete the record, stop, one notification ──────────────────

    @Test
    public void unreadableRecordFails() {
        store.put(RECORD_KEY, "{not json");

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertFailedOnce();
    }

    @Test
    public void recordMissingTheLoginRequestFails() {
        store.put(RECORD_KEY, "{\"version\":1,\"keyUid\":\"" + KEY_UID + "\",\"initRequest\":{}}");

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertFailedOnce();
    }

    @Test
    public void recordThatCannotBeDecryptedFails() {
        recordUnreadable = true;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertFailedOnce();
    }

    @Test
    public void credentialThatCannotBeDecryptedFails() {
        credentialUnreadable = true;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertFailedOnce();
    }

    @Test
    public void recordWipedAsUndecryptableFails() {
        recordBlobCorrupt = true;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertFailedOnce();
    }

    @Test
    public void credentialWipedAsUndecryptableFails() {
        credentialBlobCorrupt = true;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertNull("the store wiped the undecryptable credential", store.get(KEY_UID));
        assertFailedOnceWhateverTheCredential();
    }

    @Test
    public void invalidatedStoreKeyFailsAndTheStoreWipesTheCredentialToo() {
        keyInvalidated = true;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertNull("wipeAll took the credential with it", store.get(KEY_UID));
        assertFailedOnceWhateverTheCredential();
    }

    @Test
    public void halfRecordPairFails() {
        recordHalfPair = true;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertFailedOnce();
    }

    @Test
    public void halfCredentialPairFails() {
        credentialHalfPair = true;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertNull(store.get(RECORD_KEY));
        assertEquals(1, stops);
        assertEquals(1, notifications);
    }

    @Test
    public void storeErrorIsLoggedAsAStoreError() {
        recordUnreadable = true;

        bootLogin.run();

        assertLoggedOnce("store error");
        assertLoggedOnce("boot login failed");
    }

    @Test
    public void wipedEntryIsLoggedAsUndecryptable() {
        recordBlobCorrupt = true;

        bootLogin.run();

        assertLoggedOnce("undecryptable");
        assertEquals(0, countLogs("store error"));
    }

    @Test
    public void halfPairIsLoggedAsUndecryptable() {
        credentialHalfPair = true;

        bootLogin.run();

        assertLoggedOnce("undecryptable");
        assertEquals(0, countLogs("store error"));
    }

    private int countLogs(String phrase) {
        int n = 0;
        for (String line : logs) if (line.contains(phrase)) n++;
        return n;
    }

    @Test
    public void rejectedInitFailsAndSkipsTheLogin() {
        responses.put("InitializeApplication", "{\"error\":\"init failed\"}");

        assertFalse(bootLogin.run());

        assertEquals(1, calls.size());
        assertEquals("InitializeApplication", calls.get(0).method);
        assertFailedOnce();
    }

    @Test
    public void rejectedLoginFails() {
        responses.put("LoginAccount", "{\"error\":\"bad request\"}");

        assertFalse(bootLogin.run());

        assertEquals(2, calls.size());
        assertFailedOnce();
    }

    @Test
    public void unparsableStatusGoResponseFails() {
        responses.put("InitializeApplication", "not json");

        assertFalse(bootLogin.run());

        assertFailedOnce();
    }

    @Test
    public void nodeLoginWithAnErrorFails() {
        bootLogin.run();

        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertFailedOnce();
        assertEquals(0, pauses);
    }

    @Test
    public void timeoutWithNoUiDeletesTheRecordNotifiesAndEndsTheProcess() {
        bootLogin.run();
        final Runnable timeout = scheduled;

        timeout.run();

        assertTimedOutOnce();
    }

    @Test
    public void lateNodeLoginAfterTheTimeoutDoesNotNotifyAgain() {
        bootLogin.run();
        final Runnable timeout = scheduled;
        timeout.run();

        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);
        timeout.run();

        assertTimedOutOnce();
    }

    @Test
    public void timeoutWithAUiBoundNeitherEndsTheProcessNorNotifies() {
        uiBound = true;
        bootLogin.run();
        final Runnable timeout = scheduled;

        timeout.run();

        assertEquals(0, processEnds);
        assertEquals(0, stops);
        assertEquals(0, notifications);
        assertNull("boot-login record deleted", store.get(RECORD_KEY));
        assertEquals(CREDENTIAL, store.get(KEY_UID));
    }

    @Test
    public void lateSuccessAfterTheTimeoutWithAUiBoundIsLeftToTheUi() {
        uiBound = true;
        uiVisible = true;
        bootLogin.run();
        scheduled.run();

        bootLogin.onNodeLogin(NODE_LOGIN_OK);

        assertEquals(0, processEnds);
        assertEquals(0, stops);
        assertEquals(0, notifications);
        assertEquals(0, pauses);
    }

    @Test
    public void failureWhileAUiIsVisibleDoesNotNotify() {
        uiBound = true;
        uiVisible = true;
        responses.put("LoginAccount", "{\"error\":\"bad request\"}");

        bootLogin.run();

        assertEquals(0, notifications);
        assertEquals(0, stops);
        assertNull(store.get(RECORD_KEY));
    }

    @Test
    public void failureWhileAUiIsBoundDoesNotStop() {
        uiBound = true;
        responses.put("LoginAccount", "{\"error\":\"bad request\"}");

        bootLogin.run();

        assertEquals(0, stops);
        assertEquals(1, notifications);
        assertNull(store.get(RECORD_KEY));
    }

    @Test
    public void failedNodeLoginOutsideABootLoginIsIgnored() {
        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertEquals(0, notifications);
        assertEquals(0, stops);
        assertEquals(RECORD, store.get(RECORD_KEY));
    }

    // ── Pause rule ───────────────────────────────────────────────────────────

    @Test
    public void nodeLoginWithNoVisibleUiPauses() {
        bootLogin.onNodeLogin(NODE_LOGIN_OK);

        assertEquals(1, pauses);
    }

    @Test
    public void nodeLoginWithAVisibleUiDoesNotPause() {
        uiVisible = true;

        bootLogin.onNodeLogin(NODE_LOGIN_OK);

        assertEquals(0, pauses);
    }

    @Test
    public void failedNodeLoginDoesNotPause() {
        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertEquals(0, pauses);
    }

    // ── Feature flag and service starts ──────────────────────────────────────

    /** A record store for the start checks, which never write or mark an attempt. */
    private abstract static class StartCheckRecordStore implements BootLogin.RecordStore {
        @Override public boolean write(String recordJson) { return false; }
        @Override public boolean attemptPending() { return false; }
        @Override public void markAttempt() {}
        @Override public void clearAttempt() {}
    }

    private BootLogin.RecordStore storedRecord() {
        return new StartCheckRecordStore() {
            @Override
            public boolean exists() throws BootLogin.StoreException {
                if (recordHalfPair) throw new BootLogin.StoreException(true);
                if (recordUnreadable) throw new BootLogin.StoreException(false);
                return store.containsKey(RECORD_KEY);
            }

            @Override
            public String read() {
                return store.get(RECORD_KEY);
            }

            @Override
            public void delete() {
                recordDeletes++;
                store.remove(RECORD_KEY);
            }
        };
    }

    @Test
    public void pauseIsDroppedWhenTheUiBecomesVisibleBeforeItRuns() {
        bootLogin.onNodeLogin(NODE_LOGIN_OK);
        assertEquals(1, pauses);
        assertTrue(pauseCondition.holds());

        uiVisible = true;

        assertFalse(pauseCondition.holds());
    }

    @Test
    public void runsForTheBootActionAndForASystemRestartWithoutUi() {
        assertTrue(BootLogin.runsOnStart(true, true, false, false));
        assertTrue(BootLogin.runsOnStart(true, false, true, false));
        assertFalse(BootLogin.runsOnStart(true, false, true, true));
        assertFalse(BootLogin.runsOnStart(true, false, false, false));
    }

    @Test
    public void aSystemRestartWithTheFeatureOffKeepsTheServiceAsOnMaster() {
        assertFalse(BootLogin.runsOnStart(false, false, true, false));
        assertFalse(BootLogin.runsOnStart(false, false, true, true));
    }

    @Test
    public void featureOffRemovesTheRecordInsteadOfLoggingIn() {
        bootLogin = newBootLogin(false);

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertEquals(1, recordDeletes);
        assertEquals(1, stops);
        assertEquals(0, notifications);
    }

    @Test
    public void bootCompletedStartsTheServiceOnlyWithARecord() {
        assertTrue(BootLogin.startsOnBoot(true, storedRecord()));
        store.remove(RECORD_KEY);
        assertFalse(BootLogin.startsOnBoot(true, storedRecord()));
        assertEquals(0, recordDeletes);
    }

    @Test
    public void bootCompletedWithTheFeatureOffRemovesTheRecord() {
        assertFalse(BootLogin.startsOnBoot(false, storedRecord()));

        assertEquals(1, recordDeletes);
    }

    // ── Boot: whether BOOT_COMPLETED starts the boot login ───────────────────

    @Test
    public void bootWithNoRecordStartsNothing() {
        store.remove(RECORD_KEY);

        assertFalse(BootLogin.startsOnBoot(true, storedRecord()));
    }

    @Test
    public void bootWithARecordStartsTheBootLogin() {
        assertTrue(BootLogin.startsOnBoot(true, storedRecord()));
    }

    @Test
    public void bootWithAHalfRecordPairStartsTheBootLoginSoItCanFail() {
        recordHalfPair = true;

        assertTrue(BootLogin.startsOnBoot(true, storedRecord()));
        assertEquals(0, recordDeletes);
    }

    @Test
    public void bootWithAStoreErrorStartsNothing() {
        recordUnreadable = true;

        assertFalse(BootLogin.startsOnBoot(true, storedRecord()));
    }

    @Test
    public void bootWithAHalfRecordPairAndTheFeatureOffRemovesIt() {
        recordHalfPair = true;

        assertFalse(BootLogin.startsOnBoot(false, storedRecord()));
        assertEquals(1, recordDeletes);
    }

    // ── The store's presence check, as the receiver and the service run it ───

    /** A store like SecureStorageHelper: hasCredential wipes a half pair and reports it absent. */
    private final class HalfPairWipingStore implements BootLogin.EntryStore {
        boolean halfPair;
        boolean present;
        int wipes;

        @Override
        public boolean hasIncompletePair(String account) {
            return halfPair;
        }

        @Override
        public boolean exists(String account) {
            if (halfPair) {
                halfPair = false;
                wipes++;
                return false;
            }
            return present;
        }
    }

    private BootLogin.RecordStore recordIn(HalfPairWipingStore entries) {
        return new StartCheckRecordStore() {
            @Override
            public boolean exists() throws BootLogin.StoreException {
                return BootLogin.entryExists(entries, RECORD_KEY);
            }

            @Override
            public String read() {
                return null;
            }

            @Override
            public void delete() {
                recordDeletes++;
            }
        };
    }

    @Test
    public void bootWithAHalfRecordPairInTheStoreStartsTheBootLoginWithoutWipingIt() {
        final HalfPairWipingStore entries = new HalfPairWipingStore();
        entries.halfPair = true;

        assertTrue(BootLogin.startsOnBoot(true, recordIn(entries)));
        assertEquals("the half pair is left for the failure path", 0, entries.wipes);
    }

    @Test
    public void bootWithARecordInTheStoreStartsTheBootLogin() {
        final HalfPairWipingStore entries = new HalfPairWipingStore();
        entries.present = true;

        assertTrue(BootLogin.startsOnBoot(true, recordIn(entries)));
    }

    @Test
    public void bootWithNothingInTheStoreStartsNothing() {
        assertFalse(BootLogin.startsOnBoot(true, recordIn(new HalfPairWipingStore())));
    }
}
