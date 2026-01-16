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

Column {
    id: root

    property list<StatusValidator> validators
    property alias cameraHeight: cameraLoader.height
    property alias cameraWidth: cameraLoader.width

    signal validTagFound(string tag)

    spacing: 12

    QtObject {
        id: d

        readonly property int radius: 16
        readonly property bool cameraReady: cameraPermission.status === Qt.Granted
        property string errorMessage
        property int counter: 0

        function validateTag(tag) {
            for (let i in root.validators) {
                const validator = root.validators[i]
                if (!validator.validate(tag)) {
                    d.errorMessage = validator.errorMessage
                    return
                }
            }
            d.errorMessage = ""
            root.validTagFound(tag)
        }
    }

    CameraPermission {
        id: cameraPermission
        Component.onCompleted: {
            if (cameraPermission.status !== Qt.PermissionStatus.Granted)
                cameraPermission.request()
        }
    }

    Loader {
        id: cameraLoader
        active: true
        anchors.horizontalCenter: parent.horizontalCenter
        width: 330
        height: 330

        sourceComponent: d.cameraReady ? cameraComponent : btnComponent
    }

    Component {
        id: btnComponent

        ShapeRectangle {
            anchors.fill: parent
            path.fillColor: Theme.palette.baseColor4
            radius: d.radius

            ColumnLayout {
                anchors.fill: parent
                spacing: 20

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr('Enable access to your camera')
                    leftPadding: 48
                    rightPadding: 48
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("To scan a QR, Status needs\naccess to your webcam")
                    leftPadding: 48
                    rightPadding: 48
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.palette.directColor4
                }

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                }
            }
        }
    }

    Component {
        id: cameraComponent
        StatusQrCodeScanner {
            anchors.fill: parent
            onLastTagChanged: {
                d.validateTag(lastTag)
            }
        }
    }

    Item {
        width: parent.width
        height: 8
    }

    StatusBaseText {
        visible: !!text
        width: parent.width
        height: visible ? implicitHeight : 0
        wrapMode: Text.WordWrap
        color: Theme.palette.dangerColor1
        horizontalAlignment: Text.AlignHCenter
        text: {
            if (!!d.errorMessage) {
                return d.errorMessage
            }
            if (cameraPermission.status === Qt.Denied) {
                return qsTr("Camera access denied. Please enable it in system settings.")
            }
            return ""
        }
    }

    StatusBaseText {
        visible: d.cameraReady && cameraLoader.item?.cameraAvailable
        width: parent.width
        height: visible ? implicitHeight : 0
        wrapMode: Text.WordWrap
        color: Theme.palette.baseColor1
        font.pixelSize: Theme.tertiaryTextFontSize
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("Ensure that the QR code is in focus to scan")
    }
}
