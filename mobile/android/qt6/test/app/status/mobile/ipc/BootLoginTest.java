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
    private final Map<String, String> responses = new HashMap<>();
    private boolean uiVisible;
    private boolean uiBound;
    private final List<Call> calls = new ArrayList<>();
    private int pauses;
    private BootLogin.Condition pauseCondition;
    private int recordDeletes;
    private int stops;
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
        responses.clear();
        uiVisible = false;
        uiBound = false;
        calls.clear();
        pauses = 0;
        pauseCondition = null;
        recordDeletes = 0;
        stops = 0;
        notifications = 0;
        scheduled = null;
        scheduledDelayMs = -1;
        bootLogin = newBootLogin(true);
    }

    private BootLogin newBootLogin(boolean enabled) {
        return new BootLogin(
                enabled,
                new BootLogin.RecordStore() {
                    @Override
                    public boolean exists() {
                        return store.containsKey(RECORD_KEY);
                    }

                    @Override
                    public String read() throws BootLogin.StoreException {
                        if (recordUnreadable) throw new BootLogin.StoreException();
                        return store.get(RECORD_KEY);
                    }

                    @Override
                    public void delete() {
                        recordDeletes++;
public void delete() {
                        store.remove(RECORD_KEY);
                    }
                },
                keyUid -> {
                    if (credentialUnreadable) throw new BootLogin.StoreException();
                    return store.get(keyUid);
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
                () -> stops++,
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
                });
    }

    private void assertFailedOnce() {
        assertNull("boot-login record deleted", store.get(RECORD_KEY));
        assertEquals("credential untouched", CREDENTIAL, store.get(KEY_UID));
        assertEquals(1, stops);
        assertEquals(1, notifications);
        assertNull("no timeout left pending", scheduled);
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
    public void waitsForNodeLoginWithATimeout() {
        bootLogin.run();

        assertEquals(BootLogin.LOGIN_TIMEOUT_MS, scheduledDelayMs);
        assertEquals(60_000L, BootLogin.LOGIN_TIMEOUT_MS);
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
    public void noNodeLoginBeforeTheTimeoutFails() {
        bootLogin.run();
        final Runnable timeout = scheduled;

        timeout.run();

        scheduled = null;
        assertFailedOnce();
    }

    @Test
    public void lateNodeLoginAfterTheTimeoutDoesNotNotifyAgain() {
        bootLogin.run();
        final Runnable timeout = scheduled;
        timeout.run();

        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);
        timeout.run();

        scheduled = null;
        assertFailedOnce();
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

    private BootLogin.RecordStore storedRecord() {
        return new BootLogin.RecordStore() {
            @Override
            public boolean exists() throws BootLogin.StoreException {
                if (recordUnreadable) throw new BootLogin.StoreException();
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
}
