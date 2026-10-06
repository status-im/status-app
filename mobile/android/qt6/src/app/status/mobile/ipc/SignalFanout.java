package app.status.mobile.ipc;

import java.nio.ByteBuffer;
import java.util.function.IntFunction;

/**
 * Broadcasts one UTF-8 signal payload to every listener with at most one copy: a single
 * inline byte[] below the threshold, otherwise a single shared region reused by all
 * listeners and closed after the broadcast. Free of Android types for JVM unit tests.
 */
final class SignalFanout {
    interface Listener<P> {
        void onInline(byte[] utf8) throws Exception;

        void onShared(P region) throws Exception;
    }

    interface RegionFactory<P extends AutoCloseable> {
        /** Must not change the buffer's position. */
        P create(ByteBuffer utf8) throws Exception;
    }

    interface FailureLog {
        void failed(int listenerIndex, Throwable t);
    }

    private SignalFanout() {}

    /** Returns how many listeners accepted the signal. Never consumes {@code utf8}. */
    static <P extends AutoCloseable> int deliver(ByteBuffer utf8, int sharedThreshold, int count,
            IntFunction<? extends Listener<P>> listenerAt, RegionFactory<P> factory, FailureLog log) {
        if (count <= 0) return 0;
        if (utf8.remaining() < sharedThreshold) {
            final byte[] bytes = toArray(utf8);
            int delivered = 0;
            for (int i = 0; i < count; i++) {
                try {
                    listenerAt.apply(i).onInline(bytes);
                    delivered++;
                } catch (Throwable t) {
                    log.failed(i, t);
                }
            }
            return delivered;
        }

        final P region;
        try {
            region = factory.create(utf8);
        } catch (Throwable t) {
            log.failed(-1, t);
            return 0;
        }
        int delivered = 0;
        try {
            for (int i = 0; i < count; i++) {
                try {
                    listenerAt.apply(i).onShared(region);
                    delivered++;
                } catch (Throwable t) {
                    log.failed(i, t);
                }
            }
        } finally {
            try {
                region.close();
            } catch (Throwable t) {
                log.failed(-1, t);
            }
        }
        return delivered;
    }

    static byte[] toArray(ByteBuffer buf) {
        if (buf.hasArray() && buf.arrayOffset() == 0 && buf.position() == 0
                && buf.remaining() == buf.array().length) {
            return buf.array();
        }
        final byte[] out = new byte[buf.remaining()];
        buf.duplicate().get(out);
        return out;
    }
}
