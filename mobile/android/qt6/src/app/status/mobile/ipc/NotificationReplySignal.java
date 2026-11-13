package app.status.mobile.ipc;

/**
 * The frontend signal for a sent Android notification reply. status-go does not emit
 * messages.new for locally initiated sends, so the service builds this envelope itself.
 *
 * <p>Key order matches status-go's envelope: "type" first (SignalEnvelope prefix scan),
 * then "epoch" (the frontend's prefix scan). The frontend only accepts signals of the
 * backend session it is logged in to, so the epoch is the one the reply was sent in -
 * never the one current when a queued reply is finally delivered.
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
        if (eventJson == null || eventJson.isEmpty() || signalEpoch <= 0) return null;
        return "{\"type\":\"" + TYPE + "\",\"epoch\":" + signalEpoch + ",\"event\":" + eventJson + "}";
    }
}
