import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Controls

import utils
import ".."
import "../panels"

Item {
    id: root
    property bool isValid: true
    property alias errorMessage: txtValidationError.text
    property alias secondaryErrorMessage: txtValidationExtraInfo.text
    property var images: []
    property var validImages: []

    visible: !isValid
    width: imgExclamation.width + txtValidationError.width + txtValidationExtraInfo.width + 24
    height: txtValidationError.height + 14

    StatusBackgroundPanel {
        anchors.fill: parent

        SVGImage {
            id: imgExclamation
            width: 20
            height: 20
            sourceSize.height: height * 2
            sourceSize.width: width * 2
            verticalAlignment: Image.AlignVCenter
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 6
            anchors.leftMargin: 6
            fillMode: Image.PreserveAspectFit
            source: Assets.svg("exclamation_outline")
        }
        StyledText {
            id: txtValidationError
            verticalAlignment: Text.AlignVCenter
            anchors.top: parent.top
            anchors.left: imgExclamation.right
            anchors.topMargin: 7
            anchors.leftMargin: 6
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.additionalTextSize
            height: 18
            color: Theme.palette.dangerColor1
        }
        StyledText {
            id: txtValidationExtraInfo
            verticalAlignment: Text.AlignVCenter
            anchors.top: parent.top
            anchors.left: txtValidationError.right
            anchors.topMargin: 7
            anchors.leftMargin: 6
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.additionalTextSize
            height: 18
            color: Theme.palette.textColor
        }
    }
}
