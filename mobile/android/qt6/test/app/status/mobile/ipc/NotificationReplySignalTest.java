package app.status.mobile.ipc;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class NotificationReplySignalTest {
    private static final String RESPONSE = "{\"result\":{\"chats\":[],\"messages\":[]}}";

    @Test
    public void typeStaysTheFirstKey() {
        assertEquals(NotificationReplySignal.TYPE,
                SignalEnvelope.typeOf(NotificationReplySignal.envelope(RESPONSE, 3)));
    }

    @Test
    public void carriesTheEpochTheReplyWasSentInRightAfterTheType() {
        final String signal = NotificationReplySignal.envelope(RESPONSE, 7);
        assertTrue(signal, signal.startsWith(
                "{\"type\":\"notification.reply.sent\",\"epoch\":7,\"event\":"));
        assertTrue(signal, signal.endsWith(RESPONSE + "}"));
    }

    @Test
    public void noEnvelopeWithoutAValidEpoch() {
        assertNull(NotificationReplySignal.envelope(RESPONSE, 0));
        assertNull(NotificationReplySignal.envelope(RESPONSE, -1));
        assertNull(NotificationReplySignal.envelope("", 1));
        assertNull(NotificationReplySignal.envelope(null, 1));
    }
}
