package app.status.mobile.ipc;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class SignalEnvelopeTest {
    @Test
    public void readsTypeFromGoMarshalledEnvelope() {
        assertEquals("node.login",
                SignalEnvelope.typeOf("{\"type\":\"node.login\",\"event\":{\"error\":\"\"},\"timestamp\":1}"));
    }

    @Test
    public void toleratesWhitespace() {
        assertEquals("local-notifications",
                SignalEnvelope.typeOf(" {\n \"type\" : \"local-notifications\" ,\"event\":{}}"));
    }

    @Test
    public void readsTypeWithoutTouchingTheEvent() {
        final StringBuilder big = new StringBuilder("{\"type\":\"community.found\",\"event\":");
        // Unterminated event: a DOM parse would throw, the prefix scan must not care.
        for (int i = 0; i < 100_000; i++) big.append("[\"x\",");
        assertEquals("community.found", SignalEnvelope.typeOf(big));
    }

    @Test
    public void unknownWhenTypeIsNotTheFirstKey() {
        assertEquals("", SignalEnvelope.typeOf("{\"event\":{\"type\":\"node.login\"},\"type\":\"x\"}"));
    }

    @Test
    public void unknownForMalformedInput() {
        assertEquals("", SignalEnvelope.typeOf(null));
        assertEquals("", SignalEnvelope.typeOf(""));
        assertEquals("", SignalEnvelope.typeOf("[]"));
        assertEquals("", SignalEnvelope.typeOf("{\"type\":"));
        assertEquals("", SignalEnvelope.typeOf("{\"type\":\"unterminated"));
        assertEquals("", SignalEnvelope.typeOf("{\"type\":42}"));
        assertEquals("", SignalEnvelope.typeOf("{\"type\":\"a\\\"b\"}"));
    }
}
