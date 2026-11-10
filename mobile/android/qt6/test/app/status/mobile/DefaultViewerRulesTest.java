package app.status.mobile;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.CRC32;

import org.junit.Test;

public class DefaultViewerRulesTest {
    private static final String US = "app.status.mobile.debug";
    private static final String PROVIDER = "app.status.mobile.debug.qtprovider";
    private static final String DIR = "/cache/default-viewer";

    @Test
    public void isTheDefaultWhenAndroidPicksUs() {
        assertEquals("self", DefaultViewerRules.state(US, US, true, "Status"));
    }

    @Test
    public void canBeOfferedWhenAndroidAsksEachTime() {
        assertEquals("none", DefaultViewerRules.state(US, "android", false, "Android System"));
    }

    @Test
    public void namesTheAppThatIsTheDefault() {
        assertEquals("other:Drive",
                DefaultViewerRules.state(US, "com.google.android.apps.docs", true, "Drive"));
    }

    @Test
    public void offersNothingWhenNoAppOpensTheType() {
        assertEquals("", DefaultViewerRules.state(US, null, false, null));
    }

    @Test
    public void opensATypeByChoiceOnlyWhenAnotherAppCouldToo() {
        assertTrue(DefaultViewerRules.opensByChoice(US, US, 2));
        assertFalse(DefaultViewerRules.opensByChoice(US, US, 1));
        assertFalse(DefaultViewerRules.opensByChoice(US, "com.google.android.apps.photos", 3));
        assertFalse(DefaultViewerRules.opensByChoice(US, null, 0));
    }

    @Test
    public void claimsTheManifestsOpenWithTypes() throws IOException {
        String manifest = new String(Files.readAllBytes(manifest()), StandardCharsets.UTF_8);
        int start = manifest.indexOf("\"Open with\":");
        String filter = manifest.substring(start, manifest.indexOf("</intent-filter>", start));
        Matcher type = Pattern.compile("android:mimeType=\"([^\"]+)\"").matcher(filter);
        List<String> declared = new ArrayList<>();
        while (type.find()) {
            declared.add(type.group(1));
        }
        assertEquals(declared, DefaultViewerRules.TYPES);
    }

    @Test
    public void claimsATypeWhateverItsCase() {
        assertTrue(DefaultViewerRules.isType("Application/PDF"));
        assertFalse(DefaultViewerRules.isType("text/html"));
        assertFalse(DefaultViewerRules.isType(null));
    }

    @Test
    public void everyTypeHasAProbeOfItsKind() {
        assertEquals("Status.pdf", DefaultViewerRules.probeName("application/pdf"));
        assertEquals("Status.png", DefaultViewerRules.probeName("image/webp"));
        assertEquals("Status.txt", DefaultViewerRules.probeName("text/plain"));
        assertEquals("Status.json", DefaultViewerRules.probeName("application/json"));
        assertEquals("Status.png", DefaultViewerRules.probeName("image/x-ms-bmp"));
        assertEquals("Status.wav", DefaultViewerRules.probeName("video/mp4"));
        for (String type : DefaultViewerRules.TYPES) {
            assertNotNull(type, DefaultViewerRules.probeName(type));
        }
        assertNull(DefaultViewerRules.probeName("text/html"));
    }

    @Test
    public void knowsItsProbesWhateverTheAuthorityCase() {
        assertTrue(DefaultViewerRules.isProbe(PROVIDER, DIR,
                "App.Status.Mobile.Debug.QtProvider", DIR + "/Status.pdf"));
        assertTrue(DefaultViewerRules.isProbe(PROVIDER, DIR, PROVIDER, DIR + "/Status.wav"));
    }

    @Test
    public void takesNoOtherFileForAProbe() {
        assertFalse(DefaultViewerRules.isProbe(PROVIDER, DIR, PROVIDER, "/cache/opened-files/report.pdf"));
        assertFalse(DefaultViewerRules.isProbe(PROVIDER, DIR, PROVIDER, DIR + "/report.pdf"));
        assertFalse(DefaultViewerRules.isProbe(PROVIDER, DIR, PROVIDER, DIR + "/x/Status.pdf"));
        assertFalse(DefaultViewerRules.isProbe(PROVIDER, DIR,
                "com.android.providers.media.documents", DIR + "/Status.pdf"));
        assertFalse(DefaultViewerRules.isProbe(PROVIDER, DIR, null, null));
    }

    @Test
    public void probePdfCrossReferencesPointAtItsObjects() {
        String pdf = new String(DefaultViewerRules.probeBytes("Status.pdf"), StandardCharsets.US_ASCII);
        assertTrue(pdf.startsWith("%PDF-1.4\n"));
        assertTrue(pdf.endsWith("%%EOF\n"));

        Matcher start = Pattern.compile("startxref\n(\\d+)\n").matcher(pdf);
        assertTrue(start.find());
        int xref = Integer.parseInt(start.group(1));
        assertTrue(pdf.startsWith("xref\n0 4\n", xref));

        Matcher entry = Pattern.compile("(\\d{10}) 00000 n \n").matcher(pdf);
        int object = 0;
        while (entry.find()) {
            object++;
            assertTrue(pdf.startsWith(object + " 0 obj\n", Integer.parseInt(entry.group(1))));
        }
        assertEquals(3, object);
    }

    @Test
    public void probePngChunksCarryTheirChecksums() {
        byte[] png = DefaultViewerRules.probeBytes("Status.png");
        assertArrayEquals(new byte[] {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'},
                Arrays.copyOf(png, 8));
        List<String> chunks = new ArrayList<>();
        int at = 8;
        while (at < png.length) {
            int length = readInt(png, at);
            String type = new String(png, at + 4, 4, StandardCharsets.US_ASCII);
            CRC32 crc = new CRC32();
            crc.update(png, at + 4, 4 + length);
            assertEquals(type, (int) crc.getValue(), readInt(png, at + 8 + length));
            chunks.add(type);
            at += 12 + length;
        }
        assertEquals(Arrays.asList("IHDR", "IDAT", "IEND"), chunks);
    }

    @Test
    public void probeWavIsAHeaderWithoutSamples() {
        byte[] wav = DefaultViewerRules.probeBytes("Status.wav");
        assertEquals(44, wav.length);
        assertEquals("RIFF", new String(wav, 0, 4, StandardCharsets.US_ASCII));
        assertEquals("WAVEfmt ", new String(wav, 8, 8, StandardCharsets.US_ASCII));
        assertEquals("data", new String(wav, 36, 4, StandardCharsets.US_ASCII));
    }

    @Test
    public void probeTextIsEmpty() {
        assertEquals(0, DefaultViewerRules.probeBytes("Status.txt").length);
    }

    private static int readInt(byte[] bytes, int at) {
        return ((bytes[at] & 0xff) << 24) | ((bytes[at + 1] & 0xff) << 16)
                | ((bytes[at + 2] & 0xff) << 8) | (bytes[at + 3] & 0xff);
    }

    // Tests run from anywhere inside the repository.
    private static Path manifest() {
        for (Path dir = Paths.get("").toAbsolutePath(); dir != null; dir = dir.getParent()) {
            Path path = dir.resolve("mobile/android/qt6/AndroidManifest.xml");
            if (Files.isRegularFile(path)) {
                return path;
            }
        }
        throw new AssertionError("AndroidManifest.xml not found from " + Paths.get("").toAbsolutePath());
    }
}
