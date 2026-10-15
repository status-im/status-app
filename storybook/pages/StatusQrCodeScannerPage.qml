import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components

import Storybook

import NimQtCamera 1.0
import NimQrScan 1.0

// StatusQrCodeScanner is presentation only; decoding is wired here the way
// the app's QRCodeScanner does it: FrameTap → QrScanner, cropped to the corners.
SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    StatusQrCodeScanner {
        id: scanner

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        onNormalizedCaptureRectChanged: tap.applyRoi()

        FrameTap {
            id: tap

            videoSink: scanner.videoSink
            enabled: scanner.capturing
            maxFps: 10
            maxDim: 1024

            function applyRoi() {
                const r = scanner.normalizedCaptureRect
                tap.setDisplayRoi(r.x, r.y, r.width, r.height)
            }

            Component.onCompleted: applyRoi()
        }

        QrScanner {
            frameSource: tap.handle
            scanning: tap.enabled
            onTagFound: tag => logs.logEvent("tagFound", ["tag"], [tag])
            onDecodeError: message => logs.logEvent("decodeError", ["message"], [message])
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 150

        logsView.logText: logs.logText
    }
}

// category: Components
// status: good
