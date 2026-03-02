package app.status.mobile.ipc.notifications;

import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

import androidx.core.app.NotificationManagerCompat;

import android.content.Context;

/**
 * Manages per-conversation message state for Android notifications.
 *
 * Tracks buffered messages (for {@code MessagingStyle}), conversation metadata
 * (title, deepLink, icon), and active notification IDs. Thread-safe via
 * concurrent collections.
 */
public final class MessageBufferManager {
    private static final int MAX_BUFFERED_MESSAGES = 5;

    /** Buffered messages per conversation for MessagingStyle. Key: conversationId. */
    private final Map<String, LinkedList<MessageEntry>> messageBuffer = new ConcurrentHashMap<>();

    /** Cached conversation metadata for refreshing notifications after inline reply. */
    private final Map<String, ConversationMeta> conversationMeta = new ConcurrentHashMap<>();

    /** IDs of message/other notifications posted (excludes foreground + reply-failed). */
    private final Set<Integer> activeNotificationIds = new CopyOnWriteArraySet<>();

    // ── Data classes ──────────────────────────────────────────────────────────

    /** Represents a single message in a notification conversation history. */
    public static final class MessageEntry {
        public final String text;
        public final long timestamp;
        public final String senderName;
        public final String senderIconUri;
        public final boolean isFromMe;

        public MessageEntry(String text, long timestamp, String senderName,
                String senderIconUri, boolean isFromMe) {
            this.text = text;
            this.timestamp = timestamp;
            this.senderName = senderName;
            this.senderIconUri = senderIconUri;
            this.isFromMe = isFromMe;
        }
    }

    /** Cached metadata for a conversation (title, deepLink, large icon). */
    public static final class ConversationMeta {
        public final String title;
        public final String deepLink;
        public final String largeIconUri;

        public ConversationMeta(String title, String deepLink, String largeIconUri) {
            this.title = title;
            this.deepLink = deepLink;
            this.largeIconUri = largeIconUri;
        }
    }

    // ── Message buffer operations ─────────────────────────────────────────────

    /**
     * Adds a received message to the conversation buffer.
     * Trims the buffer to {@link #MAX_BUFFERED_MESSAGES}.
     */
    public void addMessage(String conversationId, String text, long timestamp,
            String senderName, String senderIconUri) {
        LinkedList<MessageEntry> buffer = messageBuffer.computeIfAbsent(
                conversationId, k -> new LinkedList<>());
        buffer.add(new MessageEntry(text, timestamp,
                senderName != null ? senderName : "",
                senderIconUri != null ? senderIconUri : "", false));
        while (buffer.size() > MAX_BUFFERED_MESSAGES) buffer.removeFirst();
    }

    /**
     * Appends the user's own reply to the conversation buffer (for refreshing
     * the notification after inline reply).
     */
    public void addReply(String conversationId, String replyText) {
        LinkedList<MessageEntry> buffer = messageBuffer.get(conversationId);
        if (buffer == null) buffer = new LinkedList<>();
        buffer.add(new MessageEntry(replyText.trim(), System.currentTimeMillis(), "Me", "", true));
        while (buffer.size() > MAX_BUFFERED_MESSAGES) buffer.removeFirst();
        messageBuffer.put(conversationId, buffer);
    }

    /** Returns the message buffer for a conversation, or {@code null}. */
    public List<MessageEntry> getMessages(String conversationId) {
        return messageBuffer.get(conversationId);
    }

    // ── Conversation metadata ─────────────────────────────────────────────────

    /** Stores conversation metadata (title, deepLink, icon) for reply refresh. */
    public void putMeta(String conversationId, String title, String deepLink, String largeIconUri) {
        conversationMeta.put(conversationId,
                new ConversationMeta(title,
                        deepLink != null ? deepLink : "",
                        largeIconUri != null ? largeIconUri : ""));
    }

    /** Returns cached metadata for a conversation, or {@code null}. */
    public ConversationMeta getMeta(String conversationId) {
        return conversationMeta.get(conversationId);
    }

    // ── Active notification tracking ──────────────────────────────────────────

    /** Records an active notification ID (for bulk cancellation). */
    public void trackNotification(int notificationId) {
        activeNotificationIds.add(notificationId);
    }

    // ── Clear operations ──────────────────────────────────────────────────────

    /** Clears all state for a single conversation. */
    public void clearConversation(String conversationId) {
        if (conversationId != null && !conversationId.isEmpty()) {
            messageBuffer.remove(conversationId);
            conversationMeta.remove(conversationId);
            activeNotificationIds.remove(Math.abs(conversationId.hashCode()));
        }
    }

    /** Clears all message state and cancels all tracked notifications. */
    public void clearAllAndCancelNotifications(Context context) {
        messageBuffer.clear();
        conversationMeta.clear();
        for (int id : activeNotificationIds) {
            NotificationManagerCompat.from(context).cancel(id);
        }
        activeNotificationIds.clear();
    }
}
