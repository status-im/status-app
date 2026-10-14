import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import MobileUI
import NimQtCamera 1.0
import NimQrScan 1.0

import utils

/*
    NOTE:   I'm doing some crazy workarounds here. Tested on MacOS.
            What I wanted to achieve:

            1. User only gets a OS "allow camera access" popup
               when a page with QR code scanner is opened.
            2. Mimize UI freezes, or at least make it obvious
               that something is going on.

    Camera component uses main UI thread to request OS for available devices.
    Therefore, we can't simply use Loader with `asyncronous` flag.
    Neiter we can set `loading: qrCodeScanner.status === Loader.Loading` to this button.

    To achieve desired points, I manually set `loading` property of the button
    and delay the camera loading for 250ms. UI quickly shows loading indicator,
    then it will freeze until the camera is loaded.

    I think this can only be improved by moving the OS requests to another thread from C++.

    We also don't yet have ability to auto-detect if the camera access was already enabled.
    So we show `Scan QR` button everytime.
*/

ColumnLayout {
    id: root

    property list<StatusValidator> validators
    property int state: StatusQrCodeScanner.State.None

    // This property is used in Storybook to simulate camera access being denied
    property bool cameraPermissionDenied: false

    // Camera permission (status, request, OS settings). Tests pass a fake.
    property QtObject cameraAccess: CameraAccess {}

    signal validTagFound(string tag)

    spacing: Theme.padding / 1.4

    QtObject {
        id: d

        readonly property int radius: 16
        readonly property bool cameraReady: !root.cameraPermissionDenied && root.cameraAccess.granted
        property string errorMessage
        property int counter: 0

        function validateTag(tag) {
            for (let i in root.validators) {
                const validator = root.validators[i]
                if (!validator.validate(tag)) {
                    root.state = StatusQrCodeScanner.State.Error
                    d.errorMessage = validator.errorMessage
                    errorTimer.start()
                    return
                }
            }
            d.errorMessage = ""
            root.validTagFound(tag)
            MobileUI.vibrate()
            root.state = StatusQrCodeScanner.State.Success
        }
    }

    Timer {
        id: errorTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            MobileUI.vibrate()
            root.state = StatusQrCodeScanner.State.None
        }
    }

    Timer {
        id: permissionTimer
        interval: 500
        onTriggered: root.cameraAccess.request()
    }

    Component.onCompleted: {
        // Wait before requesting the permission, so the view comes up after
        // the animation before the OS popup freezes the UI
        if (!root.cameraPermissionDenied && root.cameraAccess.status === "undetermined")
            permissionTimer.start()
    }

    Loader {
        id: cameraLoader
        active: true
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.fillHeight: true

        sourceComponent: d.cameraReady ? cameraComponent : btnComponent
    }

    Component {
        id: btnComponent

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.smallPadding / 2

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
            }

            Image {
                Layout.alignment: Qt.AlignHCenter

                // Temporary image
                source: (Theme.style === Theme.Light) ? Assets.png("activity_center/NewsDisabled-Light") :
                                                        Assets.png("activity_center/NewsDisabled-Dark")
                fillMode: Image.PreserveAspectFit
                Layout.preferredWidth: 80
                mipmap: true
                cache: false
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr('Enable access to your camera')
                font.weight: Font.Medium
                leftPadding: Theme.bigPadding
                rightPadding: Theme.bigPadding
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("To scan QR codes, add contacts, send funds to wallets, and sync apps.")
                leftPadding: Theme.bigPadding
                rightPadding: Theme.bigPadding
                font.pixelSize: Theme.additionalTextSize
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StatusButton {
                text: qsTr("Open settings")
                // The OS page where camera access is granted; Linux has none
                // (and no camera permission to deny).
                visible: root.cameraAccess.canOpenSettings
                size: StatusBaseButton.Size.Tiny
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.smallPadding
                onClicked: root.cameraAccess.openSettings()
            }

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
            }
        }
    }

    Component {
        id: cameraComponent

        StatusQrCodeScanner {
            id: scanner

            objectName: "statusQrCodeScanner"
            state: root.state
            anchors.fill: parent

            // Pulls grayscale frames from the preview, at most `maxFps`
            // while the camera runs and nothing is accepted yet, cropped to
            // the scan corners. QrScanner drops a decode still running when
            // this turns false (hidden, app inactive).
            FrameTap {
                id: tap

                videoSink: scanner.videoSink
                enabled: scanner.capturing && root.state === StatusQrCodeScanner.State.None
                maxFps: 10
                maxDim: 1024

                function applyRoi() {
                    const r = scanner.normalizedCaptureRect
                    tap.setRoi(r.x, r.y, r.width, r.height)
                }

                Component.onCompleted: applyRoi()
            }

            onNormalizedCaptureRectChanged: tap.applyRoi()

            QrScanner {
                frameSource: tap.handle
                scanning: tap.enabled
                // One code per scan: a frame can hold several.
                onTagFound: tag => {
                    if (root.state === StatusQrCodeScanner.State.None)
                        d.validateTag(tag)
                }
            }
        }
    }

    StatusBaseText {
        text: qsTr("Scanned successfully")
        color: Theme.palette.primaryColor1
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        visible: root.state === StatusQrCodeScanner.State.Success
    }

    StatusBaseText {
        Layout.fillWidth: true

        visible: !!text
        wrapMode: Text.WordWrap
        color: Theme.palette.dangerColor1
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        text: {
            if (!!d.errorMessage) {
                return d.errorMessage
            }
            return ""
        }
    }

    StatusBaseText {
        Layout.fillWidth: true

        visible: d.cameraReady && !!cameraLoader.item?.cameraAvailable && root.state === StatusQrCodeScanner.State.None
        wrapMode: Text.WordWrap
        color: Theme.palette.baseColor1
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("Align the QR code within the frame to scan")
    }
}
