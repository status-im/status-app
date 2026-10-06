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
import android.util.Log;

import androidx.core.app.NotificationCompat;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.Deque;
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

    public static final String ACTION_START =
            BuildConfig.APPLICATION_ID + ".ipc.StatusGoService.START";
    public static final String ACTION_STOP =
            BuildConfig.APPLICATION_ID + ".ipc.StatusGoService.STOP";

    private static final String CHANNEL_ID = "statusgo";
    private static final int NOTIFICATION_ID = 4242;

    /** App icon for notifications (Status logo, from status-logo-white.svg). */
    private static final int NOTIFICATION_SMALL_ICON = R.drawable.ic_notification_status_logo;

    private final RemoteCallbackList<IStatusGoSignalListener> listeners = new RemoteCallbackList<>();
    /** RemoteCallbackList broadcasts must never overlap. */
    private final Object signalDispatchLock = new Object();
    /**
     * Successful inline replies are initiated outside the UI process. Preserve their normal
     * send-response update until that process is visible and can consume it.
     */
    private final Object notificationReplyLock = new Object();
    private final Deque<String> pendingNotificationReplySignals = new ArrayDeque<>();
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
                    final String resp = callRpc("PauseService", "[\"messaging\"]");
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

    private final SignalTypeResolver signalTypes = new SignalTypeResolver(
            utf8 -> new JSONObject(decode(utf8)).optString("type", ""),
            message -> Log.w(TAG, message),
            android.os.SystemClock::elapsedRealtime,
            60_000L);

    static {
        // Loads libstatus_service.so (JNI wrapper that links real libstatus.so).
        System.loadLibrary("status_service");
    }

    private static native void nativeInit(StatusGoService self);

    /**
     * Calls status-go with a UTF-8 JSON array of string arguments. Returns a direct buffer over
     * the status-go-owned result (null if there is none) that must be released by nativeFree.
     */
    private static native ByteBuffer nativeCall(String method, byte[] argsUtf8);
    private static native ByteBuffer nativeCallDirect(String method, ByteBuffer argsUtf8, int length);
    private static native void nativeFree(ByteBuffer result);

    private static final String NULL_RESPONSE = "{\"error\":\"null response\"}";

    /** String convenience for in-process callers (e.g. NotificationReplyReceiver). */
    public static String callRpc(String method, String argsJson) {
        final ByteBuffer result = nativeCall(method, argsJson.getBytes(StandardCharsets.UTF_8));
        if (result == null) return NULL_RESPONSE;
        try {
            return StandardCharsets.UTF_8.decode(result).toString();
        } finally {
            nativeFree(result);
        }
    }

    /**
     * Queues the successful sendChatMessage JSON-RPC response from an Android
     * notification reply for normal frontend processing. The frontend's regular send path
     * consumes this response to update chat state; status-go does not emit messages.new for
     * locally initiated sends.
     */
    public static boolean publishNotificationReplyResult(String rpcResponseJson) {
        final StatusGoService service = sInstance;
        if (service == null || rpcResponseJson == null || rpcResponseJson.isEmpty()) return false;
        return service.publishNotificationReplyResultInternal(rpcResponseJson);
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

    /**
     * Called from native (status-go callback). {@code utf8} is a direct view of status-go's
     * signal memory and is only valid during this call; it must not be retained.
     */
    @SuppressWarnings("unused")
    private void onNativeSignal(ByteBuffer utf8) {
        if (utf8 == null) return;
        final String type = signalTypes.resolve(utf8);
        if (utf8.remaining() >= LARGE_SIGNAL_WARN_BYTES) {
            Log.w(TAG, "large status-go signal type=" + type + " sizeBytes=" + utf8.remaining());
        }

        String json = null;
        if ("node.login".equals(type)) {
            json = decode(utf8);
            maybeStartForegroundFromSignal(json);
        }
        if (notificationManager.wantsSignal(type)) {
            if (json == null) json = decode(utf8);
            notificationManager.handleSignal(type, json);
        }

        dispatchSignalToListeners(type, utf8);
    }

    private static String decode(ByteBuffer utf8) {
        return StandardCharsets.UTF_8.decode(utf8.duplicate()).toString();
    }

    /**
     * Sends a signal over the existing Binder transport. Returns how many listeners accepted
     * delivery, which lets notification replies remain queued until a UI listener is reachable.
     */
    private int dispatchSignalToListeners(String type, ByteBuffer utf8) {
        synchronized (signalDispatchLock) {
            final int n = listeners.beginBroadcast();
            try {
                return SignalFanout.deliver(utf8, SIGNAL_SHARED_MEMORY_THRESHOLD_BYTES, n,
                        i -> new SignalFanout.Listener<IpcPayload>() {
                            @Override
                            public void onInline(byte[] bytes) throws RemoteException {
                                listeners.getBroadcastItem(i).onSignal(bytes);
                            }

                            @Override
                            public void onShared(IpcPayload region) throws RemoteException {
                                listeners.getBroadcastItem(i).onSignalShm(region);
                            }
                        },
                        buf -> IpcPayload.shared(buf, "statusgo-signal"),
                        (i, t) -> Log.w(TAG, "failed to deliver signal to UI listener=" + i
                                + " type=" + type + " sizeBytes=" + utf8.remaining(), t));
            } finally {
                listeners.finishBroadcast();
            }
        }
    }

    private int dispatchSignalToListeners(String jsonSignal) {
        return dispatchSignalToListeners(SignalEnvelope.typeOf(jsonSignal),
                ByteBuffer.wrap(jsonSignal.getBytes(StandardCharsets.UTF_8)));
    }

    private boolean publishNotificationReplyResultInternal(String rpcResponseJson) {
        final String signal;
        try {
            JSONObject envelope = new JSONObject();
            envelope.put("type", "notification.reply.sent");
            envelope.put("event", new JSONObject(rpcResponseJson));
            signal = envelope.toString();
        } catch (Throwable t) {
            Log.w(TAG, "failed to create notification reply frontend signal", t);
            return false;
        }

        synchronized (notificationReplyLock) {
            if (!uiVisible || dispatchSignalToListeners(signal) == 0) {
                pendingNotificationReplySignals.addLast(signal);
            }
        }
        return true;
    }

    /** Flushes queued notification replies in FIFO order once the frontend is usable. */
    private void flushPendingNotificationReplySignals() {
        synchronized (notificationReplyLock) {
            while (uiVisible && !pendingNotificationReplySignals.isEmpty()) {
                if (dispatchSignalToListeners(pendingNotificationReplySignals.peekFirst()) == 0) {
                    return;
                }
                pendingNotificationReplySignals.removeFirst();
            }
        }
    }

    /** On successful node login, stay in the foreground so swipe-away from Recents is survived. */
    private void maybeStartForegroundFromSignal(String jsonSignal) {
        try {
            final JSONObject event = new JSONObject(jsonSignal).optJSONObject("event");
            if (event == null) return;
            if (!event.optString("error", "").isEmpty()) return;
            ensureForegroundStarted();
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

    private void maybeStopOnLogoutCall(String method, ByteBuffer respUtf8) {
        if (method == null) return;
        if (!method.equalsIgnoreCase("Logout")) return;
        if (!respUtf8.hasRemaining()) return;
        try {
            final JSONObject resp = new JSONObject(decode(respUtf8));
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
        final String response = callRpc("PausableServices", "[]");
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
                final String response = callRpc(method, argsJson);
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
                    final String resp = callRpc("ConnectionChange", argsJson);
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
        if (visible) flushPendingNotificationReplySignals();
    }

    private final IStatusGoService.Stub binder = new IStatusGoService.Stub() {
        @Override
        public IpcPayload rpcCall(String method, IpcPayload args) {
            enforceCallerIsSameApp();
            final ByteBuffer result;
            try (IpcPayload request = args) {
                if (request == null) {
                    result = nativeCall(method, null);
                } else {
                    final Object view = request.nativeView();
                    result = view instanceof byte[]
                            ? nativeCall(method, (byte[]) view)
                            : nativeCallDirect(method, (ByteBuffer) view, request.length());
                }
            } catch (Throwable t) {
                Log.w(TAG, "rpcCall: reading request failed", t);
                return IpcPayload.inline("{\"error\":\"request transfer failed\"}");
            }
            if (result == null) return IpcPayload.inline(NULL_RESPONSE);
            try {
                maybeStopOnLogoutCall(method, result);
                return IpcPayload.of(result, IpcPayload.INLINE_THRESHOLD_BYTES, "statusgo-rpc");
            } catch (Throwable t) {
                Log.w(TAG, "rpcCall: SharedMemory path failed; returning error JSON", t);
                return IpcPayload.inline("{\"error\":\"shared memory transfer failed\"}");
            } finally {
                nativeFree(result);
            }
        }

        @Override
        public void registerSignalListener(IStatusGoSignalListener listener) {
            enforceCallerIsSameApp();
            if (listener == null) return;
            listeners.register(listener);
            if (uiVisible) flushPendingNotificationReplySignals();
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
            // Mirrors the force-kill of the UI process in StatusQtActivity.onDestroy.
            android.os.Process.killProcess(android.os.Process.myPid());
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
