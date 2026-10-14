import QtQuick
import QtTest

import StatusQ.Core.Utils as SQUtils

// Scan rectangle (item coordinates) → normalized video-frame coordinates, as
// StatusQrCodeCapture feeds it to the frame tap's ROI. VideoOutput's
// contentRect is the scaled video in item coordinates; with
// PreserveAspectCrop it is larger than the item and centered on it.
TestCase {
    name: "StatusQrCodeCapture"

    function compareRect(actual, x, y, w, h) {
        fuzzyCompare(actual.x, x, 1e-6, "x")
        fuzzyCompare(actual.y, y, 1e-6, "y")
        fuzzyCompare(actual.width, w, 1e-6, "width")
        fuzzyCompare(actual.height, h, 1e-6, "height")
    }

    function map(content, item, mirrored) {
        return SQUtils.Utils.mapItemRectToVideoFrame(content, item, mirrored)
    }

    function test_sameAspect() {
        compareRect(map(Qt.rect(0, 0, 400, 300), Qt.rect(100, 75, 200, 150), false),
                    0.25, 0.25, 0.5, 0.5)
    }

    function test_sourceWiderIsCroppedLeftRight() {
        // 4:3 video in a 300x300 item: scaled to 400x300, centered (x = -50)
        compareRect(map(Qt.rect(-50, 0, 400, 300), Qt.rect(50, 50, 200, 200), false),
                    0.25, 50 / 300, 0.5, 200 / 300)
    }

    function test_sourceTallerIsCroppedTopBottom() {
        compareRect(map(Qt.rect(0, -50, 300, 400), Qt.rect(50, 50, 200, 200), false),
                    50 / 300, 0.25, 200 / 300, 0.5)
    }

    function test_mirroredPreviewFlipsX() {
        // the left quarter on screen is the right quarter of the frame
        compareRect(map(Qt.rect(0, 0, 400, 300), Qt.rect(0, 0, 100, 300), true),
                    0.75, 0, 0.25, 1)
    }

    function test_emptyMeansWholeFrame() {
        compareRect(map(Qt.rect(0, 0, 400, 300), Qt.rect(0, 0, 0, 0), false), 0, 0, 1, 1)
        compareRect(map(Qt.rect(0, 0, 0, 0), Qt.rect(10, 10, 50, 50), false), 0, 0, 1, 1)
    }

    function test_clampedToTheFrame() {
        compareRect(map(Qt.rect(0, 0, 400, 300), Qt.rect(-100, -100, 300, 250), false),
                    0, 0, 0.5, 0.5)
    }
}
