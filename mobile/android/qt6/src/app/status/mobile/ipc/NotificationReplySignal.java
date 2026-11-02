package app.status.mobile.ipc;

/**
 * The frontend signals the service builds itself for Android notification actions: a sent
 * reply (status-go does not emit messages.new for locally initiated sends) and a
 * conversation marked read.
 *
 * <p>Key order matches status-go's envelope: "type" first (SignalEnvelope prefix scan),
 * then "epoch" (the frontend's prefix scan). The frontend only accepts signals of the
 * backend session it is logged in to, so the epoch is the one the action ran in - never
 * the one current when a queued signal is finally delivered.
 */
final class NotificationReplySignal {
    static final String TYPE = "notification.reply.sent";

    private NotificationReplySignal() {}

    /**
     * @param eventJson the sendChatMessage JSON-RPC response, already validated JSON
     * @param signalEpoch epoch of the backend session the reply was sent in
     * @return the envelope, or null without a valid epoch (the frontend would drop it)
     */
    static String envelope(String eventJson, long signalEpoch) {
        return envelope(TYPE, eventJson, signalEpoch);
    }

    /**
     * @param type the signal type, a plain identifier (written unescaped)
     * @param eventJson the event, already validated JSON
     * @param signalEpoch epoch of the backend session the action ran in
     * @return the envelope, or null without a type, an event or a valid epoch
     */
    static String envelope(String type, String eventJson, long signalEpoch) {
        if (type == null || type.isEmpty() || eventJson == null || eventJson.isEmpty()
                || signalEpoch <= 0) return null;
        return "{\"type\":\"" + type + "\",\"epoch\":" + signalEpoch + ",\"event\":" + eventJson + "}";
    }
}
