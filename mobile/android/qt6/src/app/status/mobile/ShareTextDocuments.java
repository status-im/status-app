package app.status.mobile;

import android.content.ContentResolver;
import android.content.Context;
import android.net.Uri;
import android.util.Log;
import android.webkit.MimeTypeMap;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.Charset;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

// Text document shares: text/* streams shared without inline text. Their
// contents are pasted as message text, like a clipboard paste; the composer
// applies the message limits. vCards and calendars are rendered readably.
final class ShareTextDocuments {
    private static final String TAG = "ShareTextDocuments";
    // Memory guard only; the composer cuts the text far below this.
    static final int MAX_BYTES_PER_DOCUMENT = 1 << 20;
    static final String SEPARATOR = "\n\n";
    static final String OCTET_STREAM = "application/octet-stream";
    // application/* types that are text files: the standard rtf type and the
    // types Samsung My Files declares for .txt and .json.
    private static final List<String> TEXT_APPLICATION_TYPES =
            Arrays.asList("application/txt", "application/json", "application/rtf");

    static boolean isTextType(String mime) {
        return mime != null && (mime.startsWith("text/") || TEXT_APPLICATION_TYPES.contains(mime));
    }

    // Says nothing about the content (Samsung My Files uses octet-stream for .md).
    static boolean isOpaqueType(String mime) {
        return mime == null || OCTET_STREAM.equals(mime);
    }

    private ShareTextDocuments() {}

    // Background thread. Reads every text stream and joins them in share
    // order. The provider's per-stream type is authoritative when it names
    // one; null (MediaStore, some file providers) and octet-stream (Samsung
    // My Files for .txt) say nothing, then the intent's declared type and
    // the file extension are tried, and failing those the content decides:
    // a stream that decodes as text is text. Streams of another concrete
    // type, that fail to read or that are not decodable are skipped; the
    // rest of the share still goes through.
    static String read(Context ctx, List<Uri> uris, String intentType) {
        ContentResolver resolver = ctx.getContentResolver();
        StringBuilder joined = new StringBuilder();
        for (Uri uri : uris) {
            String mime = resolver.getType(uri);
            if (isOpaqueType(mime)) mime = fallbackType(uri, intentType);
            boolean unknown = isOpaqueType(mime);
            if (!unknown && !isTextType(mime)) {
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
                Log.w(TAG, "share intake: dropping undecodable " + (unknown ? "untyped" : "text")
                        + " stream (" + mime + ")");
                continue;
            }
            text = trimTrailing(render(text));
            if (text.isEmpty()) continue;
            if (joined.length() > 0) joined.append(SEPARATOR);
            joined.append(text);
        }
        return joined.toString();
    }

    // Wildcards ("text/*", "*/*") and octet-stream name no concrete type;
    // the extension may. Null means unknown.
    static String fallbackType(Uri uri, String intentType) {
        boolean concrete = intentType != null && !intentType.endsWith("/*")
                && !isOpaqueType(intentType);
        if (concrete) return intentType;
        String ext = MimeTypeMap.getFileExtensionFromUrl(uri.toString());
        String byExt = ext.isEmpty() ? null
                : MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.toLowerCase(Locale.ROOT));
        if (byExt == null && "text/*".equals(intentType)) return "text/plain";
        return byExt;
    }

    // Contact and calendar files become readable cards; everything else is
    // pasted as is.
    static String render(String text) {
        if (VCardText.isVCard(text)) return VCardText.format(text);
        if (ICalendarText.isICalendar(text)) return ICalendarText.format(text);
        return text;
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

    // BOM-sniffed UTF-16, otherwise strict UTF-8; a NUL anywhere means binary.
    // Null when the bytes are not text (a binary file behind a text claim or
    // an untyped stream). A read cut at the memory guard may end
    // mid-character; up to three trailing bytes are dropped before giving up.
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
                String text = cs.newDecoder()
                        .onMalformedInput(CodingErrorAction.REPORT)
                        .onUnmappableCharacter(CodingErrorAction.REPORT)
                        .decode(ByteBuffer.wrap(bytes, offset, length))
                        .toString();
                return text.indexOf('\0') >= 0 ? null : text;
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
