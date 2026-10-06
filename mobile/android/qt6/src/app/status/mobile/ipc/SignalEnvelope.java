package app.status.mobile.ipc;

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
            if (c == '\\' || c < 0x20) return "";
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
}
