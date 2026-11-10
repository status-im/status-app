pragma Singleton

import QtQuick

/// Names for the file types Status claims in "Open with"
/// (mobile/android/qt6/AndroidManifest.xml).
QtObject {
    /// How the offer to open a type in Status names it; "" for any other type.
    function name(mimeType) {
        switch (String(mimeType ?? "").toLowerCase()) {
        case "application/pdf": return qsTr("PDFs")
        case "image/png": return qsTr("PNG images")
        case "image/jpeg": return qsTr("JPEG images")
        case "image/gif": return qsTr("GIF images")
        case "image/webp": return qsTr("WebP images")
        case "image/bmp":
        case "image/x-ms-bmp": return qsTr("BMP images")
        case "text/plain": return qsTr("text files")
        case "application/json": return qsTr("JSON files")
        case "audio/mpeg":
        case "audio/mp3": return qsTr("MP3 audio")
        case "audio/wav":
        case "audio/x-wav":
        case "audio/wave": return qsTr("WAV audio")
        case "audio/webm": return qsTr("WebM audio")
        case "video/webm": return qsTr("WebM videos")
        case "video/mp4": return qsTr("MP4 videos")
        case "video/x-m4v": return qsTr("M4V videos")
        case "audio/mp4":
        case "audio/x-m4a": return qsTr("M4A audio")
        case "audio/aac": return qsTr("AAC audio")
        default: return ""
        }
    }

    /// The names of the types, each once, in order.
    function names(mimeTypes) {
        const out = []
        for (const type of mimeTypes ?? []) {
            const n = name(type)
            if (n && !out.includes(n))
                out.push(n)
        }
        return out.join(", ")
    }
}
