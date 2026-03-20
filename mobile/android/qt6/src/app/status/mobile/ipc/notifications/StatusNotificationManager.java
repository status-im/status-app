package app.status.mobile.ipc.notifications;

import android.app.Notification;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.app.Person;

import org.json.JSONObject;

import im.status.mobileui.PushNotificationHelper;

/**
 * Central orchestrator for Android local notifications.
 *
 * Receives status-go signals, decides whether to show/suppress notifications,
 * and delegates to {@link NotificationBuilder},
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
    private volatile boolean uiVisible = false;

    private static final class ActiveNotificationVisual {
        final String title;
        final Bitmap largeIcon;

        ActiveNotificationVisual(String title, Bitmap largeIcon) {
            this.title = title;
            this.largeIcon = largeIcon;
        }
    }

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
                clearManagedNotifications(ctx);
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
        final boolean isFromMe = eventWrap.optBoolean("isFromMe", false);

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

        // Mirrors status-go local_notifications.Notification.IsGroupConversation (not inferrable
        // from icons: group/community chats may have no custom avatar).
        final boolean isGroupConversation = eventWrap.optBoolean("isGroupConversation", false);
        final boolean isOneToOne = !isGroupConversation;

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
                senderIcon,
                isOneToOne,
                isFromMe
        );
    }

    // ── Show notification ─────────────────────────────────────────────────────

    private void showNotification(Context context, String title, String message,
            String deepLink, String conversationId, String notificationId,
            String largeIconUri, String category, long timestamp,
            String senderName, String personAvatarUri, boolean isOneToOne,
            boolean isFromMe) {
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
                notifIdInt = idBase.hashCode() & 0x7fffffff;
                final boolean hasContactIcon = largeIconUri != null && !largeIconUri.isEmpty();
                Bitmap largeIcon = hasContactIcon
                        ? NotificationIconHelper.parseToBitmap(largeIconUri)
                        : NotificationIconHelper.appIconBitmap(context, 256);
                String contactRequestId = notificationId != null ? notificationId : "";
                NotificationBuilder.postContactRequestNotification(
                        context, title, message, notifIdInt,
                        deepLink != null ? deepLink : "",
                        largeIcon, conversationId, contactRequestId);
                return;
            } else if (isMessage) {
                notifIdInt = conversationId.hashCode() & 0x7fffffff;
                // Rebuild message history from the currently active notification.
                List<NotificationBuilder.MessageEntry> messages =
                        getConversationMessagesFromActiveNotification(context, notifIdInt);
                final boolean conversationAlreadyActive = isNotificationActive(context, notifIdInt);
                ActiveNotificationVisual activeVisual = getActiveNotificationVisual(context, notifIdInt);
                String oneToOneContactTitle = isOneToOne
                        ? getOneToOneContactTitle(messages)
                        : null;
                messages.add(new NotificationBuilder.MessageEntry(
                        message,
                        timestamp,
                        senderName != null ? senderName : "",
                        personAvatarUri != null ? personAvatarUri : ""));
                while (messages.size() > NotificationCompat.MessagingStyle.MAXIMUM_RETAINED_MESSAGES) {
                    messages.remove(0);
                }
                if (isFromMe && !conversationAlreadyActive) return;
                String notificationTitle = (isOneToOne
                        && oneToOneContactTitle != null
                        && !oneToOneContactTitle.isEmpty())
                        ? oneToOneContactTitle
                        : ((activeVisual != null
                        && activeVisual.title != null
                        && !activeVisual.title.isEmpty())
                        ? activeVisual.title : title);
                final boolean hasMessageIcon =
                        largeIconUri != null && !largeIconUri.isEmpty();
                Bitmap largeIconFromEvent = hasMessageIcon
                        ? NotificationIconHelper.parseToBitmap(largeIconUri)
                        : NotificationIconHelper.appIconBitmap(context, 256);
                Bitmap largeIcon = activeVisual != null && activeVisual.largeIcon != null
                        ? activeVisual.largeIcon : largeIconFromEvent;
                NotificationBuilder.postMessageNotification(
                        context, notificationTitle, conversationId, notifIdInt,
                        deepLink, largeIcon, messages, isOneToOne);
            } else {
                String idBase = (notificationId != null ? notificationId
                        : (conversationId != null ? conversationId : title + message))
                        + "_" + timestamp;
                notifIdInt = idBase.hashCode() & 0x7fffffff;
                final boolean hasSimpleIcon = largeIconUri != null && !largeIconUri.isEmpty();
                Bitmap largeIcon = hasSimpleIcon
                        ? NotificationIconHelper.parseToBitmap(largeIconUri)
                        : NotificationIconHelper.appIconBitmap(context, 256);
                NotificationBuilder.postSimpleNotification(
                        context, title, message, notifIdInt,
                        deepLink, largeIcon, conversationId);
            }
        } catch (Throwable t) {
            Log.w(TAG, "showNotification failed", t);
        }
    }

    // ── Public API for NotificationReplyReceiver ──────────────────────────────

    /** Clears state for a conversation (called when notification dismissed). */
    public void clearConversation(String conversationId) {
        if (conversationId == null || conversationId.isEmpty()) return;
        Context context = contextRef.get();
        if (context == null) return;
        NotificationManagerCompat.from(context).cancel(conversationId.hashCode() & 0x7fffffff);
    }

    /**
     * Shows a "reply failed" notification.
     */
    public static void showReplyFailed(Context context) {
        NotificationBuilder.postReplyFailed(context);
    }

    private boolean isNotificationActive(Context context, int notificationId) {
        try {
            List<StatusBarNotification> active = NotificationManagerCompat.from(context)
                    .getActiveNotifications();
            for (StatusBarNotification sbn : active) {
                if (sbn.getId() == notificationId) {
                    return true;
                }
            }
        } catch (Throwable t) {
            Log.w(TAG, "isNotificationActive failed", t);
        }
        return false;
    }

    private List<NotificationBuilder.MessageEntry> getConversationMessagesFromActiveNotification(
            Context context, int notificationId) {
        List<NotificationBuilder.MessageEntry> messages = new ArrayList<>();
        try {
            List<StatusBarNotification> active = NotificationManagerCompat.from(context)
                    .getActiveNotifications();
            for (StatusBarNotification sbn : active) {
                if (sbn.getId() != notificationId) continue;
                Notification n = sbn.getNotification();
                NotificationCompat.MessagingStyle style =
                        NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(n);
                if (style == null) return messages;
                for (NotificationCompat.MessagingStyle.Message msg : style.getMessages()) {
                    Person sender = msg.getPerson();
                    messages.add(new NotificationBuilder.MessageEntry(
                            msg.getText() != null ? msg.getText().toString() : "",
                            msg.getTimestamp(),
                            sender != null && sender.getName() != null
                                    ? sender.getName().toString() : "",
                            ""));
                }
                return messages;
            }
        } catch (Throwable t) {
            Log.w(TAG, "getConversationMessagesFromActiveNotification failed", t);
        }
        return messages;
    }

    private ActiveNotificationVisual getActiveNotificationVisual(Context context, int notificationId) {
        try {
            List<StatusBarNotification> active = NotificationManagerCompat.from(context)
                    .getActiveNotifications();
            for (StatusBarNotification sbn : active) {
                if (sbn.getId() != notificationId) continue;
                Notification n = sbn.getNotification();
                if (n == null) return null;

                String title = null;
                NotificationCompat.MessagingStyle style =
                        NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(n);
                if (style != null && style.getConversationTitle() != null) {
                    title = style.getConversationTitle().toString();
                }
                if (n.extras != null) {
                    if (title == null || title.isEmpty()) {
                        CharSequence conversationTitleCs =
                                n.extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE);
                        if (conversationTitleCs != null) {
                            title = conversationTitleCs.toString();
                        }
                    }
                    if (title == null || title.isEmpty()) {
                        CharSequence titleCs = n.extras.getCharSequence(Notification.EXTRA_TITLE);
                        title = titleCs != null ? titleCs.toString() : null;
                    }
                }

                Bitmap largeIcon = null;
                if (n.extras != null) {
                    Object largeIconObj = n.extras.get(Notification.EXTRA_LARGE_ICON);
                    if (largeIconObj instanceof Bitmap) {
                        largeIcon = (Bitmap) largeIconObj;
                    }
                }
                if (largeIcon == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Icon notificationLargeIcon = n.getLargeIcon();
                    if (notificationLargeIcon != null) {
                        Drawable d = notificationLargeIcon.loadDrawable(context);
                        largeIcon = drawableToBitmap(d);
                    }
                }
                return new ActiveNotificationVisual(title, largeIcon);
            }
        } catch (Throwable t) {
            Log.w(TAG, "getActiveNotificationVisual failed", t);
        }
        return null;
    }

    private static Bitmap drawableToBitmap(Drawable drawable) {
        if (drawable == null) return null;
        int width = Math.max(1, drawable.getIntrinsicWidth());
        int height = Math.max(1, drawable.getIntrinsicHeight());
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
        drawable.draw(canvas);
        return bitmap;
    }

    private static String getOneToOneContactTitle(List<NotificationBuilder.MessageEntry> messages) {
        if (messages == null) return null;
        for (NotificationBuilder.MessageEntry entry : messages) {
            if (entry == null || entry.senderName == null || entry.senderName.isEmpty()) continue;
            if (!"You".equals(entry.senderName)) {
                return entry.senderName;
            }
        }
        return null;
    }

    private void clearManagedNotifications(Context context) {
        try {
            List<StatusBarNotification> active = NotificationManagerCompat.from(context)
                    .getActiveNotifications();
            NotificationManagerCompat nm = NotificationManagerCompat.from(context);
            for (StatusBarNotification sbn : active) {
                Notification n = sbn.getNotification();
                if (n != null && NotificationBuilder.CHANNEL_ID_MESSAGES.equals(n.getChannelId())) {
                    nm.cancel(sbn.getId());
                }
            }
        } catch (Throwable t) {
            Log.w(TAG, "clearManagedNotifications failed", t);
        }
    }
}
