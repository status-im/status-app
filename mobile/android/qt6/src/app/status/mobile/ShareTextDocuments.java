package app.status.mobile;

import android.content.ContentResolver;
import android.content.Context;
import android.net.Uri;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.Charset;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.List;

// Text document shares: text/* streams shared without inline text. Their
// contents are pasted as message text, like a clipboard paste; the composer
// applies the message limits. vCards are rendered as readable contact cards.
final class ShareTextDocuments {
    private static final String TAG = "ShareTextDocuments";
    // Memory guard only; the composer cuts the text far below this.
    static final int MAX_BYTES_PER_DOCUMENT = 1 << 20;
    static final String SEPARATOR = "\n\n";

    private ShareTextDocuments() {}

    // Background thread. Reads every text/* stream (the provider's per-stream
    // type is authoritative, as for images) and joins them in share order.
    // Streams that are not text, fail to read or are not decodable are
    // skipped; the rest of the share still goes through.
    static String read(Context ctx, List<Uri> uris) {
        ContentResolver resolver = ctx.getContentResolver();
        StringBuilder joined = new StringBuilder();
        for (Uri uri : uris) {
            String mime = resolver.getType(uri);
            if (mime == null || !mime.startsWith("text/")) {
                Log.w(TAG, "share intake: dropping non-text stream (" + mime + ")");
                continue;
            }
            String text;
            try (InputStream in = resolver.openInputStream(uri)) {
                if (in == null) continue;
                byte[] bytes = readUpTo(in, MAX_BYTES_PER_DOCUMENT);
                text = decode(bytes, bytes.length == MAX_BYTES_PER_DOCUMENT);
            } catch (Exception e) {
                Log.w(TAG, "share intake: failed to read shared text " + uri, e);
                continue;
            }
            if (text == null) {
                Log.w(TAG, "share intake: dropping undecodable text stream (" + mime + ")");
                continue;
            }
            text = trimTrailing(VCardText.isVCard(text) ? VCardText.format(text) : text);
            if (text.isEmpty()) continue;
            if (joined.length() > 0) joined.append(SEPARATOR);
            joined.append(text);
        }
        return joined.toString();
    }

    static byte[] readUpTo(InputStream in, int max) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buffer = new byte[64 * 1024];
        int remaining = max;
        while (remaining > 0) {
            int read = in.read(buffer, 0, Math.min(buffer.length, remaining));
            if (read == -1) break;
            out.write(buffer, 0, read);
            remaining -= read;
        }
        return out.toByteArray();
    }

    // BOM-sniffed UTF-16, otherwise strict UTF-8. Null when the bytes are not
    // text in either (a binary file behind a text/* claim). A read cut at the
    // memory guard may end mid-character; up to three trailing bytes are
    // dropped before giving up on it.
    static String decode(byte[] bytes, boolean truncated) {
        Charset cs = StandardCharsets.UTF_8;
        int offset = 0;
        if (bytes.length >= 3 && (bytes[0] & 0xFF) == 0xEF && (bytes[1] & 0xFF) == 0xBB
                && (bytes[2] & 0xFF) == 0xBF) {
            offset = 3;
        } else if (bytes.length >= 2 && (bytes[0] & 0xFF) == 0xFE && (bytes[1] & 0xFF) == 0xFF) {
            cs = StandardCharsets.UTF_16BE;
            offset = 2;
        } else if (bytes.length >= 2 && (bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xFF) == 0xFE) {
            cs = StandardCharsets.UTF_16LE;
            offset = 2;
        }
        int maxCut = truncated ? 3 : 0;
        for (int cut = 0; cut <= maxCut; cut++) {
            int length = bytes.length - offset - cut;
            if (length < 0) break;
            try {
                return cs.newDecoder()
                        .onMalformedInput(CodingErrorAction.REPORT)
                        .onUnmappableCharacter(CodingErrorAction.REPORT)
                        .decode(ByteBuffer.wrap(bytes, offset, length))
                        .toString();
            } catch (CharacterCodingException ignored) {
                // try the next cut
            }
        }
        return null;
    }

    private static String trimTrailing(String s) {
        int end = s.length();
        while (end > 0 && Character.isWhitespace(s.charAt(end - 1))) end--;
        return s.substring(0, end);
    }
}
