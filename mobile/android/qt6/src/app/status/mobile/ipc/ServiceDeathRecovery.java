package app.status.mobile.ipc;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

import org.json.JSONObject;

/**
 * What a status-go call does when the service process dies under it. The new process has lost
 * all in-memory state (it never saw InitializeApplication), so the in-flight call is never
 * re-sent: it answers {@link #SERVICE_DIED_RESPONSE}. The next call first replays the last
 * successful InitializeApplication once. A call is never retried: a login that kills the
 * service must not loop.
 */
final class ServiceDeathRecovery {
    static final String INITIALIZE_APPLICATION = "InitializeApplication";
    static final String SERVICE_DIED_ERROR = "status-go service died";
    static final String SERVICE_DIED_RESPONSE = "{\"error\":\"" + SERVICE_DIED_ERROR + "\"}";

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

        /** The answer to a call the service died under. */
        R serviceDied();

        boolean succeeded(R response);

        /** Frees the replayed InitializeApplication's response. */
        void release(R response);
    }

    private final Object lock = new Object();
    // Guarded by lock
    private byte[] lastInitArgs;
    private boolean replayPending;

    <R, E extends Exception> R call(Connection<R, E> connection, String method,
            ByteBuffer argsUtf8) throws E {
        final boolean isInit = INITIALIZE_APPLICATION.equals(method);
        synchronized (lock) {
            if (replayPending) {
                replayPending = false;
                if (!isInit) {
                    try {
                        connection.release(connection.send(INITIALIZE_APPLICATION,
                                ByteBuffer.wrap(lastInitArgs)));
                    } catch (ServiceDiedException e) {
                        return died(connection);
                    }
                }
            }
        }
        try {
            final R response = connection.send(method, argsUtf8);
            if (isInit && connection.succeeded(response)) {
                remember(argsUtf8);
            }
            return response;
        } catch (ServiceDiedException e) {
            return died(connection);
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

    private <R> R died(Connection<R, ?> connection) {
        synchronized (lock) {
            replayPending = lastInitArgs != null;
        }
        connection.rebind();
        return connection.serviceDied();
    }

    private void remember(ByteBuffer argsUtf8) {
        final ByteBuffer src = argsUtf8.duplicate();
        final byte[] copy = new byte[src.remaining()];
        src.get(copy);
        synchronized (lock) {
            lastInitArgs = copy;
        }
    }
}
