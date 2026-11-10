package app.status.mobile;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.zip.CRC32;
import java.util.zip.Deflater;

/** Android-free rules for offering Status as the app that opens a file type (see DefaultViewer). */
final class DefaultViewerRules {
    /** App-private cache subdirectory holding the files the system is asked about. */
    static final String PROBE_DIR = "default-viewer";

    /** The "Open with" types in AndroidManifest.xml. */
    static final List<String> TYPES = Collections.unmodifiableList(Arrays.asList(
            "image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/x-ms-bmp",
            "application/pdf", "text/plain", "application/json",
            "audio/mpeg", "audio/mp3", "audio/wav", "audio/x-wav", "audio/wave",
            "video/webm", "audio/webm", "video/mp4", "video/x-m4v",
            "audio/mp4", "audio/aac", "audio/x-m4a"));

    private DefaultViewerRules() {}

    static boolean isType(String mimeType) {
        return mimeType != null && TYPES.contains(mimeType.toLowerCase(Locale.ROOT));
    }

    /**
     * "self" when Android opens the type with Status, "none" when it asks each time,
     * "other:<app name>" when another app is the default, "" when no app opens it.
     * chosenIsCandidate is false for the system's own "Open with" dialog.
     */
    static String state(String ownPackage, String chosenPackage, boolean chosenIsCandidate,
                        String chosenLabel) {
        if (chosenPackage == null) {
            return "";
        }
        if (!chosenIsCandidate) {
            return "none";
        }
        if (chosenPackage.equals(ownPackage)) {
            return "self";
        }
        return "other:" + (chosenLabel == null ? chosenPackage : chosenLabel);
    }

    /**
     * Whether Android opens a type with Status because the user chose it: not
     * when Status is the only app for the type, which no Stop can change.
     */
    static boolean opensByChoice(String ownPackage, String chosenPackage, int candidates) {
        return ownPackage.equals(chosenPackage) && candidates > 1;
    }

    /** The probe's file name for a type Status claims, else null. */
    static String probeName(String mimeType) {
        if (!isType(mimeType)) {
            return null;
        }
        String type = mimeType.toLowerCase(Locale.ROOT);
        if (type.equals("application/pdf")) {
            return "Status.pdf";
        }
        if (type.startsWith("image/")) {
            return "Status.png";
        }
        if (type.equals("text/plain")) {
            return "Status.txt";
        }
        if (type.equals("application/json")) {
            return "Status.json";
        }
        return "Status.wav";
    }

    /** What a probe holds: an empty file of its kind, for an app the user picks just once. */
    static byte[] probeBytes(String probeName) {
        switch (probeName) {
            case "Status.pdf": return blankPdf();
            case "Status.png": return blankPng();
            case "Status.wav": return silentWav();
            default: return new byte[0];
        }
    }

    /** True for a probe coming back from the system's "Open with" dialog. */
    static boolean isProbe(String probeAuthority, String probeDirPath, String authority, String path) {
        if (authority == null || path == null
                || !authority.toLowerCase(Locale.ROOT).equals(probeAuthority.toLowerCase(Locale.ROOT))
                || !path.startsWith(probeDirPath + "/")) {
            return false;
        }
        String name = path.substring(probeDirPath.length() + 1);
        for (String type : TYPES) {
            if (name.equals(probeName(type))) {
                return true;
            }
        }
        return false;
    }

    /** One blank A4 page. */
    static byte[] blankPdf() {
        String[] objects = {
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] >>",
        };
        StringBuilder pdf = new StringBuilder("%PDF-1.4\n");
        int[] offsets = new int[objects.length];
        for (int i = 0; i < objects.length; i++) {
            offsets[i] = pdf.length();
            pdf.append(i + 1).append(" 0 obj\n").append(objects[i]).append("\nendobj\n");
        }
        int xref = pdf.length();
        pdf.append("xref\n0 ").append(objects.length + 1).append("\n0000000000 65535 f \n");
        for (int offset : offsets) {
            pdf.append(String.format(Locale.ROOT, "%010d 00000 n \n", offset));
        }
        pdf.append("trailer\n<< /Size ").append(objects.length + 1)
                .append(" /Root 1 0 R >>\nstartxref\n").append(xref).append("\n%%EOF\n");
        return pdf.toString().getBytes(StandardCharsets.US_ASCII);
    }

    /** One white grey-scale pixel. */
    static byte[] blankPng() {
        ByteArrayOutputStream png = new ByteArrayOutputStream();
        png.write(new byte[] {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}, 0, 8);
        pngChunk(png, "IHDR", new byte[] {0, 0, 0, 1, 0, 0, 0, 1, 8, 0, 0, 0, 0});
        Deflater deflater = new Deflater();
        deflater.setInput(new byte[] {0, (byte) 0xff});
        deflater.finish();
        byte[] buffer = new byte[64];
        int length = deflater.deflate(buffer);
        deflater.end();
        pngChunk(png, "IDAT", Arrays.copyOf(buffer, length));
        pngChunk(png, "IEND", new byte[0]);
        return png.toByteArray();
    }

    private static void pngChunk(ByteArrayOutputStream png, String type, byte[] data) {
        byte[] name = type.getBytes(StandardCharsets.US_ASCII);
        writeInt(png, data.length, true);
        png.write(name, 0, name.length);
        png.write(data, 0, data.length);
        CRC32 crc = new CRC32();
        crc.update(name);
        crc.update(data);
        writeInt(png, (int) crc.getValue(), true);
    }

    /** A WAV header with no samples: 8 kHz, mono, 8-bit. */
    static byte[] silentWav() {
        ByteArrayOutputStream wav = new ByteArrayOutputStream();
        wav.write('R'); wav.write('I'); wav.write('F'); wav.write('F');
        writeInt(wav, 36, false);
        byte[] format = "WAVEfmt ".getBytes(StandardCharsets.US_ASCII);
        wav.write(format, 0, format.length);
        writeInt(wav, 16, false);
        writeShort(wav, 1);
        writeShort(wav, 1);
        writeInt(wav, 8000, false);
        writeInt(wav, 8000, false);
        writeShort(wav, 1);
        writeShort(wav, 8);
        wav.write('d'); wav.write('a'); wav.write('t'); wav.write('a');
        writeInt(wav, 0, false);
        return wav.toByteArray();
    }

    private static void writeInt(ByteArrayOutputStream out, int value, boolean bigEndian) {
        for (int i = 0; i < 4; i++) {
            int shift = bigEndian ? 24 - 8 * i : 8 * i;
            out.write((value >>> shift) & 0xff);
        }
    }

    private static void writeShort(ByteArrayOutputStream out, int value) {
        out.write(value & 0xff);
        out.write((value >>> 8) & 0xff);
    }
}
