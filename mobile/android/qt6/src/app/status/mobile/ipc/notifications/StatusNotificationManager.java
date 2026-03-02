package app.status.mobile.ipc.notifications;

import android.content.Context;
import android.graphics.Bitmap;
import android.os.Build;
import android.util.Log;

import java.lang.ref.WeakReference;
import java.util.List;

import org.json.JSONObject;

import im.status.mobileui.PushNotificationHelper;

/**
 * Central orchestrator for Android local notifications.
 *
 * Receives status-go signals, decides whether to show/suppress notifications,
 * and delegates to {@link NotificationBuilder}, {@link MessageBufferManager},
 * and {@link NotificationIconHelper} for the actual work.
 *
 * Initialized once by {@link app.status.mobile.ipc.StatusGoService#onCreate()};
 * accessible via {@link #getInstance()} for same-process components like
 * {@link app.status.mobile.ipc.NotificationReplyReceiver}.
 */
public final class StatusNotificationManager {
    private static final String TAG = "StatusNotificationManager";

    private static WeakReference<StatusNotificationManager> sInstanceRef;

    private final WeakReference<Context> contextRef;
    private final MessageBufferManager bufferManager = new MessageBufferManager();
    private volatile boolean uiVisible = false;

    public StatusNotificationManager(Context serviceContext) {
        this.contextRef = new WeakReference<>(serviceContext);
        sInstanceRef = new WeakReference<>(this);
    }

    /** Returns the singleton instance (set during service creation), or {@code null}. */
    public static StatusNotificationManager getInstance() {
        return sInstanceRef != null ? sInstanceRef.get() : null;
    }

    /** Clears the singleton reference (call from {@code Service.onDestroy()}). */
    public static void clearInstance() {
        sInstanceRef = null;
    }

    // ── UI visibility ─────────────────────────────────────────────────────────

    /** Updates UI-visible flag; clears all notifications when UI comes to foreground. */
    public void setUiVisible(boolean visible) {
        uiVisible = visible;
        if (visible) {
            Context ctx = contextRef.get();
            if (ctx != null) {
                bufferManager.clearAllAndCancelNotifications(ctx);
            }
        }
    }

    // ── Signal handling ───────────────────────────────────────────────────────

    /**
     * Processes a status-go signal JSON and shows an OS notification if appropriate.
     * Suppresses notifications when the UI is in the foreground.
     */
    public void handleSignal(String jsonSignal) {
        if (jsonSignal == null || jsonSignal.isEmpty()) return;
        try {
            final JSONObject root = new JSONObject(jsonSignal);
            final String type = root.optString("type", "");

            // Suppress OS notifications when app is in foreground
            if (uiVisible) return;

            final JSONObject eventWrap = root.optJSONObject("event");
            if (eventWrap == null) return;

            if ("local-notifications".equals(type)) {
                handleLocalNotification(eventWrap);
            }
        } catch (Throwable t) {
            Log.w(TAG, "handleSignal failed", t);
        }
    }

    private void handleLocalNotification(JSONObject eventWrap) {
        if (eventWrap.optBoolean("deleted", false)) return;

        Context context = contextRef.get();
        if (context == null) return;
        if (!PushNotificationHelper.areNotificationsEnabled(context)) return;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && !PushNotificationHelper.hasNotificationPermission(context)) return;

        // Parse notification fields
        final String displayTitle = eventWrap.optString("displayTitle", "");
        final String displayMessage = eventWrap.optString("displayMessage", "");
        final String title = !displayTitle.isEmpty() ? displayTitle
                : eventWrap.optString("title", "");
        final String message = !displayMessage.isEmpty() ? displayMessage
                : eventWrap.optString("message", "");
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

        // Normalize timestamp (status-go may send Unix seconds)
        long ts = eventWrap.optLong("timestamp", System.currentTimeMillis());
        if (ts > 0 && ts < 1_000_000_000_000L) ts *= 1000;
        final long timestamp = ts > 0 ? ts : System.currentTimeMillis();

        // Pick large icon by category
        String largeIconUri = NotificationIconHelper.pickLargeIconUri(
                category, communityIcon, chatIcon, senderIcon);

        showNotification(
                context,
                title.isEmpty() ? "Status" : title,
                message,
                deepLink.isEmpty() ? null : deepLink,
                conversationId.isEmpty() ? null : conversationId,
                notificationId.isEmpty() ? null : notificationId,
                largeIconUri != null && !largeIconUri.isEmpty() ? largeIconUri : null,
                category,
                timestamp,
                senderName,
                senderIcon
        );
    }

    // ── Show notification ─────────────────────────────────────────────────────

    private void showNotification(Context context, String title, String message,
            String deepLink, String conversationId, String notificationId,
            String largeIconUri, String category, long timestamp,
            String senderName, String personAvatarUri) {
        try {
            NotificationBuilder.createMessagesChannel(context);

        final boolean isContactRequest = "contactRequest".equals(category);
        final boolean isMessage = "newMessage".equals(category)
                && conversationId != null && !conversationId.isEmpty()
                && !isContactRequest;

            // Compute stable notification ID
            final int notifIdInt;
            if (isContactRequest) {
                String idBase = (notificationId != null ? notificationId
                        : (conversationId != null ? conversationId : title + message))
                        + "_" + timestamp;
                notifIdInt = Math.abs(idBase.hashCode());
                Bitmap largeIcon = NotificationIconHelper.parseToBitmap(largeIconUri);
                String contactRequestId = notificationId != null ? notificationId : "";
                NotificationBuilder.postContactRequestNotification(
                        context, title, message, notifIdInt,
                        deepLink != null ? deepLink : "",
                        largeIcon, conversationId, contactRequestId);
                bufferManager.trackNotification(notifIdInt);
                return;
            } else if (isMessage) {
                notifIdInt = Math.abs(conversationId.hashCode());
                bufferManager.addMessage(conversationId, message, timestamp,
                        senderName, personAvatarUri);
                bufferManager.putMeta(conversationId, title, deepLink, largeIconUri);
            } else {
                String idBase = (notificationId != null ? notificationId
                        : (conversationId != null ? conversationId : title + message))
                        + "_" + timestamp;
                notifIdInt = Math.abs(idBase.hashCode());
            }

            Bitmap largeIcon = NotificationIconHelper.parseToBitmap(largeIconUri);

            if (isMessage) {
                List<MessageBufferManager.MessageEntry> messages =
                        bufferManager.getMessages(conversationId);
                NotificationBuilder.postMessageNotification(
                        context, title, conversationId, notifIdInt,
                        deepLink, largeIcon, messages);
            } else {
                NotificationBuilder.postSimpleNotification(
                        context, title, message, notifIdInt,
                        deepLink, largeIcon, conversationId);
            }

            bufferManager.trackNotification(notifIdInt);
        } catch (Throwable t) {
            Log.w(TAG, "showNotification failed", t);
        }
    }

    // ── Public API for NotificationReplyReceiver ──────────────────────────────

    /** Clears message buffer for a conversation (called when notification dismissed). */
    public void clearConversation(String conversationId) {
        bufferManager.clearConversation(conversationId);
    }

    /**
     * Shows a "reply failed" notification.
     */
    public static void showReplyFailed(Context context) {
        NotificationBuilder.postReplyFailed(context);
    }

    /**
     * Appends the user's reply to the buffer and refreshes the notification
     * to include the sent message in the conversation history.
     */
    public void appendReplyAndRefresh(Context context, String conversationId,
            String replyText, int androidNotificationId) {
        if (context == null || conversationId == null || conversationId.isEmpty()
                || replyText == null || replyText.trim().isEmpty()) return;
        try {
            bufferManager.addReply(conversationId, replyText);
            MessageBufferManager.ConversationMeta meta = bufferManager.getMeta(conversationId);
            if (meta == null) return;
            List<MessageBufferManager.MessageEntry> messages =
                    bufferManager.getMessages(conversationId);
            NotificationBuilder.refreshMessageNotification(
                    context, conversationId, androidNotificationId, meta, messages);
        } catch (Throwable t) {
            Log.w(TAG, "appendReplyAndRefresh failed", t);
        }
    }
}
