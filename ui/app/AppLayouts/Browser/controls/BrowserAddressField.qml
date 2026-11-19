import QtQuick

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Components

import utils

StatusTextField {
    id: root

    objectName: "browserAddressField"

    required property url url
    required property bool incognitoMode
    required property color bgColor

    property url faviconUrl
    property bool showFavicon
    property bool loading

    /// Shown instead of the URL while the field is not being edited, such as
    /// an Opened File's name. Editing starts from the URL itself.
    property string label: ""
    readonly property string shownText: root.label || root.url.toString()

    readonly property url searchEngineIcon: Assets.svg(SearchEnginesConfig.getEngineIcon(localAccountSensitiveSettings.selectedBrowserSearchEngineId))

    implicitHeight: 40

    background: Rectangle {
        color: root.bgColor
        radius: Theme.radius
    }
    leftPadding: showFavicon ? Theme.halfPadding + favicon.width + favicon.anchors.leftMargin
                             : Theme.smallPadding
    rightPadding: clearButton.width
    placeholderText: qsTr("Search or enter address")
    color: root.incognitoMode ? Theme.palette.privacyColors.tertiary : Theme.palette.textColor

    inputMethodHints: (SQUtils.Utils.isIOS ? Qt.ImhNone : Qt.ImhUrlCharactersOnly) // iOS would hide the spacebar; space not being a valid URL character
                      | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData
    EnterKey.type: Qt.EnterKeyGo

    text: root.shownText
    onActiveFocusChanged: {
        if (activeFocus) {
            if (root.label)
                text = root.url.toString()
            selectAll()
        } else {
            if (text !== root.shownText && root.shownText !== "") // restore the old (non empty) address
                text = Qt.binding(() => root.shownText)
        }
    }

    StatusRoundedImage {
        id: favicon
        visible: root.showFavicon
        height: parent.height*.6
        width: height
        anchors.left: parent.left
        anchors.leftMargin: height/3
        anchors.verticalCenter: parent.verticalCenter
        image.source: {
            const edited = root.text !== root.shownText && root.text !== root.url.toString()
            if (edited || root.text === "") {
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
        anchors.verticalCenter: parent.verticalCenter
        visible: parent.cursorVisible && !!parent.text
        tooltip.orientation: StatusToolTip.Orientation.Bottom
        onClicked: {
            parent.forceActiveFocus()
            parent.clear()
        }
    }
}
