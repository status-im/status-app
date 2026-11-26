package app.status.mobile.ipc;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Build;
import android.os.IBinder;
import android.os.Looper;
import android.os.Process;
import android.os.RemoteException;
import android.os.SystemClock;
import android.os.TransactionTooLargeException;
import android.system.ErrnoException;
import android.util.Log;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.nio.ByteBuffer;

import app.status.mobile.StatusGoStub;

/** UI-process Binder client for {@link StatusGoService}. */
public final class StatusGoServiceClient {
    private static final String TAG = "StatusGoServiceClient";
    private static final long CONNECT_TIMEOUT_MS = 8000;
    private static final int LARGE_SIGNAL_WARN_BYTES = 256 * 1024;
    private static final long RESTART_KILL_DELAY_MS = 250L;
    private static final long DISCONNECT_SUPPRESSION_WINDOW_MS = 1000L;

    /**
     * Recovery reason: the service went away during a login (see ServiceDeathRecovery). The
     * restarted UI skips its silent login once (a login that kills the service must not loop).
     */
    public static final String SERVICE_DIED_DURING_LOGIN =
            ServiceDeathRecovery.SERVICE_DIED_DURING_LOGIN;
    private static final String LOGIN_INTERRUPTED_PREFS = "status_login_interrupted";
    private static final String LOGIN_INTERRUPTED_PID = "writer_pid";
    private static final String LOGIN_INTERRUPTED_AT = "written_at";
    private static final String LOST_WHILE_HIDDEN_REASON = "statusgo_service_restarted";

    private static volatile StatusGoServiceClient sInstance;
    private static final AtomicBoolean restartRequested = new AtomicBoolean(false);
    private static final AtomicBoolean suppressDisconnectRestart = new AtomicBoolean(false);
    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());

    /** Fire-and-forget background thread (dies when work finishes); avoids a long-lived executor. */
    private static void runUiVisibilityAsync(Runnable r) {
        new Thread(() -> {
            Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND);
            r.run();
        }, "StatusGo-UiVisibility").start();
    }

    public static StatusGoServiceClient get() {
        if (sInstance == null) {
            synchronized (StatusGoServiceClient.class) {
                if (sInstance == null) sInstance = new StatusGoServiceClient();
            }
        }
        return sInstance;
    }

    private final Object lock = new Object();
    private IStatusGoService service;
    private CountDownLatch connectedLatch;
    private boolean bindingInProgress = false;
    private boolean bound = false;
    // Last known UI visibility intent from app process. Replayed on (re)connect.
    private volatile boolean desiredUiVisible = false;
    // Set once UI process has explicitly reported visibility at least once.
    private volatile boolean hasUiVisibilityHint = false;
    // Tracks whether this process ever had a live Binder connection to status-go.
    private volatile boolean everConnected = false;
    // The service process went away while the UI was hidden: the service that comes up next
    // is a fresh backend the UI knows nothing about (logged out, or logged in by itself through
    // the boot login when RESUME_AFTER_RESTART_ENABLED is on). The frontend restarts once
    // it is visible again (an activity start from the background is blocked on Android 10+,
    // or brings Status to the front on its own where it is allowed).
    private volatile boolean serviceLostWhileHidden = false;

    private final IStatusGoSignalListener signalListener = new IStatusGoSignalListener.Stub() {
        @Override
        public void onSignal(byte[] utf8) {
            if (utf8 == null) return;
            if (deathRecovery.loginInProgress()) {
                deathRecovery.signalReceived(SignalEnvelope.typeOf(ByteBuffer.wrap(utf8)));
            }
            // Forward into the native stub callback (SetSignalEventCallback).
            StatusGoStub.nativeDeliverSignal(utf8);
        }

        @Override
        public void onSignalShm(IpcPayload signalPayload) {
            if (signalPayload == null) {
                Log.w(TAG, "onSignalShm: null payload");
                return;
            }

            try (IpcPayload payload = signalPayload) {
                final ByteBuffer utf8 = payload.buffer();
                if (deathRecovery.loginInProgress()) {
                    deathRecovery.signalReceived(SignalEnvelope.typeOf(utf8));
                }
                if (utf8.remaining() >= LARGE_SIGNAL_WARN_BYTES) {
                    Log.w(TAG, "received large status-go signal type=" + SignalEnvelope.typeOf(utf8)
                            + " sizeBytes=" + utf8.remaining());
                }
                StatusGoStub.nativeDeliverSignalDirect(utf8, utf8.remaining());
            } catch (ErrnoException e) {
                Log.w(TAG, "onSignalShm: shared memory read failed", e);
            }
        }
    };

    private final ServiceConnection conn = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder binder) {
            synchronized (lock) {
                service = IStatusGoService.Stub.asInterface(binder);
                bindingInProgress = false;
                bound = true;
                everConnected = true;
                try {
                    service.registerSignalListener(signalListener);
                } catch (RemoteException e) {
                    Log.w(TAG, "onServiceConnected: registerSignalListener failed", e);
                }
                if (connectedLatch != null) connectedLatch.countDown();
            }
            if (serviceLostWhileHidden && hasUiVisibilityHint && desiredUiVisible) {
                serviceLostWhileHidden = false;
                requestFrontendRestart(StatusGoStub.getContext(), LOST_WHILE_HIDDEN_REASON);
                return;
            }
            // Replay UI visibility on a background thread — the Binder call
            // reaches nativeCall("AppStateChange") which can block for seconds
            // if the Go runtime's memory was paged out (major faults).
            if (hasUiVisibilityHint) {
                final IStatusGoService s;
                synchronized (lock) {
                    s = service;
                }
                if (s != null) {
                    runUiVisibilityAsync(() -> {
                        try {
                            s.setUiVisible(desiredUiVisible);
                        } catch (RemoteException e) {
                            Log.w(TAG, "onServiceConnected: setUiVisible replay failed", e);
                        }
                    });
                }
            }
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            final boolean suppressed = suppressDisconnectRestart.getAndSet(false);
            synchronized (lock) {
                service = null;
                connectedLatch = null;
                bindingInProgress = false;
                bound = false;
            }
            serviceGone(suppressed, "statusgo_service_disconnected");
        }

        @Override
        public void onBindingDied(ComponentName name) {
            final boolean suppressed = suppressDisconnectRestart.getAndSet(false);
            synchronized (lock) {
                service = null;
                connectedLatch = null;
                bindingInProgress = false;
                bound = false;
            }
            serviceGone(suppressed, "statusgo_binding_died");
        }

        @Override
        public void onNullBinding(ComponentName name) {
            synchronized (lock) {
                service = null;
                connectedLatch = null;
                bindingInProgress = false;
                bound = false;
            }
        }
    };

    private final ServiceDeathRecovery deathRecovery = new ServiceDeathRecovery();

    private StatusGoServiceClient() {}

    // The service process went away (binder callback): the next call replays
    // InitializeApplication on the new one, and the frontend restarts as before.
    private void serviceGone(boolean suppressed, String reason) {
        deathRecovery.serviceLost();
        if (suppressed || !everConnected) return;
        restartFrontend(StatusGoStub.getContext(), reason);
    }

    // Now, or once the UI is visible again
    private void restartFrontend(Context app, String reason) {
        if (hasUiVisibilityHint && desiredUiVisible) {
            requestFrontendRestart(app, reason);
        } else {
            serviceLostWhileHidden = true;
        }
    }

    /** True once, in the UI process a frontend restart for a login the service died under started. */
    public static boolean takeLoginInterrupted(Context context) {
        return LoginInterruptedMarker.take(loginInterruptedStore(context),
                Process.myPid(), SystemClock.elapsedRealtime());
    }

    // Written by the dying UI process, read by the next one: commit() and a multi-process read
    @SuppressWarnings("deprecation")
    private static LoginInterruptedMarker.Store loginInterruptedStore(Context context) {
        final SharedPreferences prefs = context.getApplicationContext()
                .getSharedPreferences(LOGIN_INTERRUPTED_PREFS, Context.MODE_MULTI_PROCESS);
        return new LoginInterruptedMarker.Store() {
            @Override public void write(int writerPid, long writtenAt) {
                prefs.edit().putInt(LOGIN_INTERRUPTED_PID, writerPid)
                        .putLong(LOGIN_INTERRUPTED_AT, writtenAt).commit();
            }
            @Override public int writerPid() { return prefs.getInt(LOGIN_INTERRUPTED_PID, 0); }
            @Override public long writtenAt() { return prefs.getLong(LOGIN_INTERRUPTED_AT, 0L); }
            @Override public void clear() { prefs.edit().clear().commit(); }
        };
    }

    // Every restart goes through here: a death during login keeps its reason whatever the cause
    private void requestFrontendRestart(Context appContext, String cause) {
        final String reason = deathRecovery.restartReason(cause);
        if (appContext == null) {
            Log.w(TAG, "requestFrontendRestart: context is null, reason=" + reason);
            return;
        }
        if (!restartRequested.compareAndSet(false, true)) return;

        try {
            Intent launch = appContext.getPackageManager()
                    .getLaunchIntentForPackage(appContext.getPackageName());
            if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                if (SERVICE_DIED_DURING_LOGIN.equals(reason)) {
                    LoginInterruptedMarker.mark(loginInterruptedStore(appContext),
                            Process.myPid(), SystemClock.elapsedRealtime());
                }
                appContext.startActivity(launch);
            } else {
                Log.w(TAG, "requestFrontendRestart: launch intent is null, reason=" + reason);
            }
        } catch (Throwable t) {
            Log.w(TAG, "requestFrontendRestart: failed to relaunch app, reason=" + reason, t);
        }

        MAIN_HANDLER.postDelayed(
                () -> android.os.Process.killProcess(android.os.Process.myPid()),
                RESTART_KILL_DELAY_MS
        );
    }

    private void resetConnection(Context appContext) {
        final boolean shouldUnbind;
        synchronized (lock) {
            service = null;
            connectedLatch = null;
            shouldUnbind = bound || bindingInProgress;
            bindingInProgress = false;
        }
        try {
            if (shouldUnbind) {
                suppressDisconnectRestart.set(true);
                // Clear suppression even if no disconnect callback arrives for this unbind path.
                MAIN_HANDLER.postDelayed(
                        () -> suppressDisconnectRestart.compareAndSet(true, false),
                        DISCONNECT_SUPPRESSION_WINDOW_MS
                );
                appContext.getApplicationContext().unbindService(conn);
            }
        } catch (Throwable ignored) {
            suppressDisconnectRestart.set(false);
        } finally {
            synchronized (lock) {
                bound = false;
            }
        }
    }

    public void ensureStartedAndBound(Context context) {
        final Context app = context.getApplicationContext();
        boolean shouldAttemptBind = false;
        synchronized (lock) {
            if (service != null) return;
            if (connectedLatch == null) connectedLatch = new CountDownLatch(1);
            if (!bound && !bindingInProgress) {
                bindingInProgress = true;
                shouldAttemptBind = true;
            }
        }
        if (!shouldAttemptBind) return;

        Intent i = new Intent(app, StatusGoService.class);
        i.setAction(StatusGoService.ACTION_START);
        try {
            // Start as a normal service; StatusGoService promotes itself to foreground only
            // when logged in.
            app.startService(i);
        } catch (Throwable t) {
            // Fallback: some OEMs are strict; best-effort start as foreground service.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                app.startForegroundService(i);
            } else {
                app.startService(i);
            }
        }
        boolean bindOk = false;
        try {
            // Bind for request/response.
            bindOk = app.bindService(i, conn, Context.BIND_AUTO_CREATE);
        } catch (Throwable t) {
            Log.w(TAG, "bindService failed", t);
        }
        if (!bindOk) {
            synchronized (lock) {
                bindingInProgress = false;
                bound = false;
                if (connectedLatch != null) {
                    connectedLatch.countDown();
                    connectedLatch = null;
                }
            }
        } else {
            synchronized (lock) {
                bound = true;
            }
        }
    }

    /**
     * Stops the status-go service process.
     *
     * Unbinds first so our binding can't keep the service alive, then delivers ACTION_STOP via
     * startService. startService is dispatched by the system's ActivityManager, so it is delivered
     * even after the UI process exits immediately afterwards (_exit(0)). The service then kills its
     * own process (see StatusGoService.onStartCommand), guaranteeing a clean login on next launch.
     */
    public void stopService(Context context) {
        final Context app = context.getApplicationContext();
        resetConnection(app);
        Intent i = new Intent(app, StatusGoService.class);
        i.setAction(StatusGoService.ACTION_STOP);
        try {
            app.startService(i);
        } catch (Throwable t) {
            Log.w(TAG, "stopService failed", t);
        }
    }

    /**
     * Calls status-go in the service process. {@code argsUtf8} is the JSON array of string
     * arguments; it is read during the call only. The caller must close() the result.
     */
    public IpcPayload call(Context context, String method, ByteBuffer argsUtf8) {
        final Context app = context.getApplicationContext();
        try {
            return deathRecovery.call(new BinderConnection(app), method, argsUtf8);
        } catch (TransactionTooLargeException e) {
            return transactionTooLarge(method, argsUtf8, e);
        } catch (RemoteException e) {
            Log.w(TAG, "call failed", e);
            if (everConnected) {
                requestFrontendRestart(app, "statusgo_service_call_failed");
            }
            return IpcPayload.inline("{\"error\":\"status-go service call failed\"}");
        }
    }

    private IStatusGoService awaitService(Context app) {
        ensureStartedAndBound(app);
        IStatusGoService s;
        CountDownLatch latch;
        synchronized (lock) {
            s = service;
            latch = connectedLatch;
        }
        if (s == null && latch != null) {
            try {
                latch.await(CONNECT_TIMEOUT_MS, TimeUnit.MILLISECONDS);
            } catch (InterruptedException ignored) {
            }
        }
        synchronized (lock) {
            return service;
        }
    }

    private final class BinderConnection
            implements ServiceDeathRecovery.Connection<IpcPayload, RemoteException> {
        private final Context app;

        BinderConnection(Context app) {
            this.app = app;
        }

        @Override
        public IpcPayload send(String method, ByteBuffer argsUtf8)
                throws ServiceDeathRecovery.ServiceDiedException, RemoteException {
            final IStatusGoService s = awaitService(app);
            if (s == null) {
                if (everConnected) {
                    requestFrontendRestart(app, "statusgo_service_not_connected");
                }
                return IpcPayload.inline("{\"error\":\"status-go service not connected\"}");
            }
            try {
                return readRpc(s, method, argsUtf8);
            } catch (android.os.DeadObjectException e) {
                Log.w(TAG, "service died during " + method, e);
                throw new ServiceDeathRecovery.ServiceDiedException(e);
            }
        }

        @Override
        public void rebind() {
            // Our own unbind: suppresses the frontend restart the disconnect would request
            resetConnection(app);
            ensureStartedAndBound(app);
        }

        @Override
        public void loginInterrupted() {
            restartFrontend(app, SERVICE_DIED_DURING_LOGIN);
        }

        @Override
        public IpcPayload serviceDied(String response) {
            return IpcPayload.inline(response);
        }

        @Override
        public boolean succeeded(IpcPayload response) {
            try {
                return ServiceDeathRecovery.succeeded(response.buffer());
            } catch (ErrnoException e) {
                return false;
            }
        }

        @Override
        public void release(IpcPayload response) {
            response.close();
        }

        @Override
        public String loginState(IpcPayload response) {
            try {
                return ServiceDeathRecovery.loginState(response.buffer());
            } catch (ErrnoException e) {
                return "";
            }
        }
    }

    // A payload problem, not a dead service: restarting the frontend cannot help.
    private static IpcPayload transactionTooLarge(String method, ByteBuffer argsUtf8,
            TransactionTooLargeException e) {
        Log.w(TAG, "call failed: transaction too large method=" + method
                + " argsBytes=" + argsUtf8.remaining(), e);
        return IpcPayload.inline("{\"error\":\"status-go transaction too large\"}");
    }

    /** Issues an rpcCall, sending large requests through SharedMemory. */
    private static IpcPayload readRpc(IStatusGoService s, String method, ByteBuffer argsUtf8)
            throws RemoteException {
        try (IpcPayload request = IpcPayload.of(
                argsUtf8, IpcPayload.INLINE_THRESHOLD_BYTES, "statusgo-request")) {
            final IpcPayload resp = s.rpcCall(method, request);
            if (resp == null) {
                return IpcPayload.inline("{\"error\":\"status-go service returned null\"}");
            }
            return resp;
        } catch (ErrnoException e) {
            Log.w(TAG, "rpcCall: shared memory request failed", e);
            return IpcPayload.inline("{\"error\":\"shared memory request failed\"}");
        }
    }

    /**
     * Best-effort hint for whether UI is currently in foreground.
     * Dispatched to a background thread so the caller (including the UI thread) is never
     * blocked by the service-connection latch or the Binder call.
     */
    public void setUiVisible(Context context, boolean visible) {
        desiredUiVisible = visible;
        hasUiVisibilityHint = true;
        final Context app = context.getApplicationContext();
        if (visible && serviceLostWhileHidden) {
            serviceLostWhileHidden = false;
            requestFrontendRestart(app, LOST_WHILE_HIDDEN_REASON);
            return;
        }
        runUiVisibilityAsync(() -> setUiVisibleSync(app, visible));
    }

    private void setUiVisibleSync(Context app, boolean visible) {
        ensureStartedAndBound(app);
        IStatusGoService s;
        CountDownLatch latch;
        synchronized (lock) {
            s = service;
            latch = connectedLatch;
        }
        if (s == null && latch != null) {
            try {
                latch.await(CONNECT_TIMEOUT_MS, TimeUnit.MILLISECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
        }
        synchronized (lock) {
            s = service;
        }
        if (s == null) return;
        try {
            s.setUiVisible(visible);
        } catch (RemoteException e) {
            Log.w(TAG, "setUiVisible failed", e);
            if (e instanceof android.os.DeadObjectException) {
                // Never re-sent: onServiceConnected replays the visibility to the new service
                final boolean duringLogin = deathRecovery.serviceLost();
                resetConnection(app);
                ensureStartedAndBound(app);
                if (duringLogin) restartFrontend(app, SERVICE_DIED_DURING_LOGIN);
            }
        }
    }
}

