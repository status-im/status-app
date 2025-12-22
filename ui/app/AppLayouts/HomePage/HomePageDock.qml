import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core.Theme

import utils

import QtModelsToolkit

Control {
    id: root

    /**
      Expected model structure

      Common data:
        key                 [string] - unique identifier of a section across all models, e.g "1;0x3234235"
        id                  [string] - id of this section
        sectionType         [int]    - type of this section (Constants.appSection.*)
        name                [string] - section's name, e.g. "Chat" or "Wallet" or a community name
        icon                [string] - section's icon (url like or blob)
        color               [color]  - the section's color
        banner              [string] - the section's banner image (url like or blob), mostly empty for non-communities
        hasNotification     [bool]   - whether the section has any notification (w/o denoting the number)
        notificationsCount  [int]    - number of notifications, if any
        enabled             [bool]   - whether the section should show in the UI

      Communities:
        members             [int]   - number of members
        activeMembers       [int]   - number of active members
        pending             [bool]  - whether a request to join/spectate is in effect
        banned              [bool]  - whether we are kicked/banned from this community

      Chats:
        chatType            [int]   - type of the chat (Constants.chatType.*)
        onlineStatus        [int]   - online status of the contact (Constants.onlineStatus.*)

      Wallets:
        walletType          [string] - type of the wallet (Constants.*WalletType)
        currencyBalance     [string] - user formatted balance of the wallet in fiat (e.g. "1 000,23 CZK")

      Dapps:
        connectorBadge      [string] - decoration image for the connector used

      Settings:
        isExperimental      [bool]   - whether the section is experimental (shows the Beta badge)
    **/
    required property var sectionsModel
    /**
      Expected model structure; same as above with two extra writable roles:
        pinned             [bool]   - whether the item is pinned in the UI
        timestamp          [int]    - timestamp of the last user interaction with the item
    **/
    required property var pinnedModel

    signal itemActivated(string key, int sectionType, string itemId)
    signal itemPinRequested(string key, bool pin)
    signal dappDisconnectRequested(string dappUrl)

    padding: Theme.defaultSmallPadding
    spacing: Theme.defaultSmallPadding

    background: Rectangle {
        color: Theme.palette.baseColor4
        radius: Theme.defaultSmallPadding * 2
    }

    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 4
        radius: 12
        samples: 25
        spread: 0
        color: Theme.palette.dropShadow
    }

    implicitHeight: 84 // by design

    Component.onCompleted: d.componentComplete = true

    QtObject {
        id: d
        property bool componentComplete
    }

    contentItem: ListView {
        implicitWidth: contentWidth
        clip: true
        orientation: ListView.Horizontal
        model: ConcatModel {
            sources: [
                SourceModel {
                    model: root.sectionsModel
                    markerRoleValue: false
                },
                SourceModel {
                    model: root.pinnedModel
                    markerRoleValue: true
                }
            ]
            markerRoleName: "pinnable"
        }

        spacing: root.spacing
        interactive: contentWidth > width
        delegate: Loader {
            id: delegateLoader
            objectName: "homeDockButtonLoader"

            required property var model
            required property int index

            sourceComponent: model.pinnable ? pinnedDockButton : regularDockButton

            SequentialAnimation {
                id: removeAnimation
                PropertyAction { target: delegateLoader; property: "ListView.delayRemove"; value: true }
                NumberAnimation { target: delegateLoader; property: "scale"; to: 0; duration: ThemeUtils.AnimationDuration.Default; easing.type: Easing.InOutQuad }
                PropertyAction { target: delegateLoader; property: "ListView.delayRemove"; value: false }
            }

            ListView.onRemove: removeAnimation.start()
        }

        Behavior on implicitWidth {
            enabled: d.componentComplete
            PropertyAnimation { duration: ThemeUtils.AnimationDuration.Fast }
        }
    }

    Component {
        id: regularDockButton

        HomePageDockButton {
            objectName: "regularDockButton" + model.name
            sectionType: model.sectionType
            text: model.name
            hasNotification: model.hasNotification ?? false
            notificationsCount: model.notificationsCount ?? 0
            connectorBadge: model.connectorBadge ?? ""
            icon.color: hovered ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
            icon.name: model.icon
            enabled: model.enabled
            onClicked: root.itemActivated(model.key, sectionType, "") // not interested in item (section) id here
        }
    }

    Component {
        id: pinnedDockButton

        HomePageDockButton {
            objectName: "pinnedDockButton" + model.name
            id: pinnedDelegate
            sectionType: model.sectionType
            text: model.name
            hasNotification: model.hasNotification ?? false
            notificationsCount: model.notificationsCount ?? 0
            connectorBadge: model.connectorBadge ?? ""
            icon.name: model.icon
            icon.color: model.color ?? Theme.palette.directColor1
            icon.width: 24
            icon.height: 24
            tooltipText: "%1 (%2)".arg(text).arg(Utils.translatedSectionName(sectionType) || model.sectionName)

            chatType: model.chatType ?? Constants.chatType.unknown
            onlineStatus: model.onlineStatus ?? Constants.onlineStatus.unknown

            pinned: true
            onItemPinRequested: function(key, pin) {
                root.itemPinRequested(key, pin)
            }
            onDappDisconnectRequested: (dappUrl) => root.dappDisconnectRequested(dappUrl)
            onClicked: {
                root.itemActivated(model.key, sectionType, model.id)
            }
        }
    }
}
