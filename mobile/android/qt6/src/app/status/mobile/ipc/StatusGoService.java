package app.status.mobile.ipc;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import android.os.RemoteCallbackList;
import android.os.RemoteException;
import android.util.Log;

import androidx.core.app.NotificationCompat;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

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

    public static final String ACTION_START = "app.status.mobile.ipc.StatusGoService.START";
    public static final String ACTION_STOP = "app.status.mobile.ipc.StatusGoService.STOP";

    private static final String CHANNEL_ID = "statusgo";
    private static final int NOTIFICATION_ID = 4242;

    /** Status logo as notification icon (ic_launcher_monochrome is white/alpha for tinting). */
    private static final int NOTIFICATION_SMALL_ICON = R.mipmap.ic_launcher_monochrome;

    private final RemoteCallbackList<IStatusGoSignalListener> listeners = new RemoteCallbackList<>();
    private volatile boolean foregroundStarted = false;

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

    private final IStatusGoService.Stub binder = new IStatusGoService.Stub() {
        @Override
        public String call(String method, String argsJson) {
            enforceCallerIsSameApp();
            String resp = nativeCall(method, argsJson);
            maybeStopOnLogoutCall(method, resp);
            return resp;
        }

        @Override
        public String callToFile(String method, String argsJson) {
            enforceCallerIsSameApp();
            String resp = nativeCall(method, argsJson);
            if (resp == null) resp = "{\"error\":\"null response\"}";
            maybeStopOnLogoutCall(method, resp);
            try {
                File f = File.createTempFile("statusgo_", ".json", getCacheDir());
                try (FileOutputStream os = new FileOutputStream(f, false)) {
                    os.write(resp.getBytes(StandardCharsets.UTF_8));
                }
                return f.getAbsolutePath();
            } catch (Throwable t) {
                Log.w(TAG, "callToFile failed", t);
                return "{\"error\":\"callToFile failed\"}";
            }
        }

        @Override
        public void registerSignalListener(IStatusGoSignalListener listener) {
            enforceCallerIsSameApp();
            if (listener != null) listeners.register(listener);
        }

        @Override
        public void unregisterSignalListener(IStatusGoSignalListener listener) {
            enforceCallerIsSameApp();
            if (listener != null) listeners.unregister(listener);
        }

        @Override
        public void setUiVisible(boolean visible) {
            enforceCallerIsSameApp();
            notificationManager.setUiVisible(visible);
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
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
        StatusNotificationManager.clearInstance();
        listeners.kill();
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
