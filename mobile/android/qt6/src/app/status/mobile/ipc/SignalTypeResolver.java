package app.status.mobile.ipc;

import java.nio.ByteBuffer;

/**
 * Signal type lookup: the {@link SignalEnvelope} prefix scan, falling back to one full parse
 * when "type" is not the first key, with a rate-limited warning so a status-go envelope
 * change shows up in logs instead of silently disabling type-based handling.
 */
final class SignalTypeResolver {
    interface FullParse {
        String typeOf(ByteBuffer utf8) throws Exception;
    }

    interface Warn {
        void warn(String message);
    }

    interface Clock {
        long nowMs();
    }

    private final FullParse parse;
    private final Warn warn;
    private final Clock clock;
    private final long warnIntervalMs;

    private final Object warnLock = new Object();
    private boolean warned;
    private long lastWarnMs;
    private int suppressed;

    SignalTypeResolver(FullParse parse, Warn warn, Clock clock, long warnIntervalMs) {
        this.parse = parse;
        this.warn = warn;
        this.clock = clock;
        this.warnIntervalMs = warnIntervalMs;
    }

    String resolve(ByteBuffer utf8) {
        final String scanned = SignalEnvelope.typeOf(utf8);
        if (!scanned.isEmpty()) return scanned;

        String type;
        try {
            type = parse.typeOf(utf8.duplicate());
        } catch (Throwable t) {
            type = null;
        }
        if (type == null) type = "";
        maybeWarn(type, utf8.remaining());
        return type;
    }

    private void maybeWarn(String type, int sizeBytes) {
        final int suppressedSinceLast;
        synchronized (warnLock) {
            final long now = clock.nowMs();
            if (warned && now - lastWarnMs < warnIntervalMs) {
                suppressed++;
                return;
            }
            warned = true;
            lastWarnMs = now;
            suppressedSinceLast = suppressed;
            suppressed = 0;
        }
        warn.warn("signal type not found by prefix scan; used a full parse type=" + type
                + " sizeBytes=" + sizeBytes + " suppressed=" + suppressedSinceLast);
    }
}
