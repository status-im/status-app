import QtQuick

import StatusQ.Core
import StatusQ.Components as StatusQ
import StatusQ.Core.Theme

import shared
import shared.panels
import shared.status

import utils

Item {
    property url webUrl
    property url source
    property string text

    signal clicked(var mouse)
    signal rightClicked(var mouse)

    id: root
    width: 74
    height: 48 + Theme.halfPadding

    SVGImage {
        id: bookmarkImage
        width: 48
        height: 48
        anchors.horizontalCenter: parent.horizontalCenter
        source: !!root.source && !!root.source.toString() ? root.source : Assets.svg("compassActive")
        visible: root.source && root.source.toString()
    }

    StatusQ.StatusRoundIcon {
        id: addButton
        anchors.horizontalCenter: parent.horizontalCenter
        asset.name: "add"
        asset.color: Theme.palette.baseColor1
        color: Theme.palette.baseColor2
        visible: !webUrl.toString()
    }

    StatusQ.StatusLetterIdenticon {
        id: identicon
        anchors.horizontalCenter: parent.horizontalCenter
        letterIdenticonColor: Theme.palette.baseColor2
        identiconText.text: text.charAt(0)
        identiconText.color: Theme.palette.baseColor1
        visible: !bookmarkImage.visible && !addButton.visible
    }

    StyledText {
        id: bookmarkName
        text: root.text
        width: 67
        anchors.top: bookmarkImage.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.additionalTextSize
        wrapMode: Text.WordWrap
        anchors.topMargin: Theme.halfPadding
        maximumLineCount: 2
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }

    StatusMouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked(mouse)
            } else {
                root.clicked(mouse)
            }
        }
    }
}
