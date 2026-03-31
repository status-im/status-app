import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

import utils

Control {
    id: root

    required property bool signingPurpose
    required property bool isKeycardKeyPair

    property bool failed: false

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Image {
            id: image
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            source: root.failed ? Assets.png("keycard/biometrics-fail")
                                : Assets.png("keycard/biometrics-success")
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        StatusBaseText {
            id: title
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
            text: root.failed ? qsTr("Biometric %1 failed").arg(root.signingPurpose? qsTr("signing") : qsTr("authentication"))
                              : qsTr("%1 with biometrics").arg(root.signingPurpose? qsTr("Signing") : qsTr("Authentication"))
        }

        StatusBaseText {
            id: message
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.failed
            text: qsTr("Use your %1 instead").arg(root.isKeycardKeyPair? qsTr("PIN") : qsTr("password"))
            color: Theme.palette.baseColor1
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
