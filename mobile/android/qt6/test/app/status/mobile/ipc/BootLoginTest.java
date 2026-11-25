package app.status.mobile.ipc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.ArrayList;
import java.util.List;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;

public class BootLoginTest {
    private static final String KEY_UID = "0xkeyuid";
    private static final String DEK_HEX = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    private static final String RECORD = "{\"version\":1,\"keyUid\":\"" + KEY_UID + "\","
            + "\"versionCode\":42,"
            + "\"initRequest\":{\"dataDir\":\"/data/status\",\"logEnabled\":true},"
            + "\"loginRequest\":{\"keyUid\":\"" + KEY_UID + "\",\"kdfIterations\":3200,"
            + "\"walletConnectProjectID\":\"wc-id\"}}";
    private static final String NODE_LOGIN_OK =
            "{\"type\":\"node.login\",\"event\":{\"error\":\"\",\"account\":{}}}";
    private static final String NODE_LOGIN_FAILED =
            "{\"type\":\"node.login\",\"event\":{\"error\":\"wrong dek\"}}";

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

    private String record;
    private String credential;
    private boolean uiVisible;
    private boolean uiBound;
    private String initResponse;
    private String loginResponse;
    private final List<Call> calls = new ArrayList<>();
    private int pauses;
    private BootLogin.Condition pauseCondition;
    private int stops;
    private int recordDeletes;
    private BootLogin bootLogin;

    private final BootLogin.RecordStore records = new BootLogin.RecordStore() {
        @Override public String read() { return record; }
        @Override public boolean exists() { return record != null; }
        @Override public void delete() { recordDeletes++; record = null; }
    };

    private BootLogin newBootLogin(boolean enabled) {
        return new BootLogin(
                enabled,
                records,
                keyUid -> KEY_UID.equals(keyUid) ? credential : null,
                (method, argsJson) -> {
                    calls.add(new Call(method, argsJson));
                    return "InitializeApplication".equals(method) ? initResponse : loginResponse;
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
                () -> {});
    }

    @Before
    public void setUp() {
        record = RECORD;
        credential = "dek:" + DEK_HEX;
        uiVisible = false;
        uiBound = false;
        initResponse = "{\"error\":\"\"}";
        loginResponse = "{\"error\":\"\"}";
        calls.clear();
        pauses = 0;
        pauseCondition = null;
        stops = 0;
        recordDeletes = 0;
        bootLogin = newBootLogin(true);
    }

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
    public void noRecordDoesNothingAndStops() {
        record = null;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertEquals(1, stops);
    }

    @Test
    public void noCredentialDoesNothingAndStops() {
        credential = null;

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertEquals(1, stops);
    }

    @Test
    public void credentialThatIsNotADekDoesNothing() {
        credential = "my password";

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertEquals(1, stops);
    }

    @Test
    public void unreadableRecordDoesNothingAndStops() {
        record = "{not json";

        assertFalse(bootLogin.run());

        assertEquals(0, calls.size());
        assertEquals(1, stops);
    }

    @Test
    public void doesNotStopWhileAUiIsBound() {
        record = null;
        uiBound = true;

        assertFalse(bootLogin.run());

        assertEquals(0, stops);
    }

    @Test
    public void failedInitSkipsTheLoginAndStops() {
        initResponse = "{\"error\":\"init failed\"}";

        assertFalse(bootLogin.run());

        assertEquals(1, calls.size());
        assertEquals("InitializeApplication", calls.get(0).method);
        assertEquals(1, stops);
    }

    @Test
    public void rejectedLoginRequestStops() {
        loginResponse = "{\"error\":\"invalid request\"}";

        assertFalse(bootLogin.run());

        assertEquals(2, calls.size());
        assertEquals(1, stops);
    }

    @Test
    public void failedLoginDoesNotStopWhileAUiIsBound() {
        loginResponse = "{\"error\":\"invalid request\"}";
        uiBound = true;

        assertFalse(bootLogin.run());

        assertEquals(0, stops);
    }

    @Test
    public void failedNodeLoginOfABootLoginStops() {
        assertTrue(bootLogin.run());

        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertEquals(1, stops);
    }

    @Test
    public void failedNodeLoginOfAUiLoginDoesNotStop() {
        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertEquals(0, stops);
    }

    @Test
    public void successfulNodeLoginOfABootLoginKeepsRunning() {
        assertTrue(bootLogin.run());

        bootLogin.onNodeLogin(NODE_LOGIN_OK);

        assertEquals(0, stops);
    }

    @Test
    public void onlyTheFirstNodeLoginBelongsToTheBootLogin() {
        assertTrue(bootLogin.run());
        bootLogin.onNodeLogin(NODE_LOGIN_OK);

        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertEquals(0, stops);
    }

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
    }

    @Test
    public void bootCompletedStartsTheServiceOnlyWithARecord() {
        assertTrue(BootLogin.startsOnBoot(true, records));
        record = null;
        assertFalse(BootLogin.startsOnBoot(true, records));
        assertEquals(0, recordDeletes);
    }

    @Test
    public void bootCompletedWithTheFeatureOffRemovesTheRecord() {
        assertFalse(BootLogin.startsOnBoot(false, records));

        assertEquals(1, recordDeletes);
    }

    @Test
    public void failedNodeLoginDoesNotPause() {
        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertEquals(0, pauses);
    }
}
