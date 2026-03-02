package app.status.mobile.ipc.notifications;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.app.Person;
import androidx.core.app.RemoteInput;
import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.core.graphics.drawable.IconCompat;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import app.status.mobile.R;
import app.status.mobile.ipc.NotificationReplyReceiver;

/**
 * Builds Android {@link android.app.Notification} objects for the various
 * notification types used by Status.
 *
 * This class is stateless — it receives all data as parameters and returns
 * built notifications or posts them directly. It owns no buffers or caches.
 */
public final class NotificationBuilder {
    private static final String TAG = "NotificationBuilder";

    static final String CHANNEL_ID_MESSAGES = "statusgo-messages";

    /** Key for RemoteInput reply text. */
    public static final String REPLY_REMOTE_INPUT_KEY = "reply_text";
    /** Action for inline reply from notification. */
    public static final String ACTION_REPLY = "app.status.mobile.ipc.NOTIFICATION_REPLY";
    /** Action when notification dismissed (swipe/cancel). */
    public static final String ACTION_DISMISS = "app.status.mobile.ipc.NOTIFICATION_DISMISS";
    /** Action for accepting a contact request from notification. */
    public static final String ACTION_ACCEPT_CONTACT_REQUEST = "app.status.mobile.ipc.NOTIFICATION_ACCEPT_CONTACT_REQUEST";
    /** Action for rejecting a contact request from notification. */
    public static final String ACTION_REJECT_CONTACT_REQUEST = "app.status.mobile.ipc.NOTIFICATION_REJECT_CONTACT_REQUEST";

    /** Status logo (monochrome for tinting). */
    private static final int NOTIFICATION_SMALL_ICON = R.mipmap.ic_foreground;
    /** ID for "reply failed" notifications. */
    private static final int REPLY_FAILED_NOTIFICATION_ID = 4243;

    private NotificationBuilder() {}

    // ── Notification channels ─────────────────────────────────────────────────

    /** Ensures the "Messages" notification channel exists (Android O+). */
    public static void createMessagesChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager nm = (NotificationManager) context.getSystemService(
                Context.NOTIFICATION_SERVICE);
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

    // ── Message notifications (MessagingStyle) ────────────────────────────────

    /**
     * Builds and posts a message notification with {@code MessagingStyle},
     * inline reply action, and dismiss intent.
     *
     * @param context         service context
     * @param title           conversation title
     * @param conversationId  chat ID for grouping/buffering
     * @param notificationId  Android notification ID (stable per conversation)
     * @param deepLink        deep link URI for tap action
     * @param largeIcon       large icon bitmap (may be null)
     * @param messages        buffered messages for MessagingStyle
     */
    public static void postMessageNotification(Context context, String title,
            String conversationId, int notificationId, String deepLink,
            Bitmap largeIcon, List<MessageBufferManager.MessageEntry> messages) {

        Intent intent = buildTapIntent(context, deepLink);
        if (intent == null) return;

        PendingIntent pendingIntent = PendingIntent.getActivity(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID_MESSAGES)
                .setSmallIcon(NOTIFICATION_SMALL_ICON)
                .setContentTitle(title)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent);
        if (largeIcon != null) builder.setLargeIcon(largeIcon);

        buildMessagingStyle(builder, title, messages);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && largeIcon != null) {
            String shortcutId = "conv_" + conversationId;
            pushConversationShortcut(context, shortcutId, title, largeIcon, intent);
            builder.setShortcutId(shortcutId);
        }

        // Delete intent: clear buffer when user swipes away
        addDismissIntent(context, builder, conversationId, notificationId);

        // Reply action
        addReplyAction(context, builder, conversationId, notificationId);

        builder.setGroup("conv_" + conversationId);

        NotificationManagerCompat.from(context).notify(notificationId, builder.build());
    }

    /**
     * Refreshes a message notification after inline reply (appends user's reply
     * to the existing conversation).
     */
    public static void refreshMessageNotification(Context context,
            String conversationId, int notificationId,
            MessageBufferManager.ConversationMeta meta,
            List<MessageBufferManager.MessageEntry> messages) {

        if (messages == null || messages.isEmpty()) return;

        Intent intent = buildTapIntent(context, meta.deepLink);
        if (intent == null) return;

        PendingIntent pendingIntent = PendingIntent.getActivity(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Bitmap largeIcon = NotificationIconHelper.parseToBitmap(meta.largeIconUri);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID_MESSAGES)
                .setSmallIcon(NOTIFICATION_SMALL_ICON)
                .setContentTitle(meta.title)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent);
        if (largeIcon != null) builder.setLargeIcon(largeIcon);

        buildMessagingStyle(builder, meta.title, messages);
        addDismissIntent(context, builder, conversationId, notificationId);
        addReplyAction(context, builder, conversationId, notificationId);
        builder.setGroup("conv_" + conversationId);

        NotificationManagerCompat.from(context).notify(notificationId, builder.build());
    }

    // ── Contact request notification ──────────────────────────────────────────

    /**
     * Builds and posts a contact request notification with Accept and Reject
     * action buttons. No reply action.
     */
    public static void postContactRequestNotification(Context context, String title, String message,
            int notificationId, String deepLink, Bitmap largeIcon, String conversationId,
            String contactRequestId) {

        Intent intent = buildTapIntent(context, deepLink);
        if (intent == null) return;

        PendingIntent pendingIntent = PendingIntent.getActivity(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID_MESSAGES)
                .setSmallIcon(NOTIFICATION_SMALL_ICON)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(message))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent);
        if (largeIcon != null) builder.setLargeIcon(largeIcon);

        addContactRequestActions(context, builder, conversationId, contactRequestId, notificationId);
        if (conversationId != null && !conversationId.isEmpty()) {
            addDismissIntent(context, builder, conversationId, notificationId);
        }
        if (conversationId != null && !conversationId.isEmpty()) {
            builder.setGroup("conv_" + conversationId);
        }

        NotificationManagerCompat.from(context).notify(notificationId, builder.build());
    }

    // ── Simple (non-message) notification ─────────────────────────────────────

    /**
     * Builds and posts a simple notification with {@code BigTextStyle}
     * (for non-message events like community/group invites).
     */
    public static void postSimpleNotification(Context context, String title, String message,
            int notificationId, String deepLink, Bitmap largeIcon, String conversationId) {

        Intent intent = buildTapIntent(context, deepLink);
        if (intent == null) return;

        PendingIntent pendingIntent = PendingIntent.getActivity(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID_MESSAGES)
                .setSmallIcon(NOTIFICATION_SMALL_ICON)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(message))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent);
        if (largeIcon != null) builder.setLargeIcon(largeIcon);

        if (conversationId != null && !conversationId.isEmpty()) {
            builder.setGroup("conv_" + conversationId);
        }

        NotificationManagerCompat.from(context).notify(notificationId, builder.build());
    }

    // ── Reply-failed notification ─────────────────────────────────────────────

    /**
     * Shows a notification indicating an inline reply could not be sent.
     */
    public static void postReplyFailed(Context context) {
        if (context == null) return;
        try {
            createMessagesChannel(context);
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID_MESSAGES)
                    .setSmallIcon(NOTIFICATION_SMALL_ICON)
                    .setContentTitle(context.getString(R.string.notification_reply_failed))
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setAutoCancel(true);
            NotificationManagerCompat.from(context).notify(REPLY_FAILED_NOTIFICATION_ID, builder.build());
        } catch (Throwable t) {
            Log.w(TAG, "postReplyFailed failed", t);
        }
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    private static void buildMessagingStyle(NotificationCompat.Builder builder,
            String conversationTitle, List<MessageBufferManager.MessageEntry> messages) {
        if (messages == null || messages.isEmpty()) return;

        Person me = new Person.Builder().setName("Me").build();
        NotificationCompat.MessagingStyle style = new NotificationCompat.MessagingStyle(me)
                .setConversationTitle(conversationTitle);

        Set<String> senderNames = new HashSet<>();
        for (MessageBufferManager.MessageEntry entry : messages) {
            Person sender = entry.isFromMe ? me : null;
            if (!entry.isFromMe && entry.senderName != null && !entry.senderName.isEmpty()) {
                senderNames.add(entry.senderName);
                Person.Builder pb = new Person.Builder().setName(entry.senderName);
                if (entry.senderIconUri != null && !entry.senderIconUri.isEmpty()) {
                    Bitmap avatar = NotificationIconHelper.parseToBitmap(entry.senderIconUri);
                    if (avatar != null) pb.setIcon(IconCompat.createWithBitmap(avatar));
                }
                sender = pb.build();
            }
            style.addMessage(entry.text, entry.timestamp, sender);
        }
        if (senderNames.size() > 1) style.setGroupConversation(true);

        MessageBufferManager.MessageEntry latest = messages.get(messages.size() - 1);
        builder.setContentText(latest.text).setStyle(style);
    }

    private static void pushConversationShortcut(Context context, String shortcutId,
            String shortLabel, Bitmap icon, Intent intent) {
        try {
            ShortcutInfoCompat shortcut = new ShortcutInfoCompat.Builder(context, shortcutId)
                    .setLongLived(true)
                    .setShortLabel(shortLabel)
                    .setIcon(IconCompat.createWithBitmap(icon))
                    .setIntent(intent != null ? intent
                            : context.getPackageManager().getLaunchIntentForPackage(context.getPackageName()))
                    .build();
            ShortcutManagerCompat.pushDynamicShortcut(context, shortcut);
        } catch (Throwable t) {
            Log.w(TAG, "pushConversationShortcut failed", t);
        }
    }

    private static void addDismissIntent(Context context, NotificationCompat.Builder builder,
            String conversationId, int notificationId) {
        Intent dismissIntent = new Intent(context, NotificationReplyReceiver.class);
        dismissIntent.setAction(ACTION_DISMISS);
        dismissIntent.setPackage(context.getPackageName());
        dismissIntent.putExtra("conversationId", conversationId);
        builder.setDeleteIntent(PendingIntent.getBroadcast(
                context, notificationId, dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
    }

    private static void addReplyAction(Context context, NotificationCompat.Builder builder,
            String conversationId, int notificationId) {
        RemoteInput remoteInput = new RemoteInput.Builder(REPLY_REMOTE_INPUT_KEY)
                .setLabel(context.getString(R.string.notification_reply))
                .build();
        Intent replyIntent = new Intent(context, NotificationReplyReceiver.class);
        replyIntent.setAction(ACTION_REPLY);
        replyIntent.setPackage(context.getPackageName());
        replyIntent.putExtra("conversationId", conversationId);
        replyIntent.putExtra("androidNotificationId", notificationId);
        int replyFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            replyFlags |= PendingIntent.FLAG_MUTABLE;
        }
        PendingIntent replyPendingIntent = PendingIntent.getBroadcast(
                context, notificationId, replyIntent, replyFlags);
        builder.addAction(new NotificationCompat.Action.Builder(
                android.R.drawable.ic_menu_send,
                context.getString(R.string.notification_reply),
                replyPendingIntent
        ).addRemoteInput(remoteInput).build());
    }

    private static void addContactRequestActions(Context context, NotificationCompat.Builder builder,
            String conversationId, String contactRequestId, int notificationId) {
        Intent acceptIntent = new Intent(context, NotificationReplyReceiver.class);
        acceptIntent.setAction(ACTION_ACCEPT_CONTACT_REQUEST);
        acceptIntent.setPackage(context.getPackageName());
        acceptIntent.putExtra("conversationId", conversationId);
        acceptIntent.putExtra("contactRequestId", contactRequestId);
        acceptIntent.putExtra("androidNotificationId", notificationId);
        PendingIntent acceptPendingIntent = PendingIntent.getBroadcast(
                context, notificationId * 2, acceptIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Intent rejectIntent = new Intent(context, NotificationReplyReceiver.class);
        rejectIntent.setAction(ACTION_REJECT_CONTACT_REQUEST);
        rejectIntent.setPackage(context.getPackageName());
        rejectIntent.putExtra("conversationId", conversationId);
        rejectIntent.putExtra("contactRequestId", contactRequestId);
        rejectIntent.putExtra("androidNotificationId", notificationId);
        PendingIntent rejectPendingIntent = PendingIntent.getBroadcast(
                context, notificationId * 2 + 1, rejectIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        builder.addAction(new NotificationCompat.Action.Builder(
                android.R.drawable.ic_menu_upload,
                context.getString(R.string.notification_accept_contact_request),
                acceptPendingIntent
        ).build());
        builder.addAction(new NotificationCompat.Action.Builder(
                android.R.drawable.ic_menu_delete,
                context.getString(R.string.notification_reject_contact_request),
                rejectPendingIntent
        ).build());
    }

    private static Intent buildTapIntent(Context context, String deepLink) {
        Intent intent;
        if (deepLink != null && !deepLink.isEmpty()) {
            intent = new Intent(Intent.ACTION_VIEW, Uri.parse(deepLink));
        } else {
            intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        }
        if (intent == null) return null;
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        intent.setPackage(context.getPackageName());
        return intent;
    }
}
