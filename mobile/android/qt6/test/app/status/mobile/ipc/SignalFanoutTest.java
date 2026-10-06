package app.status.mobile.ipc;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import org.junit.Test;

public class SignalFanoutTest {
    private static final int THRESHOLD = 16;

    private static final class FakeRegion implements AutoCloseable {
        final byte[] bytes;
        boolean closed;

        FakeRegion(ByteBuffer src) {
            bytes = new byte[src.remaining()];
            src.duplicate().get(bytes);
        }

        @Override
        public void close() {
            closed = true;
        }
    }

    private static final class Recorder implements SignalFanout.Listener<FakeRegion> {
        final List<Object> received = new ArrayList<>();
        boolean fail;

        @Override
        public void onInline(byte[] utf8) {
            if (fail) throw new IllegalStateException("dead listener");
            received.add(utf8);
        }

        @Override
        public void onShared(FakeRegion region) {
            if (fail) throw new IllegalStateException("dead listener");
            received.add(region);
        }
    }

    private final List<FakeRegion> created = new ArrayList<>();
    private final List<Throwable> failures = new ArrayList<>();

    private int deliver(ByteBuffer payload, Recorder... listeners) {
        return SignalFanout.deliver(payload, THRESHOLD, listeners.length, i -> listeners[i],
                buf -> {
                    final FakeRegion r = new FakeRegion(buf);
                    created.add(r);
                    return r;
                },
                (i, t) -> failures.add(t));
    }

    private static ByteBuffer utf8(String s) {
        return ByteBuffer.wrap(s.getBytes(StandardCharsets.UTF_8));
    }

    @Test
    public void largeSignalUsesOneSharedRegionForAllListeners() {
        final Recorder a = new Recorder(), b = new Recorder(), c = new Recorder();
        final ByteBuffer payload = utf8("{\"type\":\"community.found\",\"event\":{}}");

        assertEquals(3, deliver(payload, a, b, c));

        assertEquals(1, created.size());
        final FakeRegion region = created.get(0);
        assertSame(region, a.received.get(0));
        assertSame(region, b.received.get(0));
        assertSame(region, c.received.get(0));
        assertArrayEquals(payload.array(), region.bytes);
        assertTrue("region must be released after the broadcast", region.closed);
    }

    @Test
    public void smallSignalSharesOneArrayWithoutCopyingAWrappedBuffer() {
        final Recorder a = new Recorder(), b = new Recorder();
        final ByteBuffer payload = utf8("{\"type\":\"x\"}");

        assertEquals(2, deliver(payload, a, b));

        assertEquals(0, created.size());
        assertSame(payload.array(), a.received.get(0));
        assertSame(payload.array(), b.received.get(0));
    }

    @Test
    public void smallDirectSignalIsCopiedOnce() {
        final Recorder a = new Recorder(), b = new Recorder();
        final byte[] bytes = "{\"type\":\"x\"}".getBytes(StandardCharsets.UTF_8);
        final ByteBuffer direct = ByteBuffer.allocateDirect(bytes.length);
        direct.put(bytes).flip();

        assertEquals(2, deliver(direct, a, b));

        assertSame(a.received.get(0), b.received.get(0));
        assertArrayEquals(bytes, (byte[]) a.received.get(0));
        assertEquals("delivery must not consume the caller's buffer", 0, direct.position());
    }

    @Test
    public void noListenersCreatesNothing() {
        assertEquals(0, deliver(utf8("{\"type\":\"community.found\",\"event\":{}}")));
        assertEquals(0, created.size());
    }

    @Test
    public void failingListenerDoesNotStopTheOthers() {
        final Recorder dead = new Recorder(), live = new Recorder();
        dead.fail = true;

        assertEquals(1, deliver(utf8("{\"type\":\"community.found\",\"event\":{}}"), dead, live));

        assertEquals(1, live.received.size());
        assertEquals(1, failures.size());
        assertTrue(created.get(0).closed);
    }
}
