package app.status.mobile.ipc;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * What a status-go call does when the service process dies under it. The new process has lost
 * all in-memory state (it never saw InitializeApplication), so the in-flight call is never
 * re-sent: it answers {@link #SERVICE_DIED_RESPONSE} (a JSON-RPC error for CallPrivateRPC). The next call first replays the last
 * successful InitializeApplication once. A call is never retried: a login that kills the
 * service must not loop.
 * It also tells whether the service went away during a login (one this UI sent, or a boot
 * login GetLoginState reported in progress; no node.login yet), so the restarted UI can skip
 * its silent login once.
 * A login that never sends node.login (status-go skips it during local pairing) leaves the
 * login open: a later death then skips one silent login, the credential is kept.
 */
final class ServiceDeathRecovery {
    static final String INITIALIZE_APPLICATION = "InitializeApplication";
    // Matched by StartupOnboardingWrapper.qml (d.serviceDiedError)
    static final String SERVICE_DIED_ERROR = "status-go service died";
    static final String SERVICE_DIED_RESPONSE = "{\"error\":\"" + SERVICE_DIED_ERROR + "\"}";
    static final String CALL_PRIVATE_RPC = "CallPrivateRPC";
    static final String NODE_LOGIN_SIGNAL = "node.login";
    // Read by StatusQtActivity on the relaunch
    static final String SERVICE_DIED_DURING_LOGIN = "statusgo_service_died_during_login";
    static final String GET_LOGIN_STATE = "GetLoginState";
    // Nim LoginState (src/app_service/service/accounts/dto/accounts.nim)
    private static final String LOGIN_STATE_IN_PROGRESS = "inProgress";
    private static final String LOGIN_STATE_LOGGED_IN = "loggedIn";

    // The status-go calls that start a login; it ends with node.login
    private static final Set<String> LOGIN_METHODS = new HashSet<>(Arrays.asList(
            "LoginAccount", "CreateAccountAndLogin", "RestoreAccountAndLogin", "Login",
            "LoginWithConfig", "LoginWithKeycard"));

    /** The service process died during the call. */
    static final class ServiceDiedException extends Exception {
        ServiceDiedException(Throwable cause) {
            super(cause);
        }
    }

    interface Connection<R, E extends Exception> {
        /** One call on the bound service. */
        R send(String method, ByteBuffer argsUtf8) throws ServiceDiedException, E;

        /** Drops the dead binding and binds a new service process. */
        void rebind();

        /**
         * The service died under another call while a login this UI started was running:
         * that login never reports node.login.
         */
        void loginInterrupted();

        /** The answer to a call the service died under. */
        R serviceDied(String response);

        boolean succeeded(R response);

        /** Frees the replayed InitializeApplication's response. */
        void release(R response);

        /** The "state" of a GetLoginState answer, "" when none. */
        String loginState(R response);
    }

    private final Object lock = new Object();
    // Counts the service processes lost; written without the lock (binder callbacks)
    private final AtomicInteger losses = new AtomicInteger();
    private final AtomicBoolean loginInProgress = new AtomicBoolean();
    // A service was lost during a login, until a later login reaches node.login
    private final AtomicBoolean lostDuringLogin = new AtomicBoolean();
    // Guarded by lock
    private byte[] lastInitArgs;
    // Guarded by lock: the losses count the service was last initialized at
    private int initializedAt;

    <R, E extends Exception> R call(Connection<R, E> connection, String method,
            ByteBuffer argsUtf8) throws E {
        final boolean isInit = INITIALIZE_APPLICATION.equals(method);
        // Held across the replay on purpose: every other caller waits until the new service
        // is initialized, so no call reaches it before InitializeApplication
        synchronized (lock) {
            if (!isInit && replayPending()) {
                final R failed = replay(connection, method, argsUtf8);
                if (failed != null) return failed;
            }
        }
        final boolean isLogin = LOGIN_METHODS.contains(method);
        if (isLogin) loginInProgress.set(true);
        final int seen = losses.get();
        final R response;
        try {
            response = connection.send(method, argsUtf8);
        } catch (ServiceDiedException e) {
            return died(connection, isLogin, method, argsUtf8);
        }
        final boolean succeeded = connection.succeeded(response);
        if (isLogin && !succeeded) loginInProgress.set(false);
        if (isInit && succeeded) remember(argsUtf8, seen);
        if (GET_LOGIN_STATE.equals(method) && succeeded) {
            loginStateReported(connection.loginState(response));
        }
        return response;
    }

    /**
     * The service process went away outside a call (disconnect, binding died, a failed
     * one-way hint): the next call replays InitializeApplication on the new one.
     * Returns true when a login this UI started was in progress; that login is over.
     */
    boolean serviceLost() {
        losses.incrementAndGet();
        final boolean duringLogin = loginInProgress.getAndSet(false);
        if (duringLogin) lostDuringLogin.set(true);
        return duringLogin;
    }

    void signalReceived(String type) {
        if (NODE_LOGIN_SIGNAL.equals(type)) loggedIn();
    }

    /** The reason every frontend restart carries: a death during login wins over the cause. */
    String restartReason(String reason) {
        return lostDuringLogin.get() ? SERVICE_DIED_DURING_LOGIN : reason;
    }

    boolean loginInProgress() {
        return loginInProgress.get();
    }

    static String loginState(ByteBuffer responseUtf8) {
        try {
            final String json = StandardCharsets.UTF_8.decode(responseUtf8.duplicate()).toString();
            return new JSONObject(json).optString("state", "");
        } catch (Exception e) {
            return "";
        }
    }

    static boolean succeeded(ByteBuffer responseUtf8) {
        try {
            final String json = StandardCharsets.UTF_8.decode(responseUtf8.duplicate()).toString();
            return new JSONObject(json).optString("error", "").isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    // The adopt of a boot login this UI didn't start is inside the login window too
    private void loginStateReported(String state) {
        if (LOGIN_STATE_IN_PROGRESS.equals(state)) loginInProgress.set(true);
        else if (LOGIN_STATE_LOGGED_IN.equals(state)) loggedIn();
    }

    private void loggedIn() {
        loginInProgress.set(false);
        lostDuringLogin.set(false);
    }

    // Guarded by lock
    private boolean replayPending() {
        return lastInitArgs != null && initializedAt != losses.get();
    }

    // Under lock. Null when the new service is initialized, else the answer for the call,
    // which is not sent. An exception escaping the send leaves the replay pending.
    private <R, E extends Exception> R replay(Connection<R, E> connection, String method,
            ByteBuffer argsUtf8) throws E {
        final int seen = losses.get();
        final R response;
        try {
            response = connection.send(INITIALIZE_APPLICATION, ByteBuffer.wrap(lastInitArgs));
        } catch (ServiceDiedException e) {
            return died(connection, false, method, argsUtf8);
        }
        final boolean succeeded = connection.succeeded(response);
        connection.release(response);
        if (!succeeded) return connection.serviceDied(serviceDiedResponse(method, argsUtf8));
        initializedAt = seen;
        return null;
    }

    // A death under the login call itself is answered to its caller
    private <R> R died(Connection<R, ?> connection, boolean underTheLoginCall, String method,
            ByteBuffer argsUtf8) {
        final boolean interrupted = serviceLost() && !underTheLoginCall;
        connection.rebind();
        if (interrupted) connection.loginInterrupted();
        return connection.serviceDied(serviceDiedResponse(method, argsUtf8));
    }

    // CallPrivateRPC callers parse a JSON-RPC response
    static String serviceDiedResponse(String method, ByteBuffer argsUtf8) {
        if (!CALL_PRIVATE_RPC.equals(method)) return SERVICE_DIED_RESPONSE;
        return "{\"jsonrpc\":\"2.0\",\"id\":" + JSONObject.valueToString(requestId(argsUtf8))
                + ",\"error\":{\"code\":-32000,\"message\":\"" + SERVICE_DIED_ERROR + "\"}}";
    }

    // The id of the request in the ["<request>"] argument list, null when unreadable
    private static Object requestId(ByteBuffer argsUtf8) {
        try {
            final String json = StandardCharsets.UTF_8.decode(argsUtf8.duplicate()).toString();
            return new JSONObject(new JSONArray(json).getString(0)).opt("id");
        } catch (Exception e) {
            return null;
        }
    }

    private void remember(ByteBuffer argsUtf8, int seen) {
        final ByteBuffer src = argsUtf8.duplicate();
        final byte[] copy = new byte[src.remaining()];
        src.get(copy);
        synchronized (lock) {
            lastInitArgs = copy;
            initializedAt = seen;
        }
    }
}
