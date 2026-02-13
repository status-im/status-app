import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import MobileUI

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

    signal validTagFound(string tag)

    spacing: Theme.padding / 1.4

    QtObject {
        id: d

        readonly property int radius: 16
        readonly property bool cameraReady: !root.cameraPermissionDenied && cameraPermission.status === Qt.Granted
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

    CameraPermission {
        id: cameraPermission
        Component.onCompleted: {
            if (root.cameraPermissionDenied) {
                return
            }

            if (cameraPermission.status !== Qt.PermissionStatus.Granted)
                cameraPermission.request()
        }
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
                // Opening app settings is only supported on mobile
                // This screen shouldn't be shown on desktop anyway
                visible: SQUtils.Utils.isMobile
                size: StatusBaseButton.Size.Tiny
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.smallPadding
                onClicked: SystemUtils.openAppSettings()
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
            state: root.state
            anchors.fill: parent
            onLastTagChanged: {
                d.validateTag(lastTag)
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
        visible: !!text
        width: parent.width
        height: visible ? implicitHeight : 0
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
        visible: d.cameraReady && !!cameraLoader.item?.cameraAvailable && root.state === StatusQrCodeScanner.State.None
        width: parent.width
        height: visible ? implicitHeight : 0
        wrapMode: Text.WordWrap
        color: Theme.palette.baseColor1
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("Align the QR code within the frame to scan")
    }
}
