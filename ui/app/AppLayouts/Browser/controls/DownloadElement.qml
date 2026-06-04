import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import utils
import shared.panels

Rectangle {
    id: root

    property bool downloadComplete: false
    property bool isCanceled: false
    property bool isPaused: false
    property bool hovered: false
    // use this to place the newest downloads first
    property int reversedIndex: listView.count - 1 - index
    property string primaryText: ""
    property string downloadText: ""

    signal optionsButtonClicked(int xVal)
    signal itemClicked()

    width: 272
    height: 40
    border.width: 0
    color: hovered ? Theme.palette.backgroundHover : StatusColors.transparent
    radius: Theme.radius

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: {
           root.hovered = true
        }
        onExited: {
            root.hovered = false
        }
        onClicked: {
            itemClicked()
        }
    }

    Loader {
        id: iconLoader
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.smallPadding
        active: root.visible
        sourceComponent: {
            if (downloadComplete || isPaused || isCanceled) {
                return fileImageComponent
            }
            return loadingImageComponent
        }

        Component {
            id: loadingImageComponent
            StatusLoadingIndicator {}
        }
        Component {
            id: fileImageComponent
            StatusIcon {
                icon: "file"
                color: downloadComplete ? StatusColors.transparent : Theme.palette.darkGrey
            }
        }
    }

    StyledText {
        id: filenameText
        text: primaryText
        elide: Text.ElideRight
        anchors.left: iconLoader.right
        anchors.right: optionsBtn.left
        anchors.top:  downloadComplete ? undefined : parent.top
        anchors.verticalCenter: downloadComplete ? parent.verticalCenter : undefined
        minimumPixelSize: 13
        anchors.leftMargin: Theme.smallPadding
        anchors.topMargin: 2
    }

    StyledText {
        id: progressText
        visible:  !downloadComplete
        color: Theme.palette.secondaryText
        text: downloadText
        elide: Text.ElideRight
        anchors.left: iconLoader.right
        anchors.right: optionsBtn.left
        anchors.bottom: parent.bottom
        minimumPixelSize: 13
        anchors.leftMargin: Theme.smallPadding
        anchors.bottomMargin: 2
    }

    StatusFlatRoundButton {
        width: 32
        height: 32
        id: optionsBtn
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.smallPadding
        icon.name: "more"
        type: StatusFlatRoundButton.Type.Tertiary
        onClicked: optionsButtonClicked(optionsBtn.x)
    }
}

