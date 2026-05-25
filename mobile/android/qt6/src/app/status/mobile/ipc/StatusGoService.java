package app.status.mobile.ipc;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
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
    private static final int LARGE_SIGNAL_WARN_BYTES = 256 * 1024;
    private static final int SIGNAL_SHARED_MEMORY_THRESHOLD_BYTES = 128 * 1024;

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

    /**
     * Native network connectivity monitoring. On Android the status-go lib runs in this
     * process; the QML NetworkChecker path (which lives in the killable/pausable UI
     * process) is a no-op here, so we observe connectivity natively and push it into
     * status-go via the ConnectionChange RPC.
     */
    private ConnectivityManager connectivityManager;
    private ConnectivityManager.NetworkCallback networkCallback;
    /** Last (type|expensive) sent to status-go. Accessed only on the lifecycleExecutor thread. */
    private String lastConnectionKey = null;

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
        final int signalSizeBytes = jsonSignal != null
                ? jsonSignal.getBytes(StandardCharsets.UTF_8).length
                : 0;
        final String signalType = getSignalType(jsonSignal);
        if (signalSizeBytes >= LARGE_SIGNAL_WARN_BYTES) {
            Log.w(TAG, "large status-go signal type=" + signalType
                    + " sizeBytes=" + signalSizeBytes);
        }

        maybeStartForegroundFromSignal(jsonSignal);
        notificationManager.handleSignal(jsonSignal);

        final int n = listeners.beginBroadcast();
        final boolean useSharedMemorySignal = signalSizeBytes >= SIGNAL_SHARED_MEMORY_THRESHOLD_BYTES;
        try {
            for (int i = 0; i < n; i++) {
                try {
                    final IStatusGoSignalListener listener = listeners.getBroadcastItem(i);
                    if (useSharedMemorySignal) {
                        final byte[] signalBytes = jsonSignal != null
                                ? jsonSignal.getBytes(StandardCharsets.UTF_8)
                                : new byte[0];
                        try (RpcResponse signalResponse = sharedPayload(signalBytes, "statusgo-signal")) {
                            listener.onSignalShm(signalResponse);
                        }
                    } else {
                        listener.onSignal(jsonSignal);
                    }
                } catch (RemoteException e) {
                    Log.w(TAG, "failed to deliver signal to UI listener type=" + signalType
                            + " sizeBytes=" + signalSizeBytes, e);
                } catch (RuntimeException e) {
                    Log.w(TAG, "runtime failure delivering signal to UI listener type=" + signalType
                            + " sizeBytes=" + signalSizeBytes, e);
                } catch (Throwable e) {
                    Log.w(TAG, "unexpected failure delivering signal to UI listener type=" + signalType
                            + " sizeBytes=" + signalSizeBytes, e);
                }
            }
        } finally {
            listeners.finishBroadcast();
        }
    }

    private RpcResponse sharedPayload(byte[] bytes, String namePrefix) throws android.system.ErrnoException {
        SharedMemory shm = null;
        try {
            shm = SharedMemory.create(namePrefix, bytes.length);
            final ByteBuffer buf = shm.mapReadWrite();
            try {
                buf.put(bytes);
            } finally {
                SharedMemory.unmap(buf);
            }
            shm.setProtect(OsConstants.PROT_READ);
            final RpcResponse result = RpcResponse.shared(shm);
            shm = null;
            return result;
        } finally {
            if (shm != null) shm.close();
        }
    }

    private String getSignalType(String jsonSignal) {
        if (jsonSignal == null || jsonSignal.isEmpty()) return "";
        try {
            return new JSONObject(jsonSignal).optString("type", "");
        } catch (Throwable t) {
            return "";
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

    /**
     * Observes the default network and pushes connectivity state into status-go.
     *
     * onCapabilitiesChanged fires immediately on registration for the current network and
     * again on every capability change; onLost fires when the (single) default network is
     * gone. onAvailable is not overridden — onCapabilitiesChanged always follows it and
     * carries the data we need.
     */
    private final class NetworkConnectivityCallback extends ConnectivityManager.NetworkCallback {
        @Override
        public void onCapabilitiesChanged(Network network, NetworkCapabilities caps) {
            dispatchConnectionChange(typeFromCapabilities(caps), meteredFromCapabilities(caps));
        }

        @Override
        public void onLost(Network network) {
            dispatchConnectionChange("none", false);
        }
    }

    /** Maps Android transports to a status-go connection type ("wifi"/"cellular"/"unknown"). */
    private static String typeFromCapabilities(NetworkCapabilities caps) {
        if (caps == null) return "unknown";
        // VPN networks normally retain the underlying transport bits, so checking the real
        // transports first classifies VPN-over-wifi/cellular correctly. Wi-Fi takes priority
        // over cellular so a Wi-Fi+VPN combo is never mislabeled.
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return "wifi";
        // status-go has no ethernet type; "wifi" is the closest fast/non-expensive class.
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) return "wifi";
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) return "cellular";
        return "unknown";
    }

    /** A network is "expensive" (metered) when it lacks the NOT_METERED capability. */
    private static boolean meteredFromCapabilities(NetworkCapabilities caps) {
        if (caps == null) return false;
        return !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED);
    }

    /**
     * Serializes a ConnectionChange RPC onto lifecycleExecutor (the JNI-call thread),
     * de-duplicating so status-go only sees calls when (type, expensive) actually changed.
     * De-dup matters: onCapabilitiesChanged fires often for capability churn that does not
     * change the pair, and each offline->online transition triggers a hystrix.Flush() in
     * status-go.
     */
    private void dispatchConnectionChange(String type, boolean expensive) {
        final String key = type + "|" + expensive;
        try {
            lifecycleExecutor.execute(() -> {
                if (key.equals(lastConnectionKey)) return;
                try {
                    final JSONObject payload = new JSONObject();
                    payload.put("type", type);
                    payload.put("expensive", expensive);
                    // nativeCall expects a JSON array of string args; ConnectionChange takes
                    // a single JSON-object string.
                    final String argsJson = "[" + JSONObject.quote(payload.toString()) + "]";
                    Log.d(TAG, "ConnectionChange args: " + argsJson);
                    final String resp = nativeCall("ConnectionChange", argsJson);
                    lastConnectionKey = key; // only on success, so a transient failure can retry
                    if (resp != null && !resp.isEmpty()) {
                        final String err = new JSONObject(resp).optString("error", "");
                        if (!err.isEmpty()) Log.w(TAG, "ConnectionChange returned error: " + err);
                    }
                } catch (Throwable t) {
                    Log.w(TAG, "Failed to push ConnectionChange to status-go", t);
                }
            });
        } catch (java.util.concurrent.RejectedExecutionException ignored) {
            // service shutting down; nothing to push
        }
    }

    /**
     * Registers a default-network callback. registerDefaultNetworkCallback delivers the
     * current network's onCapabilitiesChanged immediately, which — together with StartNode
     * re-applying the stored connection state — seeds status-go with connectivity at start.
     */
    private void registerNetworkCallback() {
        try {
            connectivityManager =
                    (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
            if (connectivityManager == null) {
                Log.w(TAG, "ConnectivityManager unavailable; network monitoring disabled");
                return;
            }
            networkCallback = new NetworkConnectivityCallback();
            connectivityManager.registerDefaultNetworkCallback(networkCallback);
        } catch (Throwable t) {
            // e.g. RuntimeException("TOO_MANY_REQUESTS"); best-effort only.
            Log.w(TAG, "Failed to register network callback", t);
            networkCallback = null;
        }
    }

    private void unregisterNetworkCallback() {
        if (connectivityManager != null && networkCallback != null) {
            try {
                connectivityManager.unregisterNetworkCallback(networkCallback);
            } catch (Throwable t) {
                Log.w(TAG, "Failed to unregister network callback", t);
            }
        }
        networkCallback = null;
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
        registerNetworkCallback();
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
        unregisterNetworkCallback();
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
