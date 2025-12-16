import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Popups

import utils

ToolButton {
    id: root

    /*required */property int sectionType // cf Constants.appSection.*
    property bool hasNotification
    property int notificationsCount
    property bool pinned
    property color badgeColor: Theme.palette.primaryColor1
    property url connectorBadge
    property int chatType: Constants.chatType.unknown
    property int onlineStatus: Constants.onlineStatus.unknown
    property string tooltipText: Utils.translatedSectionName(sectionType, "")

    signal itemPinRequested(string key, bool pin)
    signal dappDisconnectRequested(string dappUrl)

    implicitWidth: 64
    implicitHeight: 64

    padding: Theme.defaultSmallPadding
    opacity: pressed || down ? ThemeUtils.pressedOpacity : enabled ? 1 : ThemeUtils.disabledOpacity
    Behavior on opacity { NumberAnimation { duration: ThemeUtils.AnimationDuration.Fast } }

    icon.width: 36
    icon.height: 36

    background: Rectangle {
        id: background
        color: hovered ? Theme.palette.directColor7 : Theme.palette.directColor8
        Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
        radius: Theme.defaultSmallPadding * 2

        // top right corner
        StatusBadge {
            width: root.notificationsCount ? implicitWidth : 12 + border.width // bigger dot
            height: root.notificationsCount ? implicitHeight : 12 + border.width
            border.width: 2
            border.color: parent.color
            Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
            anchors.right: parent.right
            anchors.rightMargin: root.notificationsCount ? -2 : 0
            anchors.top: parent.top
            anchors.topMargin: root.notificationsCount ? -2 : 0
            visible: root.hasNotification
            value: root.notificationsCount
        }
    }

    contentItem: StatusSmartIdenticon {
        asset.width: root.icon.width
        asset.height: root.icon.height
        asset.letterSize: Theme.secondaryAdditionalTextSize
        asset.emoji: root.pinned && (root.sectionType === Constants.appSection.wallet || root.chatType === Constants.chatType.communityChat) ? root.icon.name : ""
        asset.color: root.icon.color
        Behavior on asset.color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
        asset.name: asset.emoji ? "" : root.icon.name
        asset.bgRadius: root.pinned && root.sectionType === Constants.appSection.wallet ? Theme.defaultPadding : asset.bgWidth/2
        name: root.text

        Binding on asset.bgColor { // need some round background around the icon
            value: Theme.palette.primaryColor3
            when: root.pinned && (root.sectionType === Constants.appSection.dApp || root.sectionType === Constants.appSection.profile)
        }

        hoverEnabled: false

        // for dApps
        bridgeBadge {
            image.source: root.connectorBadge
            border.width: 0
            implicitHeight: 16
            implicitWidth: 16
            anchors.rightMargin: 1
            anchors.bottomMargin: 1
        }
        bridgeBadge.visible: root.connectorBadge != "" && !bridgeBadge.isError

        // for chat items
        badge {
            visible: root.chatType === Constants.chatType.oneToOne && root.onlineStatus !== Constants.onlineStatus.unknown
            color: root.onlineStatus === Constants.onlineStatus.online ? Theme.palette.successColor1
                                                                       : Theme.palette.baseColor1
            border.width: 1
            border.color: background.color
            implicitHeight: 10
            implicitWidth: 10
            anchors.rightMargin: 1
            anchors.bottomMargin: 1
        }
    }

    StatusToolTip {
        visible: !!text && root.hovered
        offset: -(x + width/2 - root.width/2)
        text: root.tooltipText
    }

    onPressAndHold: if (root.pinned) contextMenuComponent.createObject(root).popup(root.pressX, root.pressY)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        acceptedButtons: Qt.RightButton
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
        onClicked: if (root.pinned) contextMenuComponent.createObject(root).popup()
    }

    Component {
        id: contextMenuComponent
        StatusMenu {
            objectName: "homeDockButtonCtxMenu"
            StatusAction {
                objectName: "unpinAction"
                icon.name: "unpin"
                text: qsTr("Unpin")
                onTriggered: root.itemPinRequested(model.key, false)
            }
            StatusAction {
                objectName: "disconnectAction"
                enabled: root.sectionType === Constants.appSection.dApp
                icon.name: "disconnect"
                text: qsTr("Disconnect")
                onTriggered: root.dappDisconnectRequested(model.id)
            }
            onClosed: destroy()
        }
    }
}
