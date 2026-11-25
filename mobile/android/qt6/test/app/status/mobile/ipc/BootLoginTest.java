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
    private final List<Call> calls = new ArrayList<>();
    private int pauses;
    private int stops;
    private BootLogin bootLogin;

    @Before
    public void setUp() {
        record = RECORD;
        credential = "dek:" + DEK_HEX;
        uiVisible = false;
        uiBound = false;
        calls.clear();
        pauses = 0;
        stops = 0;
        bootLogin = new BootLogin(
                () -> record,
                keyUid -> KEY_UID.equals(keyUid) ? credential : null,
                (method, argsJson) -> {
                    calls.add(new Call(method, argsJson));
                    return "{\"error\":\"\"}";
                },
                () -> pauses++,
                new BootLogin.Ui() {
                    @Override public boolean visible() { return uiVisible; }
                    @Override public boolean bound() { return uiBound; }
                },
                () -> stops++,
                () -> {});
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
    public void failedInitSkipsTheLogin() {
        bootLogin = new BootLogin(
                () -> record,
                keyUid -> credential,
                (method, argsJson) -> {
                    calls.add(new Call(method, argsJson));
                    return "{\"error\":\"init failed\"}";
                },
                () -> pauses++,
                new BootLogin.Ui() {
                    @Override public boolean visible() { return false; }
                    @Override public boolean bound() { return false; }
                },
                () -> stops++,
                () -> {});

        assertFalse(bootLogin.run());

        assertEquals(1, calls.size());
        assertEquals("InitializeApplication", calls.get(0).method);
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
    public void failedNodeLoginDoesNotPause() {
        bootLogin.onNodeLogin(NODE_LOGIN_FAILED);

        assertEquals(0, pauses);
    }
}
