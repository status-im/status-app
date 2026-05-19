package app.status.mobile.ipc;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Binder;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.RemoteCallbackList;
import android.os.RemoteException;
import android.os.SharedMemory;
import android.system.OsConstants;
import android.util.Log;

import androidx.core.app.NotificationCompat;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import org.json.JSONArray;
import org.json.JSONObject;

import app.status.mobile.BuildConfig;
import app.status.mobile.R;
import app.status.mobile.ipc.notifications.StatusNotificationManager;
import im.status.mobileui.PushNotificationHelper;

/**
 * Separate-process status-go host.
 *
 * Runs in its own Android process (see AndroidManifest.xml) and is intended to be the
 * only process that links/uses the real libstatus.so. UI process talks to it over Binder.
 *
 * This class manages service lifecycle, foreground promotion, IPC (Binder), and signal
 * dispatch.
 */
public final class StatusGoService extends Service {
    private static final String TAG = "StatusGoService";

    /**
     * Responses shorter than this (in UTF-8 bytes) are returned inline in the Binder reply
     * Parcel; larger responses are transferred via SharedMemory to stay under Android's
     * per-process Binder transaction budget (~1 MB hard cap). Empirically ~97% of calls fit
     * at 64 KB.
     */
    private static final int INLINE_THRESHOLD_BYTES = 64 * 1024;

    public static final String ACTION_START =
            BuildConfig.APPLICATION_ID + ".ipc.StatusGoService.START";
    public static final String ACTION_STOP =
            BuildConfig.APPLICATION_ID + ".ipc.StatusGoService.STOP";

    private static final String CHANNEL_ID = "statusgo";
    private static final int NOTIFICATION_ID = 4242;

    /** App icon for notifications (Status logo, from status-logo-white.svg). */
    private static final int NOTIFICATION_SMALL_ICON = R.drawable.ic_notification_status_logo;

    private final RemoteCallbackList<IStatusGoSignalListener> listeners = new RemoteCallbackList<>();
    private volatile boolean foregroundStarted = false;
    private volatile boolean uiVisible = false;

    private final ExecutorService lifecycleExecutor = Executors.newSingleThreadExecutor();
    private final AtomicInteger lifecycleGen = new AtomicInteger(0);

    /** Single instance per process; lets background components (NotificationReplyReceiver) reach the service. */
    private static volatile StatusGoService sInstance;

    /**
     * Background work (e.g. an inline notification reply) sends a chat message while messaging
     * is paused. The send path resumes the "messaging" service so the message actually
     * transmits, then asks us to re-pause after a flush window. This delay must comfortably
     * cover the mvds outbound loop picking up the queued message after resume.
     */
    private static final long MESSAGING_REPAUSE_DELAY_MS = 60_000L;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Runnable repauseMessagingRunnable = () -> {
        if (uiVisible) return; // app came to foreground; foregrounding already resumed messaging
        try {
            lifecycleExecutor.execute(() -> {
                if (uiVisible) return;
                try {
                    final String resp = nativeCall("PauseService", "[\"messaging\"]");
                } catch (Throwable t) {
                    Log.w(TAG, "failed to re-pause messaging after background send", t);
                }
            });
        } catch (java.util.concurrent.RejectedExecutionException ignored) {
            // service shutting down; nothing to re-pause
        }
    };

    /**
     * Asks the service to re-pause the "messaging" service after a flush window, coalescing
     * with any pending request. Called from background components after they Resume("messaging")
     * + send a message while the app is backgrounded. A real foreground/background transition
     * supersedes it (the pending callback is cancelled in applyUiVisibility, and the runnable
     * re-checks uiVisible anyway).
     */
    public static void scheduleMessagingRepause() {
        final StatusGoService s = sInstance;
        if (s == null) return;
        s.mainHandler.removeCallbacks(s.repauseMessagingRunnable);
        s.mainHandler.postDelayed(s.repauseMessagingRunnable, MESSAGING_REPAUSE_DELAY_MS);
    }

    private StatusNotificationManager notificationManager;

    static {
        // Loads libstatus_service.so (JNI wrapper that links real libstatus.so).
        System.loadLibrary("status_service");
    }

    private static native void nativeInit(StatusGoService self);
    private static native String nativeCall(String method, String argsJson);

    /** Exposes nativeCall for components in the same process (e.g. NotificationReplyReceiver). */
    public static String callRpc(String method, String argsJson) {
        return nativeCall(method, argsJson);
    }

    /**
     * Defense-in-depth: ensure only our own app UID can invoke Binder methods.
     *
     * Note: this service is also declared with android:exported="false" and a signature-level
     * permission in AndroidManifest.xml. This runtime check protects against accidental manifest
     * changes and makes the security property explicit at the IPC boundary.
     */
    private void enforceCallerIsSameApp() {
        final int callingUid = Binder.getCallingUid();
        final int myUid = getApplicationInfo() != null ? getApplicationInfo().uid : -1;
        if (callingUid != myUid) {
            throw new SecurityException("Unauthorized caller uid=" + callingUid);
        }
    }

    /** Called from native (status-go callback). */
    @SuppressWarnings("unused")
    private void onNativeSignal(String jsonSignal) {
        maybeStartForegroundFromSignal(jsonSignal);
        notificationManager.handleSignal(jsonSignal);

        final int n = listeners.beginBroadcast();
        try {
            for (int i = 0; i < n; i++) {
                try {
                    listeners.getBroadcastItem(i).onSignal(jsonSignal);
                } catch (RemoteException ignored) {
                    // RemoteCallbackList handles dead clients.
                }
            }
        } finally {
            listeners.finishBroadcast();
        }
    }

    private void maybeStartForegroundFromSignal(String jsonSignal) {
        if (jsonSignal == null || jsonSignal.isEmpty()) return;
        try {
            final JSONObject root = new JSONObject(jsonSignal);
            final String type = root.optString("type", "");
            if (type.isEmpty()) return;

            // On successful node login, keep this service as a foreground service so it survives
            // swipe-away from Recents.
            if ("node.login".equals(type)) {
                final JSONObject event = root.optJSONObject("event");
                if (event == null) return;
                if (!event.optString("error", "").isEmpty()) return;
                ensureForegroundStarted();
                return;
            }
        } catch (Throwable t) {
            // Best-effort only; don't crash the service.
        }
    }

    private void ensureForegroundStarted() {
        if (foregroundStarted) return;
        try {
            createNotificationChannel();
            startForeground(NOTIFICATION_ID, buildNotification());
            foregroundStarted = true;
        } catch (Throwable t) {
            // Best-effort only; don't crash service.
        }
    }

    private void maybeStopOnLogoutCall(String method, String respJson) {
        if (method == null) return;
        if (!method.equalsIgnoreCase("Logout")) return;
        if (respJson == null || respJson.isEmpty()) return;
        try {
            final JSONObject resp = new JSONObject(respJson);
            if (!resp.optString("error", "").isEmpty()) return;
            try {
                stopForeground(true);
            } catch (Throwable ignored) {}
            foregroundStarted = false;
            stopSelf();
        } catch (Throwable t) {
            // Best-effort only.
        }
    }

    // Services to pause when going to the background.
    // Messaging ("messaging") is intentionally excluded so push notifications keep working.
    /**
     * Fetches the names of all currently registered pausable services from status-go.
     * Returns null if the node is not running or the response cannot be parsed.
     */
    private String fetchPausableServiceNames() throws org.json.JSONException {
        final String response = nativeCall("PausableServices", "[]");
        if (response == null || response.isEmpty()) return null;
        final JSONArray services = new JSONArray(response);
        if (services.length() == 0) return null;
        final JSONArray names = new JSONArray();
        for (int i = 0; i < services.length(); i++) {
            names.put(services.getJSONObject(i).getString("name"));
        }
        return names.toString();
    }

    /**
     * Schedules PauseServices/ResumeServices calls on a dedicated single thread.
     * Uses a generation counter to coalesce rapid/piled-up calls: if a newer setUiVisible
     * arrives before an older one starts executing, the older one is skipped.
     *
     * The service list is fetched dynamically from PausableServices() so that any
     * service registered in status-go is automatically included without requiring
     * client-side changes.
     *
     * Waku light client receive is event-driven and independent of all registered
     * services — messages continue to arrive and be processed regardless of pause state.
     *
     * The nativeCall bridge expects argsJson as a JSON array of string arguments.
     * PauseServices/ResumeServices each take a single string parameter (a JSON-encoded
     * list of service names), so argsJson must be: ["<escaped-names-json>"].
     */
    private void scheduleBackendLifecycleUpdate(boolean visible) {
        final int gen = lifecycleGen.incrementAndGet();
        lifecycleExecutor.execute(() -> {
            if (lifecycleGen.get() != gen) return;
            try {
                final String namesJson = fetchPausableServiceNames();
                if (namesJson == null) return;
                final String method = visible ? "ResumeServices" : "PauseServices";
                final String argsJson = "[" + JSONObject.quote(namesJson) + "]";
                final String response = nativeCall(method, argsJson);
                if (response == null || response.isEmpty()) return;
                final JSONObject parsed = new JSONObject(response);
                final String error = parsed.optString("error", "");
                if (!error.isEmpty()) {
                    Log.w(TAG, method + " returned error: " + error);
                }
            } catch (Throwable t) {
                Log.w(TAG, "Failed to update backend lifecycle for UI visibility", t);
            }
        });
    }

    private void applyUiVisibility(boolean visible) {
        uiVisible = visible;
        // A real fg/bg transition handles messaging via scheduleBackendLifecycleUpdate;
        // drop any pending notification-driven re-pause so it can't fire stale.
        mainHandler.removeCallbacks(repauseMessagingRunnable);
        notificationManager.setUiVisible(visible);
        scheduleBackendLifecycleUpdate(visible);
    }

    private final IStatusGoService.Stub binder = new IStatusGoService.Stub() {
        @Override
        public RpcResponse rpcCall(String method, String argsJson) {
            enforceCallerIsSameApp();
            String resp = nativeCall(method, argsJson);
            if (resp == null) resp = "{\"error\":\"null response\"}";
            maybeStopOnLogoutCall(method, resp);

            final byte[] bytes = resp.getBytes(StandardCharsets.UTF_8);
            if (bytes.length < INLINE_THRESHOLD_BYTES) {
                return RpcResponse.inline(bytes);
            }

            SharedMemory shm = null;
            try {
                shm = SharedMemory.create("statusgo-rpc", bytes.length);
                final ByteBuffer buf = shm.mapReadWrite();
                try {
                    buf.put(bytes);
                } finally {
                    SharedMemory.unmap(buf);
                }
                shm.setProtect(OsConstants.PROT_READ);

                final RpcResponse result = RpcResponse.shared(shm);
                shm = null; // ownership transferred; closure happens in writeToParcel
                return result;
            } catch (Throwable t) {
                if (shm != null) shm.close();
                Log.w(TAG, "rpcCall: SharedMemory path failed; returning error JSON", t);
                return RpcResponse.inline(
                        "{\"error\":\"shared memory transfer failed\"}".getBytes(StandardCharsets.UTF_8));
            }
        }

        @Override
        public void registerSignalListener(IStatusGoSignalListener listener) {
            enforceCallerIsSameApp();
            if (listener == null) return;
            listeners.register(listener);
            // Reset uiVisible if the UI process dies unexpectedly (crash, OOM, force-stop).
            // RemoteCallbackList.unregister() calls unlinkToDeath internally, so clean
            // unregistration does not trigger this callback.
            try {
                listener.asBinder().linkToDeath(() -> applyUiVisibility(false), 0);
            } catch (RemoteException ignored) {
                // Binder already dead — notification suppression is not a concern.
            }
        }

        @Override
        public void unregisterSignalListener(IStatusGoSignalListener listener) {
            enforceCallerIsSameApp();
            if (listener != null) listeners.unregister(listener);
        }

        @Override
        public void setUiVisible(boolean visible) {
            enforceCallerIsSameApp();
            applyUiVisibility(visible);
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        sInstance = this;
        notificationManager = new StatusNotificationManager(this);
        PushNotificationHelper.initialize(this);
        nativeInit(this);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        final String action = intent != null ? intent.getAction() : null;
        if (ACTION_STOP.equals(action)) {
            try {
                stopForeground(true);
            } catch (Throwable ignored) {}
            foregroundStarted = false;
            stopSelf();
            return START_NOT_STICKY;
        }
        // Ensure we can be started from background components (e.g. FCM) without risking
        // ForegroundServiceDidNotStartInTime. We can downgrade/stop later if needed.
        ensureForegroundStarted();
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    @Override
    public void onDestroy() {
        sInstance = null;
        mainHandler.removeCallbacksAndMessages(null);
        StatusNotificationManager.clearInstance();
        listeners.kill();
        lifecycleExecutor.shutdownNow();
        super.onDestroy();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (nm == null) return;
        NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID,
                "Status background",
                NotificationManager.IMPORTANCE_LOW
        );
        ch.setDescription("Keeps Status background service running for messaging.");
        nm.createNotificationChannel(ch);
    }

    private Notification buildNotification() {
        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Status is running")
                .setContentText("Background service for messaging and notifications")
                .setSmallIcon(NOTIFICATION_SMALL_ICON)
                .setOngoing(true)
                .build();
    }
}
