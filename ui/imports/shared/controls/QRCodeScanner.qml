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
import StatusQ.Popups.Dialog

import MobileUI
import NimQtCamera
import NimQrScan

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

    readonly property bool cameraReady: d.cameraReady

    signal validTagFound(string tag)

    readonly property alias imageErrorMessage: d.imageErrorMessage

    // Decodes the QR codes in a local image file (what "Upload image" picks):
    // the codes go through the validators like camera codes. Ignored once a
    // result was accepted or a validator error shows (state !== None).
    function scanImageFile(url) {
        if (root.state !== StatusQrCodeScanner.State.None)
            return
        d.clearImageError()
        imageDecoder.decodeFile(url)
    }

    // Starts a new scanning session: after a result (Success) or an error the
    // scanner stays idle until reset, so a reused dialog calls this on opening.
    // An image still decoding belongs to the old session and is dropped.
    function reset() {
        imageDecoder.cancel()
        errorTimer.stop()
        errorClearTimer.stop()
        d.rejectedTags = ({})
        d.errorMessage = ""
        d.clearImageError()
        root.state = StatusQrCodeScanner.State.None
    }

    spacing: Theme.padding / 1.4

    onVisibleChanged: {
        if (!visible) {
            imageDecoder.cancel()
            d.clearImageError()
        }
    }

    QtObject {
        id: d

        readonly property int radius: 16
        readonly property bool cameraReady: !root.cameraPermissionDenied && root.cameraAccess.granted
        readonly property bool imagePickerEnabled: root.state === StatusQrCodeScanner.State.None
                                                   && !imageDecoder.busy
        property string errorMessage
        property string imageErrorMessage
        property int counter: 0

        property var rejectedTags: ({})
        readonly property int rejectedTagGoneMs: 1000

        // Whether errorMessage is about a camera code: it stays while the code
        // is in view and clears once it is gone. A rejected image code's
        // message lasts imageErrorDurationMs, like the other image errors.
        property bool cameraError: false

        // The Error state pauses decoding: the rejected codes still in view
        // count as seen when it ends, or the pause would read as "gone".
        function refreshRejectedTags() {
            const now = Date.now()
            for (const tag in d.rejectedTags)
                d.rejectedTags[tag] = now
        }

        readonly property int imageErrorDurationMs: 4000

        readonly property string imageNameFilters: {
            const lower = "*.jpg *.jpeg *.jpe *.png" + (imageDecoder.heicSupported ? " *.heic *.heif" : "")
            return lower + " " + lower.toUpperCase()
        }

        function showImageError(message) {
            d.errorMessage = "" // replaces a lingering validator message
            d.imageErrorMessage = message
            imageErrorTimer.restart()
        }

        function clearImageError() {
            imageErrorTimer.stop()
            d.imageErrorMessage = ""
        }

        function passesValidators(tag) {
            for (let i in root.validators) {
                if (!root.validators[i].validate(tag))
                    return false
            }
            return true
        }

        function validateTag(tag) {
            d.clearImageError()
            for (let i in root.validators) {
                const validator = root.validators[i]
                if (!validator.validate(tag)) {
                    root.state = StatusQrCodeScanner.State.Error
                    d.errorMessage = validator.errorMessage
                    errorClearTimer.stop()
                    errorTimer.start()
                    MobileUI.vibrate() // with the error, as on success
                    return false
                }
            }
            d.errorMessage = ""
            // before the signal: a handler may move on and tear the scanner down
            MobileUI.vibrate()
            root.validTagFound(tag)
            root.state = StatusQrCodeScanner.State.Success
            return true
        }
    }

    Timer {
        id: errorTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            d.refreshRejectedTags()
            root.state = StatusQrCodeScanner.State.None
            errorClearTimer.interval = d.cameraError ? d.rejectedTagGoneMs
                                                     : d.imageErrorDurationMs - errorTimer.interval
            errorClearTimer.restart()
        }
    }

    Timer {
        id: errorClearTimer
        onTriggered: d.errorMessage = ""
    }

    Timer {
        id: imageErrorTimer
        interval: d.imageErrorDurationMs
        onTriggered: d.imageErrorMessage = ""
    }

    QrImageDecoder {
        id: imageDecoder
        objectName: "qrImageDecoder"

        onDecoded: (texts, undecodable) => {
            if (root.state !== StatusQrCodeScanner.State.None)
                return // a result was accepted meanwhile (one per session)
            if (texts.length === 0) {
                d.showImageError(undecodable > 0 ? qsTr("Couldn't read the QR code")
                                                 : qsTr("No QR code found in the image"))
                return
            }
            // The first code the validators accept; else the first one, so the
            // validator's own error shows (as for a camera code).
            d.cameraError = false
            d.validateTag(texts.find(t => d.passesValidators(t)) ?? texts[0])
        }

        onFailed: (kind, message) => {
            if (root.state !== StatusQrCodeScanner.State.None)
                return
            if (kind === "unsupported")
                d.showImageError(imageDecoder.heicSupported
                                 ? qsTr("Unsupported format. Select a JPG, PNG, or HEIC image")
                                 : qsTr("Unsupported format. Select a JPG or PNG image"))
            else
                d.showImageError(qsTr("Couldn't open the image"))
        }
    }

    StatusFileDialog {
        id: imageDialog
        objectName: "qrImageFileDialog"

        title: qsTr("Please choose an image")
        currentFolder: picturesShortcut
        usePhotoLibrary: true
        nameFilters: [qsTr("Image files (%1)").arg(d.imageNameFilters)]

        onAccepted: root.scanImageFile(selectedFile)
    }

    Timer {
        id: permissionTimer
        interval: 500
        onTriggered: root.cameraAccess.request()
    }

    Component.onCompleted: {
        // Wait before requesting the permission, so the view comes up after
        // the animation before the OS popup freezes the UI. canRequest: also
        // after an ordinary denial on Android, where the OS may ask again.
        if (!root.cameraPermissionDenied && root.cameraAccess.canRequest)
            permissionTimer.start()
    }

    Loader {
        id: cameraLoader
        objectName: "qrCameraArea"
        active: true
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.fillHeight: true

        sourceComponent: d.cameraReady ? cameraComponent : btnComponent
    }

    Component {
        id: btnComponent

        Item {
            anchors.fill: parent

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
                    objectName: "openCameraSettingsButton"
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

            StatusButton {
                objectName: "qrUploadImageButton"
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    margins: 10
                }
                width: 40
                height: 40
                normalColor: Theme.palette.baseColor5
                hoverColor: Theme.palette.hoverColor(normalColor)
                icon.name: "select-image"
                tooltip.text: qsTr("Upload image")
                enabled: d.imagePickerEnabled
                onClicked: imageDialog.open()
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

            imagePickerVisible: true
            imagePickerEnabled: d.imagePickerEnabled
            onImagePickerRequested: imageDialog.open()

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
                    const a = scanner.captureArea
                    tap.setPreviewRoi(a.x, a.y, a.width, a.height, a.previewWidth,
                                      a.previewHeight, a.fillMode, a.mirrored)
                }

                Component.onCompleted: applyRoi()
            }

            onCaptureAreaChanged: tap.applyRoi()

            QrScanner {
                frameSource: tap.handle
                scanning: tap.enabled
                // One code per scan: a frame can hold several.
                onTagFound: tag => {
                    if (root.state !== StatusQrCodeScanner.State.None)
                        return
                    const now = Date.now()
                    const seen = d.rejectedTags[tag]
                    if (seen !== undefined && now - seen <= d.rejectedTagGoneMs) {
                        d.rejectedTags[tag] = now // still in view
                        if (d.cameraError && errorClearTimer.running)
                            errorClearTimer.restart() // its error stays
                        return
                    }
                    d.cameraError = true
                    if (d.validateTag(tag))
                        delete d.rejectedTags[tag]
                    else
                        d.rejectedTags[tag] = now
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
        id: errorText
        objectName: "qrScannerErrorText"
        Layout.fillWidth: true

        visible: !!text
        wrapMode: Text.WordWrap
        color: Theme.palette.dangerColor1
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        // the latest message: each kind clears the other when it is set
        text: d.imageErrorMessage || d.errorMessage
    }

    StatusBaseText {
        Layout.fillWidth: true

        // one message at a time: not next to an error
        visible: d.cameraReady && !!cameraLoader.item?.cameraAvailable
                 && root.state === StatusQrCodeScanner.State.None && !errorText.visible
        wrapMode: Text.WordWrap
        color: Theme.palette.directColor1
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("Align the QR code within the frame to scan")
    }
}
