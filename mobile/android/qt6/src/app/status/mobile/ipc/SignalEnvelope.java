package app.status.mobile.ipc;

import java.nio.ByteBuffer;

/**
 * Reads the type of a status-go signal envelope without parsing the whole document.
 *
 * status-go marshals {@code {"type":...,"event":...,"timestamp":...}} with "type" as the
 * first key, so the type is found by scanning the prefix. Anything else yields "".
 * Kept free of Android dependencies so it runs in JVM unit tests.
 */
public final class SignalEnvelope {
    private static final String TYPE_KEY = "\"type\"";

    private SignalEnvelope() {}

    /** Reads from {@code utf8}'s position to its limit without moving the position. */
    public static String typeOf(ByteBuffer utf8) {
        return utf8 == null ? "" : typeOf(new Latin1View(utf8));
    }

    public static String typeOf(CharSequence json) {
        if (json == null) return "";
        final int n = json.length();
        int i = skipWhitespace(json, 0, n);
        if (i >= n || json.charAt(i) != '{') return "";
        i = skipWhitespace(json, i + 1, n);
        if (!regionMatches(json, i, n, TYPE_KEY)) return "";
        i = skipWhitespace(json, i + TYPE_KEY.length(), n);
        if (i >= n || json.charAt(i) != ':') return "";
        i = skipWhitespace(json, i + 1, n);
        if (i >= n || json.charAt(i) != '"') return "";
        final int start = ++i;
        for (; i < n; i++) {
            final char c = json.charAt(i);
            if (c == '"') return json.subSequence(start, i).toString();
            // Escaped types never occur in practice; treat them as unknown.
            if (c == '\\' || c < 0x20 || c > 0x7e) return "";
        }
        return "";
    }

    private static int skipWhitespace(CharSequence s, int i, int n) {
        while (i < n) {
            final char c = s.charAt(i);
            if (c != ' ' && c != '\n' && c != '\r' && c != '\t') break;
            i++;
        }
        return i;
    }

    private static boolean regionMatches(CharSequence s, int i, int n, String expected) {
        if (n - i < expected.length()) return false;
        for (int k = 0; k < expected.length(); k++) {
            if (s.charAt(i + k) != expected.charAt(k)) return false;
        }
        return true;
    }

    /** Bytes as chars, so non-ASCII bytes never match the ASCII structure being scanned. */
    private static final class Latin1View implements CharSequence {
        private final ByteBuffer buf;
        private final int offset;
        private final int length;

        Latin1View(ByteBuffer buf) {
            this(buf, buf.position(), buf.remaining());
        }

        private Latin1View(ByteBuffer buf, int offset, int length) {
            this.buf = buf;
            this.offset = offset;
            this.length = length;
        }

        @Override
        public int length() {
            return length;
        }

        @Override
        public char charAt(int index) {
            return (char) (buf.get(offset + index) & 0xff);
        }

        @Override
        public CharSequence subSequence(int start, int end) {
            return new Latin1View(buf, offset + start, end - start);
        }

        @Override
        public String toString() {
            final char[] chars = new char[length];
            for (int i = 0; i < length; i++) chars[i] = charAt(i);
            return new String(chars);
        }
    }
}
