import QtQuick
import QtTest

import StatusQ.Internal

/**
 * Capabilities of the browser Backend this build uses (ADR 0006 §8).
 * Answered without a Web View, so the singleton must be readable on its own.
 */
Item {
    TestCase {
        name: "BrowserBackendCapabilities"

        function test_inPageMediaPlaybackSupported_isTrueOnWebEngine() {
            compare(typeof BrowserBackendCapabilities.inPageMediaPlaybackSupported, "boolean")
            // This suite runs on the desktop (WebEngine) Backend.
            compare(BrowserBackendCapabilities.inPageMediaPlaybackSupported, true)
        }

        function test_pdfViewerSupported_isTrueOnWebEngine() {
            compare(typeof BrowserBackendCapabilities.pdfViewerSupported, "boolean")
            // This suite runs on the desktop (WebEngine) Backend.
            compare(BrowserBackendCapabilities.pdfViewerSupported, true)
        }
    }
}
