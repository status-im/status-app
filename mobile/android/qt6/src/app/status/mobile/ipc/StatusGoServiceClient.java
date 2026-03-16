package app.status.mobile.ipc;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Build;
import android.os.IBinder;
import android.os.RemoteException;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import app.status.mobile.StatusGoStub;

/** UI-process Binder client for {@link StatusGoService}. */
public final class StatusGoServiceClient {
    private static final String TAG = "StatusGoServiceClient";
    private static final long CONNECT_TIMEOUT_MS = 8000;

    private static volatile StatusGoServiceClient sInstance;

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
            // Forward into the native stub callback (SetSignalEventCallback).
            StatusGoStub.nativeDeliverSignal(jsonSignal);
        }
    };

    private final ServiceConnection conn = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder binder) {
            synchronized (lock) {
                service = IStatusGoService.Stub.asInterface(binder);
                bindingInProgress = false;
                bound = true;
                try {
                    service.registerSignalListener(signalListener);
                    // Re-apply lifecycle state only after explicit UI visibility callback.
                    // This avoids an implicit initial "background" transition on cold bind.
                    if (hasUiVisibilityHint) {
                        service.setUiVisible(desiredUiVisible);
                    }
                } catch (RemoteException e) {
                    Log.w(TAG, "onServiceConnected setup failed", e);
                }
                if (connectedLatch != null) connectedLatch.countDown();
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
            final String pathOrErr = s.callToFile(method, argsJson);
            if (pathOrErr == null) {
                return "{\"error\":\"status-go service returned null\"}";
            }
            if (!pathOrErr.startsWith("/")) {
                // service returned an error JSON (small)
                return pathOrErr;
            }
            final File f = new File(pathOrErr);
            byte[] data;
            try {
                data = Files.readAllBytes(f.toPath());
            } catch (IOException e) {
                Log.w(TAG, "Failed to read response file: " + pathOrErr, e);
                return "{\"error\":\"failed to read response file\"}";
            } finally {
                // best-effort cleanup
                //noinspection ResultOfMethodCallIgnored
                f.delete();
            }
            return new String(data, StandardCharsets.UTF_8);
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
                        final String pathOrErr2 = s.callToFile(method, argsJson);
                        if (pathOrErr2 == null) {
                            return "{\"error\":\"status-go service returned null\"}";
                        }
                        if (!pathOrErr2.startsWith("/")) {
                            return pathOrErr2;
                        }
                        final File f2 = new File(pathOrErr2);
                        byte[] data2;
                        try {
                            data2 = Files.readAllBytes(f2.toPath());
                        } catch (IOException io) {
                            Log.w(TAG, "Failed to read response file: " + pathOrErr2, io);
                            return "{\"error\":\"failed to read response file\"}";
                        } finally {
                            //noinspection ResultOfMethodCallIgnored
                            f2.delete();
                        }
                        return new String(data2, StandardCharsets.UTF_8);
                    } catch (RemoteException e2) {
                        Log.w(TAG, "call retry failed", e2);
                    }
                }
            }
            return "{\"error\":\"status-go service call failed\"}";
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
        ensureStartedAndBound(app);
        Executors.newSingleThreadExecutor().execute(() -> {
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
        });
    }
}

