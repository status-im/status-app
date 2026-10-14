import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components

import NimQtCamera 1.0
import NimQrScan 1.0

// StatusQrCodeScanner is presentation only; decoding is wired here the way
// the app's QRCodeScanner does it: FrameTap → QrScanner, cropped to the corners.
Item {
    id: root

    StatusQrCodeScanner {
        id: scanner

        anchors.fill: parent
        onNormalizedCaptureRectChanged: tap.applyRoi()
    }

    FrameTap {
        id: tap

        videoSink: scanner.videoSink
        enabled: scanner.capturing
        maxFps: 10
        maxDim: 1024

        function applyRoi() {
            const r = scanner.normalizedCaptureRect
            tap.setRoi(r.x, r.y, r.width, r.height)
        }

        Component.onCompleted: applyRoi()
    }

    QrScanner {
        frameSource: tap.handle
        scanning: tap.enabled
        onTagFound: tag => lastTag.text = tag
    }

    Rectangle {
        anchors.fill: row
    }

    RowLayout {
        id: row
        Label {
            id: lastTag
        }
    }
}

// category: Components
// status: good
