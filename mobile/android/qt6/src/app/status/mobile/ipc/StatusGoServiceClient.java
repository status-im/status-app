package app.status.mobile.ipc;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Build;
import android.os.IBinder;
import android.os.Process;
import android.os.RemoteException;
import android.system.ErrnoException;
import android.util.Log;

import org.json.JSONObject;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.nio.charset.StandardCharsets;

import app.status.mobile.StatusGoStub;

/** UI-process Binder client for {@link StatusGoService}. */
public final class StatusGoServiceClient {
    private static final String TAG = "StatusGoServiceClient";
    private static final long CONNECT_TIMEOUT_MS = 8000;
    private static final int LARGE_SIGNAL_WARN_BYTES = 256 * 1024;

    private static volatile StatusGoServiceClient sInstance;

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

    private final IStatusGoSignalListener signalListener = new IStatusGoSignalListener.Stub() {
        @Override
        public void onSignal(String jsonSignal) {
            final int signalSizeBytes = jsonSignal != null
                    ? jsonSignal.getBytes(StandardCharsets.UTF_8).length
                    : 0;
            if (signalSizeBytes >= LARGE_SIGNAL_WARN_BYTES) {
                Log.w(TAG, "received large status-go signal type=" + getSignalType(jsonSignal)
                        + " sizeBytes=" + signalSizeBytes);
            }
            // Forward into the native stub callback (SetSignalEventCallback).
            StatusGoStub.nativeDeliverSignal(jsonSignal);
        }

        @Override
        public void onSignalShm(RpcResponse signalPayload) {
            if (signalPayload == null) {
                Log.w(TAG, "onSignalShm: null payload");
                return;
            }

            try (RpcResponse payload = signalPayload) {
                final String jsonSignal = payload.readJson();
                final int signalSizeBytes = jsonSignal != null
                        ? jsonSignal.getBytes(StandardCharsets.UTF_8).length
                        : 0;
                if (signalSizeBytes >= LARGE_SIGNAL_WARN_BYTES) {
                    Log.w(TAG, "received large status-go signal type=" + getSignalType(jsonSignal)
                            + " sizeBytes=" + signalSizeBytes);
                }
                StatusGoStub.nativeDeliverSignal(jsonSignal);
            } catch (ErrnoException e) {
                Log.w(TAG, "onSignalShm: shared memory read failed", e);
            }
        }
    };

    private static String getSignalType(String jsonSignal) {
        if (jsonSignal == null || jsonSignal.isEmpty()) return "";
        try {
            return new JSONObject(jsonSignal).optString("type", "");
        } catch (Throwable t) {
            return "";
        }
    }

    private final ServiceConnection conn = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder binder) {
            synchronized (lock) {
                service = IStatusGoService.Stub.asInterface(binder);
                bindingInProgress = false;
                bound = true;
                try {
                    service.registerSignalListener(signalListener);
                } catch (RemoteException e) {
                    Log.w(TAG, "onServiceConnected: registerSignalListener failed", e);
                }
                if (connectedLatch != null) connectedLatch.countDown();
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
            synchronized (lock) {
                service = null;
                connectedLatch = null;
                bindingInProgress = false;
                bound = false;
            }
        }
    };

    private StatusGoServiceClient() {}

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
                appContext.getApplicationContext().unbindService(conn);
            }
        } catch (Throwable ignored) {
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

    public String call(Context context, String method, String argsJson) {
        final Context app = context.getApplicationContext();
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
            s = service;
        }
        if (s == null) {
            return "{\"error\":\"status-go service not connected\"}";
        }
        try {
            return readRpc(s, method, argsJson);
        } catch (RemoteException e) {
            Log.w(TAG, "call failed", e);
            // After reinstall/update (or service crash), binder can become a dead object.
            // Reset, rebind, and retry once to avoid cascading JSON parse errors upstream.
            if (e instanceof android.os.DeadObjectException) {
                resetConnection(app);
                ensureStartedAndBound(app);
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
                    s = service;
                }
                if (s != null) {
                    try {
                        return readRpc(s, method, argsJson);
                    } catch (RemoteException e2) {
                        Log.w(TAG, "call retry failed", e2);
                    }
                }
            }
            return "{\"error\":\"status-go service call failed\"}";
        }
    }

    /**
     * Issues an rpcCall and reads the response. The RpcResponse is closed unconditionally
     * via try-with-resources so the SharedMemory fd (if any) is released on every exit path.
     */
    private static String readRpc(IStatusGoService s, String method, String argsJson)
            throws RemoteException {
        try (RpcResponse resp = s.rpcCall(method, argsJson)) {
            if (resp == null) {
                return "{\"error\":\"status-go service returned null\"}";
            }
            return resp.readJson();
        } catch (ErrnoException e) {
            Log.w(TAG, "rpcCall: shared memory read failed", e);
            return "{\"error\":\"shared memory read failed\"}";
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
                resetConnection(app);
                ensureStartedAndBound(app);
                synchronized (lock) {
                    s = service;
                    latch = connectedLatch;
                }
                if (s == null && latch != null) {
                    try {
                        latch.await(CONNECT_TIMEOUT_MS, TimeUnit.MILLISECONDS);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        return;
                    }
                }
                synchronized (lock) {
                    s = service;
                }
                if (s != null) {
                    try {
                        s.setUiVisible(visible);
                    } catch (RemoteException e2) {
                        Log.w(TAG, "setUiVisible retry failed", e2);
                    }
                }
            }
        }
    }
}

