package app.status.mobile;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.net.Uri;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.filters.SmallTest;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/**
 * Decoding of text document shares: BOM-sniffed UTF-16, strict UTF-8, binary
 * rejected, and a read cut at the memory guard still decodes.
 */
@RunWith(AndroidJUnit4.class)
@SmallTest
public class ShareTextDocumentsTest {

    private static byte[] concat(byte[] head, byte[] tail) {
        byte[] out = Arrays.copyOf(head, head.length + tail.length);
        System.arraycopy(tail, 0, out, head.length, tail.length);
        return out;
    }

    @Test
    public void utf8WithoutBom() {
        assertEquals("héllo", ShareTextDocuments.decode("héllo".getBytes(StandardCharsets.UTF_8), false));
    }

    @Test
    public void utf8BomIsStripped() {
        byte[] bytes = concat(new byte[] {(byte) 0xEF, (byte) 0xBB, (byte) 0xBF},
                "note".getBytes(StandardCharsets.UTF_8));
        assertEquals("note", ShareTextDocuments.decode(bytes, false));
    }

    @Test
    public void utf16BomsSelectTheEncoding() {
        byte[] be = concat(new byte[] {(byte) 0xFE, (byte) 0xFF}, "ab".getBytes(StandardCharsets.UTF_16BE));
        byte[] le = concat(new byte[] {(byte) 0xFF, (byte) 0xFE}, "ab".getBytes(StandardCharsets.UTF_16LE));
        assertEquals("ab", ShareTextDocuments.decode(be, false));
        assertEquals("ab", ShareTextDocuments.decode(le, false));
    }

    @Test
    public void binaryBehindTextClaimIsRejected() {
        byte[] png = {(byte) 0x89, 'P', 'N', 'G', (byte) 0xFF, (byte) 0xFE, 0x00, (byte) 0xC3};
        assertNull(ShareTextDocuments.decode(png, false));
    }

    @Test
    public void truncatedReadDropsTheCutCharacter() {
        byte[] whole = "ab€".getBytes(StandardCharsets.UTF_8); // € is 3 bytes
        byte[] cut = Arrays.copyOf(whole, whole.length - 1);
        assertNull(ShareTextDocuments.decode(cut, false));
        assertEquals("ab", ShareTextDocuments.decode(cut, true));
    }

    @Test
    public void providerWithoutTypeFallsBackToIntentThenExtension() {
        Uri txt = Uri.parse("content://media/external/file/42");
        Uri md = Uri.parse("content://com.example.files/docs/notes.md");
        Uri bare = Uri.parse("content://com.example.files/docs/1234");
        assertEquals("text/plain", ShareTextDocuments.fallbackType(bare, "text/plain"));
        assertEquals("text/markdown", ShareTextDocuments.fallbackType(md, "text/*"));
        assertEquals("text/plain", ShareTextDocuments.fallbackType(bare, "text/*"));
        assertNull(ShareTextDocuments.fallbackType(bare, "*/*"));
        assertEquals("text/plain", ShareTextDocuments.fallbackType(Uri.parse(txt + "/a.txt"), "*/*"));
        // Samsung My Files shares .txt as octet-stream: no information either.
        assertEquals("text/plain", ShareTextDocuments.fallbackType(Uri.parse(txt + "/a.txt"),
                "application/octet-stream"));
        assertNull(ShareTextDocuments.fallbackType(bare, "application/octet-stream"));
    }

    @Test
    public void samsungMyFilesTypesCountAsText() {
        assertTrue(ShareTextDocuments.isTextType("application/txt"));
        assertTrue(ShareTextDocuments.isTextType("application/json"));
        assertTrue(ShareTextDocuments.isTextType("text/comma-separated-values"));
        assertFalse(ShareTextDocuments.isTextType("application/pdf"));
        assertTrue(ShareTextDocuments.isOpaqueType("application/octet-stream"));
        assertTrue(ShareTextDocuments.isOpaqueType(null));
        assertFalse(ShareTextDocuments.isOpaqueType("text/plain"));
    }

    @Test
    public void nulByteMeansBinary() {
        byte[] bytes = {'a', 'b', 0, 'c'};
        assertNull(ShareTextDocuments.decode(bytes, false));
    }

    @Test
    public void readStopsAtTheMemoryGuard() throws Exception {
        byte[] big = new byte[ShareTextDocuments.MAX_BYTES_PER_DOCUMENT + 10];
        Arrays.fill(big, (byte) 'x');
        byte[] read = ShareTextDocuments.readUpTo(new ByteArrayInputStream(big),
                ShareTextDocuments.MAX_BYTES_PER_DOCUMENT);
        assertEquals(ShareTextDocuments.MAX_BYTES_PER_DOCUMENT, read.length);
    }
}
