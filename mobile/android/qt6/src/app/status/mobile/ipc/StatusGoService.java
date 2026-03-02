package app.status.mobile.ipc;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.net.Uri;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import android.os.RemoteCallbackList;
import android.os.RemoteException;
import android.util.Base64;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.app.Person;
import androidx.core.app.RemoteInput;
import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.core.graphics.drawable.IconCompat;

import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

import app.status.mobile.R;
import im.status.mobileui.PushNotificationHelper;

/**
 * Separate-process status-go host.
 *
 * Runs in its own Android process (see AndroidManifest.xml) and is intended to be the
 * only process that links/uses the real libstatus.so. UI process talks to it over Binder.
 */
public final class StatusGoService extends Service {
    private static final String TAG = "StatusGoService";

    public static final String ACTION_START = "app.status.mobile.ipc.StatusGoService.START";
    public static final String ACTION_STOP = "app.status.mobile.ipc.StatusGoService.STOP";

    private static final String CHANNEL_ID = "statusgo";
    private static final String CHANNEL_ID_MESSAGES = "statusgo-messages";
    private static final int NOTIFICATION_ID = 4242;

    private static final int MAX_BUFFERED_MESSAGES = 5;

    /** Buffered messages per conversation for MessagingStyle. Key: conversationId. */
    private final Map<String, LinkedList<MessageEntry>> messageBuffer = new ConcurrentHashMap<>();

    private final RemoteCallbackList<IStatusGoSignalListener> listeners = new RemoteCallbackList<>();
    private volatile boolean foregroundStarted = false;
    private volatile boolean uiVisible = false;
    private volatile long uiVisibleLastUpdateMs = 0L;

    private static final class MessageEntry {
        final String text;
        final long timestamp;
        final String senderName;
        final String senderIconUri;

        MessageEntry(String text, long timestamp, String senderName, String senderIconUri) {
            this.text = text;
            this.timestamp = timestamp;
            this.senderName = senderName;
            this.senderIconUri = senderIconUri;
        }
    }

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
        maybeShowOsNotificationFromSignal(jsonSignal);

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

    /**
     * Show OS notifications from the service process.
     *
     * This is required to deliver OS notifications when the UI process is killed.
     * We suppress notifications when the UI is in foreground (uiVisible=true).
     * Handles "local-notifications" signals from status-go (new messages, group invites, etc.).
     */
    private void maybeShowOsNotificationFromSignal(String jsonSignal) {
        if (jsonSignal == null || jsonSignal.isEmpty()) return;
        try {
            final JSONObject root = new JSONObject(jsonSignal);
            final String type = root.optString("type", "");

            if (uiVisible) {
                final long now = System.currentTimeMillis();
                if (uiVisibleLastUpdateMs > 0 && (now - uiVisibleLastUpdateMs) < 5000) return;
            }

            final JSONObject eventWrap = root.optJSONObject("event");
            if (eventWrap == null) return;

            if ("local-notifications".equals(type)) {
                if (eventWrap.optBoolean("deleted", false)) return;
                final String displayTitle = eventWrap.optString("displayTitle", "");
                final String displayMessage = eventWrap.optString("displayMessage", "");
                final String title = !displayTitle.isEmpty() ? displayTitle : eventWrap.optString("title", "");
                final String message = !displayMessage.isEmpty() ? displayMessage : eventWrap.optString("message", "");
                final String deepLink = eventWrap.optString("deepLink", "");
                final String conversationId = eventWrap.optString("conversationId", "");
                final String notificationId = eventWrap.optString("id", "");
                final String category = eventWrap.optString("category", "");
                final String communityIcon = eventWrap.optString("communityIcon", "");
                final String chatIcon = eventWrap.optString("chatIcon", "");
                String senderIcon = "";
                String senderName = "";
                final JSONObject author = eventWrap.optJSONObject("notificationAuthor");
                if (author != null) {
                    senderIcon = author.optString("icon", "");
                    senderName = author.optString("name", "");
                }
                // status-go may send Unix timestamp in seconds; MessagingStyle expects ms
                long ts = eventWrap.optLong("timestamp", System.currentTimeMillis());
                if (ts > 0 && ts < 1_000_000_000_000L) ts *= 1000;
                final long timestamp = ts > 0 ? ts : System.currentTimeMillis();

                // Pick large icon by category: community > chat/group > sender
                String largeIconUri = pickLargeIconUri(category, communityIcon, chatIcon, senderIcon);
                showLocalNotification(
                    title.isEmpty() ? "Status" : title,
                    message,
                    deepLink.isEmpty() ? null : deepLink,
                    conversationId.isEmpty() ? null : conversationId,
                    notificationId.isEmpty() ? null : notificationId,
                    largeIconUri != null && !largeIconUri.isEmpty() ? largeIconUri : null,
                    category,
                    senderName,
                    timestamp,
                    senderIcon
                );
                return;
            }
        } catch (Throwable t) {
            Log.w(TAG, "maybeShowOsNotificationFromSignal failed", t);
        }
    }

    /** Key for RemoteInput reply text. */
    public static final String REPLY_REMOTE_INPUT_KEY = "reply_text";
    /** Action for inline reply from notification. */
    public static final String ACTION_REPLY = "app.status.mobile.ipc.NOTIFICATION_REPLY";

    /**
     * Display an Android local notification from the service process.
     * For newMessage with conversationId: uses MessagingStyle with buffered messages.
     * For other categories: uses BigTextStyle.
     */
    private void showLocalNotification(String title, String message, String deepLink,
            String conversationId, String notificationId, String senderIconUri, String category,
            String senderName, long timestamp, String senderIconUriForPerson) {
        try {
            if (!PushNotificationHelper.areNotificationsEnabled(this)) return;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                    && !PushNotificationHelper.hasNotificationPermission(this)) return;

            createMessagesNotificationChannel();

            Intent intent;
            if (deepLink != null && !deepLink.isEmpty()) {
                intent = new Intent(Intent.ACTION_VIEW, Uri.parse(deepLink));
            } else {
                intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
            }
            if (intent == null) return;

            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            intent.setPackage(getPackageName());

            final boolean useMessagingStyle = "newMessage".equals(category)
                    && conversationId != null && !conversationId.isEmpty();

            // For MessagingStyle: stable ID per conversation so we update one notification.
            // For other notifications: unique ID per event.
            final int notificationIdInt;
            if (useMessagingStyle) {
                notificationIdInt = Math.abs(conversationId.hashCode());
                // Add to buffer and trim
                messageBuffer.computeIfAbsent(conversationId, k -> new LinkedList<>())
                    .add(new MessageEntry(message, timestamp,
                            senderName != null ? senderName : "",
                            senderIconUriForPerson != null ? senderIconUriForPerson : ""));
                LinkedList<MessageEntry> buffer = messageBuffer.get(conversationId);
                while (buffer.size() > MAX_BUFFERED_MESSAGES) buffer.removeFirst();
            } else {
                notificationIdInt = Math.abs((notificationId != null ? notificationId
                        : (conversationId != null ? conversationId : title + message)).hashCode());
            }

            PendingIntent pendingIntent = PendingIntent.getActivity(
                this,
                notificationIdInt,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            Bitmap largeIcon = parseSenderIconToBitmap(senderIconUri);

            NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID_MESSAGES)
                .setSmallIcon(getApplicationInfo().icon)
                .setContentTitle(title)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent);
            if (largeIcon != null) builder.setLargeIcon(largeIcon);

            if (useMessagingStyle) {
                buildMessagingStyle(builder, title, conversationId);
                // Android 11+: use conversation shortcut so avatar shows in collapsed view.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && largeIcon != null) {
                    String shortcutId = "conv_" + conversationId;
                    pushConversationShortcut(shortcutId, title, largeIcon, intent);
                    builder.setShortcutId(shortcutId);
                }
            } else {
                builder.setContentText(message)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(message));
            }

            // Add Reply action for message notifications
            if (useMessagingStyle) {
                RemoteInput remoteInput = new RemoteInput.Builder(REPLY_REMOTE_INPUT_KEY)
                    .setLabel(getString(R.string.notification_reply))
                    .build();
                Intent replyIntent = new Intent(this, NotificationReplyReceiver.class);
                replyIntent.setAction(ACTION_REPLY);
                replyIntent.setPackage(getPackageName());
                replyIntent.putExtra("conversationId", conversationId);
                replyIntent.putExtra("notificationId", notificationId != null ? notificationId : "");
                replyIntent.putExtra("androidNotificationId", notificationIdInt);
                int replyFlags = PendingIntent.FLAG_UPDATE_CURRENT;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    replyFlags |= PendingIntent.FLAG_MUTABLE;
                }
                PendingIntent replyPendingIntent = PendingIntent.getBroadcast(
                    this,
                    notificationIdInt,
                    replyIntent,
                    replyFlags
                );
                NotificationCompat.Action replyAction = new NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_send,
                    getString(R.string.notification_reply),
                    replyPendingIntent
                ).addRemoteInput(remoteInput).build();
                builder.addAction(replyAction);
            }

            if (conversationId != null && !conversationId.isEmpty()) {
                builder.setGroup("conv_" + conversationId);
            }

            NotificationManagerCompat.from(this).notify(notificationIdInt, builder.build());
        } catch (Throwable t) {
            Log.w(TAG, "showLocalNotification failed", t);
        }
    }

    private void buildMessagingStyle(NotificationCompat.Builder builder, String conversationTitle,
            String conversationId) {
        List<MessageEntry> messages = messageBuffer.get(conversationId);
        if (messages == null || messages.isEmpty()) return;

        Person me = new Person.Builder().setName("Me").build();
        NotificationCompat.MessagingStyle style = new NotificationCompat.MessagingStyle(me)
            .setConversationTitle(conversationTitle);

        Set<String> senderNames = new HashSet<>();
        for (MessageEntry entry : messages) {
            Person sender = null;
            if (entry.senderName != null && !entry.senderName.isEmpty()) {
                senderNames.add(entry.senderName);
                Person.Builder personBuilder = new Person.Builder().setName(entry.senderName);
                if (entry.senderIconUri != null && !entry.senderIconUri.isEmpty()) {
                    Bitmap avatar = parseSenderIconToBitmap(entry.senderIconUri);
                    if (avatar != null) {
                        personBuilder.setIcon(IconCompat.createWithBitmap(avatar));
                    }
                }
                sender = personBuilder.build();
            }
            style.addMessage(entry.text, entry.timestamp, sender);
        }
        if (senderNames.size() > 1) {
            style.setGroupConversation(true);
        }

        MessageEntry latest = messages.get(messages.size() - 1);
        builder.setContentText(latest.text)
            .setStyle(style);
    }

    /**
     * Pushes a long-lived dynamic shortcut for the conversation so the collapsed
     * MessagingStyle notification shows the contact avatar (via setShortcutId).
     * ShortcutManagerCompat.pushDynamicShortcut handles the 5-shortcut limit.
     */
    private void pushConversationShortcut(String shortcutId, String shortLabel,
            Bitmap icon, Intent intent) {
        try {
            ShortcutInfoCompat shortcut = new ShortcutInfoCompat.Builder(this, shortcutId)
                .setLongLived(true)
                .setShortLabel(shortLabel)
                .setIcon(IconCompat.createWithBitmap(icon))
                .setIntent(intent != null ? intent : getPackageManager().getLaunchIntentForPackage(getPackageName()))
                .build();
            ShortcutManagerCompat.pushDynamicShortcut(this, shortcut);
        } catch (Throwable t) {
            Log.w(TAG, "pushConversationShortcut failed", t);
        }
    }

    /**
     * Picks the large icon URI by notification category.
     * Community notifications: community icon preferred, fallback to sender.
     * Group chat/invite: group/chat icon preferred, fallback to sender.
     * 1-1 and contact request: sender icon.
     */
    private String pickLargeIconUri(String category, String communityIcon, String chatIcon, String senderIcon) {
        switch (category) {
            case "communityRequestToJoin":
            case "communityJoined":
                return !communityIcon.isEmpty() ? communityIcon : (!senderIcon.isEmpty() ? senderIcon : null);
            case "groupInvite":
                return !chatIcon.isEmpty() ? chatIcon : (!senderIcon.isEmpty() ? senderIcon : null);
            case "newMessage":
                // For messages: community chat -> community icon; group -> chat icon; 1-1 -> sender
                if (!communityIcon.isEmpty()) return communityIcon;
                if (!chatIcon.isEmpty()) return chatIcon;
                return !senderIcon.isEmpty() ? senderIcon : null;
            default:
                return !senderIcon.isEmpty() ? senderIcon : null;
        }
    }

    /** Decodes icon from data URI (data:image/...;base64,...) to Bitmap for large icon. */
    private Bitmap parseSenderIconToBitmap(String iconUri) {
        if (iconUri == null || iconUri.isEmpty()) return null;
        try {
            if (iconUri.startsWith("data:")) {
                int comma = iconUri.indexOf(',');
                if (comma < 0) return null;
                byte[] bytes = Base64.decode(iconUri.substring(comma + 1), Base64.DEFAULT);
                Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                if (bitmap == null) return null;
                int maxSize = 256;
                if (bitmap.getWidth() > maxSize || bitmap.getHeight() > maxSize) {
                    float scale = Math.min((float) maxSize / bitmap.getWidth(),
                            (float) maxSize / bitmap.getHeight());
                    int w = Math.round(bitmap.getWidth() * scale);
                    int h = Math.round(bitmap.getHeight() * scale);
                    Bitmap scaled = Bitmap.createScaledBitmap(bitmap, w, h, true);
                    if (bitmap != scaled) bitmap.recycle();
                    bitmap = scaled;
                }
                return makeBitmapCircular(bitmap);
            }
        } catch (Throwable t) {
            Log.w(TAG, "parseSenderIconToBitmap failed", t);
        }
        return null;
    }

    /** Crops to circle so opaque sources (JPEG) render as true circles with transparent corners. */
    private Bitmap makeBitmapCircular(Bitmap source) {
        if (source == null) return null;
        int size = Math.min(source.getWidth(), source.getHeight());
        if (size <= 0) return source;
        Bitmap output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        output.eraseColor(Color.TRANSPARENT);
        Canvas canvas = new Canvas(output);
        Path circle = new Path();
        circle.addCircle(size / 2f, size / 2f, size / 2f, Path.Direction.CW);
        canvas.clipPath(circle);
        int srcX = (source.getWidth() - size) / 2;
        int srcY = (source.getHeight() - size) / 2;
        Rect src = new Rect(srcX, srcY, srcX + size, srcY + size);
        Rect dst = new Rect(0, 0, size, size);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        canvas.drawBitmap(source, src, dst, paint);
        if (source != output) source.recycle();
        return output;
    }

    private void createMessagesNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (nm == null) return;
        NotificationChannel ch = new NotificationChannel(
            CHANNEL_ID_MESSAGES,
            "Messages",
            NotificationManager.IMPORTANCE_DEFAULT
        );
        ch.setDescription("Chat and community notifications");
        ch.enableVibration(true);
        nm.createNotificationChannel(ch);
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
            uiVisible = visible;
            uiVisibleLastUpdateMs = visible ? System.currentTimeMillis() : 0L;
            if (visible) {
                messageBuffer.clear();
            }
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
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
                .setSmallIcon(android.R.drawable.stat_notify_chat)
                .setOngoing(true)
                .build();
    }
}

