package app.status.mobile.ipc;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.json.JSONObject;

/**
 * What a status-go call does when the service process dies under it. The new process has lost
 * all in-memory state (it never saw InitializeApplication), so the in-flight call is never
 * re-sent: it answers {@link #SERVICE_DIED_RESPONSE}. The next call first replays the last
 * successful InitializeApplication once. A call is never retried: a login that kills the
 * service must not loop.
 * It also tells whether the service went away while a login this UI started was running
 * (sent, no node.login yet), so the restarted UI can skip its silent login once.
 */
final class ServiceDeathRecovery {
    static final String INITIALIZE_APPLICATION = "InitializeApplication";
    // Matched by StartupOnboardingWrapper.qml (d.serviceDiedError)
    static final String SERVICE_DIED_ERROR = "status-go service died";
    static final String SERVICE_DIED_RESPONSE = "{\"error\":\"" + SERVICE_DIED_ERROR + "\"}";
    static final String NODE_LOGIN_SIGNAL = "node.login";

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
        R serviceDied();

        boolean succeeded(R response);

        /** Frees the replayed InitializeApplication's response. */
        void release(R response);
    }

    private final Object lock = new Object();
    // Counts the service processes lost; written without the lock (binder callbacks)
    private final AtomicInteger losses = new AtomicInteger();
    private final AtomicBoolean loginInProgress = new AtomicBoolean();
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
                final R failed = replay(connection);
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
            return died(connection, isLogin);
        }
        final boolean succeeded = connection.succeeded(response);
        if (isLogin && !succeeded) loginInProgress.set(false);
        if (isInit && succeeded) remember(argsUtf8, seen);
        return response;
    }

    /**
     * The service process went away outside a call (disconnect, binding died, a failed
     * one-way hint): the next call replays InitializeApplication on the new one.
     * Returns true when a login this UI started was in progress; that login is over.
     */
    boolean serviceLost() {
        losses.incrementAndGet();
        return loginInProgress.getAndSet(false);
    }

    void signalReceived(String type) {
        if (NODE_LOGIN_SIGNAL.equals(type)) loginInProgress.set(false);
    }

    boolean loginInProgress() {
        return loginInProgress.get();
    }

    static boolean succeeded(ByteBuffer responseUtf8) {
        try {
            final String json = StandardCharsets.UTF_8.decode(responseUtf8.duplicate()).toString();
            return new JSONObject(json).optString("error", "").isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    // Guarded by lock
    private boolean replayPending() {
        return lastInitArgs != null && initializedAt != losses.get();
    }

    // Under lock. Null when the new service is initialized, else the answer for the call,
    // which is not sent. An exception escaping the send leaves the replay pending.
    private <R, E extends Exception> R replay(Connection<R, E> connection) throws E {
        final int seen = losses.get();
        final R response;
        try {
            response = connection.send(INITIALIZE_APPLICATION, ByteBuffer.wrap(lastInitArgs));
        } catch (ServiceDiedException e) {
            return died(connection, false);
        }
        final boolean succeeded = connection.succeeded(response);
        connection.release(response);
        if (!succeeded) return connection.serviceDied();
        initializedAt = seen;
        return null;
    }

    // A death under the login call itself is answered to its caller
    private <R> R died(Connection<R, ?> connection, boolean underTheLoginCall) {
        final boolean interrupted = serviceLost() && !underTheLoginCall;
        connection.rebind();
        if (interrupted) connection.loginInterrupted();
        return connection.serviceDied();
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
