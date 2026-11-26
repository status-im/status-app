package app.status.mobile.ipc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.LinkedList;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Deque;
import java.util.List;

import org.junit.Test;

public class ServiceDeathRecoveryTest {
    private static final String INIT = ServiceDeathRecovery.INITIALIZE_APPLICATION;
    private static final String DIED = "DIED";
    private static final String OK = "{\"error\":\"\"}";

    /** A service connection whose answers are scripted; {@code null} = the process dies. */
    private static final class FakeConnection
            implements ServiceDeathRecovery.Connection<String, RuntimeException> {
        final List<String> sent = new ArrayList<>();
        final Deque<String> script = new LinkedList<>();
        int rebinds;
        int released;
        int loginsInterrupted;
        boolean alwaysDie;
        RuntimeException throwOnNextCall;

        @Override
        public String send(String method, ByteBuffer argsUtf8)
                throws ServiceDeathRecovery.ServiceDiedException {
            sent.add(method + "(" + StandardCharsets.UTF_8.decode(argsUtf8.duplicate()) + ")");
            if (throwOnNextCall != null) {
                final RuntimeException e = throwOnNextCall;
                throwOnNextCall = null;
                throw e;
            }
            final String answer = alwaysDie ? null : (script.isEmpty() ? OK : script.poll());
            if (answer == null) throw new ServiceDeathRecovery.ServiceDiedException(null);
            return answer;
        }

        @Override
        public void rebind() {
            rebinds++;
        }

        @Override
        public void loginInterrupted() {
            loginsInterrupted++;
        }

        @Override
        public String serviceDied() {
            return DIED;
        }

        @Override
        public boolean succeeded(String response) {
            return ServiceDeathRecovery.succeeded(
                    ByteBuffer.wrap(response.getBytes(StandardCharsets.UTF_8)));
        }

        @Override
        public void release(String response) {
            released++;
        }

        void dieOnNextCall() {
            script.add(null);
        }
    }

    private final ServiceDeathRecovery recovery = new ServiceDeathRecovery();
    private final FakeConnection service = new FakeConnection();

    private String call(String method, String args) {
        return recovery.call(service, method,
                ByteBuffer.wrap(args.getBytes(StandardCharsets.UTF_8)));
    }

    @Test
    public void deathMidCallReturnsServiceDiedAndNeverResendsTheCall() {
        call(INIT, "a");
        service.dieOnNextCall();

        assertEquals(DIED, call("LoginAccount", "dek"));

        assertEquals(Arrays.asList("InitializeApplication(a)", "LoginAccount(dek)"), service.sent);
        assertEquals(1, service.rebinds);
    }

    @Test
    public void nextCallReplaysInitializeApplicationOnceThenSendsTheCall() {
        call(INIT, "a");
        service.dieOnNextCall();
        call("LoginAccount", "dek");

        assertEquals(OK, call("GetSettings", "x"));
        call("GetSettings", "y");

        assertEquals(Arrays.asList("InitializeApplication(a)", "LoginAccount(dek)",
                "InitializeApplication(a)", "GetSettings(x)", "GetSettings(y)"), service.sent);
        assertEquals(1, service.released);
    }

    @Test
    public void noReplayWhenTheNextCallIsInitializeApplication() {
        call(INIT, "a");
        service.dieOnNextCall();
        call("LoginAccount", "dek");

        call(INIT, "b");
        call("GetSettings", "x");

        assertEquals(Arrays.asList("InitializeApplication(a)", "LoginAccount(dek)",
                "InitializeApplication(b)", "GetSettings(x)"), service.sent);
    }

    @Test
    public void replaysTheLastSuccessfulInitializeApplicationOnly() {
        call(INIT, "a");
        service.script.add("{\"error\":\"rejected\"}");
        call(INIT, "b");
        service.dieOnNextCall();
        call("LoginAccount", "dek");

        call("GetSettings", "x");

        assertEquals("InitializeApplication(a)", service.sent.get(3));
    }

    @Test
    public void noReplayBeforeAnyInitializeApplication() {
        service.dieOnNextCall();
        call("GetSettings", "x");

        call("GetSettings", "y");

        assertEquals(Arrays.asList("GetSettings(x)", "GetSettings(y)"), service.sent);
    }

    @Test
    public void aServiceThatKeepsDyingIsNeverRetriedInALoop() {
        call(INIT, "a");
        service.alwaysDie = true;

        assertEquals(DIED, call("LoginAccount", "dek"));
        assertEquals(DIED, call("LoginAccount", "dek"));

        // One send per call: the dying login, then only the replay (which died too)
        assertEquals(Arrays.asList("InitializeApplication(a)", "LoginAccount(dek)",
                "InitializeApplication(a)"), service.sent);
        assertEquals(2, service.rebinds);
    }

    @Test
    public void aFailedReplayKeepsTheCallUnsentAndReplaysAgainNextTime() {
        call(INIT, "a");
        service.dieOnNextCall();
        call("LoginAccount", "dek");
        service.script.add("{\"error\":\"status-go service not connected\"}");

        assertEquals(DIED, call("LoginAccount", "dek2"));
        assertEquals(OK, call("GetSettings", "x"));

        assertEquals(Arrays.asList("InitializeApplication(a)", "LoginAccount(dek)",
                "InitializeApplication(a)", "InitializeApplication(a)", "GetSettings(x)"),
                service.sent);
        assertEquals(2, service.released);
    }

    @Test
    public void aReplayThatThrowsStaysPending() {
        call(INIT, "a");
        service.dieOnNextCall();
        call("LoginAccount", "dek");
        service.throwOnNextCall = new IllegalStateException("transaction failed");

        try {
            call("GetSettings", "x");
        } catch (IllegalStateException expected) {
        }
        call("GetSettings", "y");

        assertEquals(Arrays.asList("InitializeApplication(a)", "LoginAccount(dek)",
                "InitializeApplication(a)", "InitializeApplication(a)", "GetSettings(y)"),
                service.sent);
    }

    @Test
    public void aServiceLostOutsideACallArmsTheReplay() {
        call(INIT, "a");

        recovery.serviceLost();
        call("GetSettings", "x");
        call("GetSettings", "y");

        assertEquals(Arrays.asList("InitializeApplication(a)", "InitializeApplication(a)",
                "GetSettings(x)", "GetSettings(y)"), service.sent);
        assertEquals(0, service.rebinds);
    }

    @Test
    public void aServiceLostBeforeAnyInitializeApplicationReplaysNothing() {
        recovery.serviceLost();
        call("GetSettings", "x");

        assertEquals(Arrays.asList("GetSettings(x)"), service.sent);
    }

    @Test
    public void aServiceLostWhileALoginIsInProgressIsADeathDuringLogin() {
        call(INIT, "a");
        call("LoginAccount", "dek");

        assertTrue(recovery.serviceLost());
        // The login ended with the service
        assertFalse(recovery.serviceLost());
    }

    @Test
    public void everyLoginCallStartsALogin() {
        for (String login : Arrays.asList("LoginAccount", "CreateAccountAndLogin",
                "RestoreAccountAndLogin", "Login", "LoginWithConfig", "LoginWithKeycard")) {
            call(login, "x");
            assertTrue(login, recovery.serviceLost());
        }
    }

    @Test
    public void nodeLoginEndsTheLogin() {
        call("LoginAccount", "dek");

        recovery.signalReceived("node.login");

        assertFalse(recovery.serviceLost());
    }

    @Test
    public void otherSignalsDoNotEndTheLogin() {
        call("LoginAccount", "dek");

        recovery.signalReceived("node.ready");

        assertTrue(recovery.serviceLost());
    }

    @Test
    public void aRejectedLoginCallStartsNoLogin() {
        service.script.add("{\"error\":\"login in progress\"}");
        call("LoginAccount", "dek");

        assertFalse(recovery.serviceLost());
    }

    @Test
    public void aDeathUnderTheLoginCallIsAnsweredToTheCallerNotADeathDuringLogin() {
        call(INIT, "a");
        service.dieOnNextCall();
        call("LoginAccount", "dek");

        assertFalse(recovery.serviceLost());
        assertEquals(0, service.loginsInterrupted);
    }

    @Test
    public void aDeathUnderAnotherCallWhileALoginRunsInterruptsTheLogin() {
        call(INIT, "a");
        call("LoginAccount", "dek");
        service.dieOnNextCall();

        assertEquals(DIED, call("GetLoginState", ""));

        assertEquals(1, service.loginsInterrupted);
        assertFalse(recovery.serviceLost());
    }

    @Test
    public void aDeathUnderACallWhileLoggedInInterruptsNoLogin() {
        call("LoginAccount", "dek");
        recovery.signalReceived("node.login");
        service.dieOnNextCall();

        call("GetSettings", "x");

        assertEquals(0, service.loginsInterrupted);
    }

    @Test
    public void aServiceLostWhileLoggedInIsNotADeathDuringLogin() {
        call("LoginAccount", "dek");
        recovery.signalReceived("node.login");
        call("GetSettings", "x");

        assertFalse(recovery.serviceLost());
    }

    @Test
    public void succeededReadsTheErrorField() {
        assertTrue(ServiceDeathRecovery.succeeded(utf8("{\"error\":\"\"}")));
        assertTrue(ServiceDeathRecovery.succeeded(utf8("{\"accounts\":[]}")));
        assertFalse(ServiceDeathRecovery.succeeded(utf8("{\"error\":\"no\"}")));
        assertFalse(ServiceDeathRecovery.succeeded(utf8("not json")));
    }

    @Test
    public void serviceDiedResponseHasTheStubErrorShape() {
        assertEquals("{\"error\":\"status-go service died\"}",
                ServiceDeathRecovery.SERVICE_DIED_RESPONSE);
    }

    private static ByteBuffer utf8(String s) {
        return ByteBuffer.wrap(s.getBytes(StandardCharsets.UTF_8));
    }
}
