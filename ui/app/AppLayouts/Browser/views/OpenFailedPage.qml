import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

/// Shown in place of a Web View whose Opened File could not be shown.
Rectangle {
    id: root

    property string fileName

    signal supportedFormatsRequested()

    color: Theme.palette.background

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width - 2 * Theme.bigPadding, 420)
        spacing: Theme.halfPadding

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 161
            Layout.preferredHeight: 160
            source: Theme.style === Theme.Light
                    ? Assets.png("empty-states/onchain-friends-empty-light")
                    : Assets.png("empty-states/onchain-friends-empty-dark")
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        StatusBaseText {
            objectName: "openFailedText"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.directColor1
            text: qsTr("Couldn't open the file")
        }

        StatusBaseText {
            objectName: "openFailedFileName"
            Layout.fillWidth: true
            visible: !!root.fileName
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            font.pixelSize: Theme.additionalTextSize
            color: Theme.palette.baseColor1
            text: root.fileName
        }

        StatusLinkText {
            objectName: "openFailedFormatsLink"
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Theme.primaryTextFontSize
            normalColor: linkColor
            text: qsTr("View supported formats")
            onClicked: root.supportedFormatsRequested()
        }
    }
}
