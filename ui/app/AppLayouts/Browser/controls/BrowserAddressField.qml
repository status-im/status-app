import QtQuick

import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import utils

StatusTextField {
    id: root

    required property url url
    required property bool incognitoMode
    required property color bgColor

    property url faviconUrl
    property bool showFavicon
    property bool loading

    readonly property url searchEngineIcon: Assets.svg(SearchEnginesConfig.getEngineIcon(localAccountSensitiveSettings.selectedBrowserSearchEngineId))

    implicitHeight: 36

    background: Rectangle {
        color: root.bgColor
        radius: 40
    }
    verticalAlignment: TextInput.AlignVCenter
    leftPadding: showFavicon ? Theme.halfPadding + favicon.width + favicon.anchors.leftMargin
                             : Theme.padding
    rightPadding: Theme.halfPadding + clearButton.width
    placeholderText: qsTr("Search or enter address")
    font.pixelSize: Theme.additionalTextSize
    color: root.incognitoMode ? Theme.palette.privacyColors.tertiary : Theme.palette.textColor

    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
    EnterKey.type: Qt.EnterKeyGo

    text: root.url
    onActiveFocusChanged: {
        if (activeFocus) {
            selectAll()
        } else {
            if (text === "") // restore the old URL
                text = Qt.binding(() => root.url)
        }
    }

    StatusRoundedImage {
        id: favicon
        visible: root.showFavicon
        height: parent.height/2
        width: height
        anchors.left: parent.left
        anchors.leftMargin: Theme.halfPadding
        anchors.verticalCenter: parent.verticalCenter
        image.sourceSize: Qt.size(width, height)
        image.source: {
            if (root.url.toString() !== root.text || root.text === "") {
                return root.searchEngineIcon
            }

            if (root.showFavicon) {
                if (root.faviconUrl.toString() !== "" )
                    return root.faviconUrl
                return Assets.svg("globe")
            }

            return root.searchEngineIcon
        }
    }

    StatusClearButton {
        id: clearButton
        anchors.right: parent.right
        anchors.rightMargin: Theme.halfPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: parent.cursorVisible && !!parent.text
        icon.width: 18
        icon.height: 18
        tooltip.orientation: StatusToolTip.Orientation.Bottom
        onClicked: {
            parent.forceActiveFocus()
            parent.clear()
        }
    }
}
