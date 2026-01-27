import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.HomePage.delegates

import utils

Control {
    id: root

    /**
      Expected model structure:

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

      Writable layer:
        pinned             [bool]   - whether the item is pinned in the UI
        timestamp          [int]    - timestamp of the last user interaction with the item
    **/
    property alias model: gridView.model

    property int delegateWidth: 160
    property int delegateHeight: 160

    signal itemActivated(string key, int sectionType, string itemId)
    signal itemPinRequested(string key, bool pin)
    signal dappDisconnectRequested(string dappUrl)

    padding: Theme.defaultHalfPadding

    contentItem: Item {
        StatusGridView {
            id: gridView

            readonly property int delegateCountPerRow: Math.trunc(parent.width / (root.delegateWidth + root.spacing))

            height: parent.height
            width: (delegateCountPerRow * cellWidth) + (delegateCountPerRow - 1)
            anchors.horizontalCenter: parent.horizontalCenter

            ScrollBar.vertical: StatusScrollBar {
                parent: gridView.parent
                anchors.top: gridView.top
                anchors.bottom: gridView.bottom
                anchors.left: parent.right
                anchors.leftMargin: root.rightPadding
            }

            cellWidth: root.delegateWidth + root.spacing
            cellHeight: root.delegateHeight + root.spacing

            delegate: Loader {
                required property int index
                required property var model

                objectName: "homeGridItemLoader_" + model.key

                sourceComponent: {
                    switch (model.sectionType) {
                    case Constants.appSection.profile:
                        return settingsDelegate
                    case Constants.appSection.community:
                        return communityDelegate
                    case Constants.appSection.wallet:
                        return walletDelegate
                    case Constants.appSection.chat:
                    case -1: // search
                        return chatDelegate
                    case Constants.appSection.dApp:
                        return dappDelegate
                    default:
                        console.warn("Unhandled HomePageGridItem delegate for sectionType:", model.sectionType)
                    }
                }

                Connections {
                    target: item ?? null
                    function onClicked() {
                        root.itemActivated(model.key, model.sectionType, item.itemId)
                    }
                    function onPinRequested() {
                        root.itemPinRequested(model.key, !model.pinned)
                    }
                }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: ThemeUtils.AnimationDuration.Fast }
            }
        }

        Component {
            id: communityDelegate

            HomePageGridCommunityItem {
                width: root.delegateWidth
                height: root.delegateHeight
                itemId: model.id
                title: model.name
                color: model.color
                icon.source: model.icon
                banner: model.banner ?? ""
                hasNotification: model.hasNotification
                notificationsCount: model.notificationsCount
                pinned: model.pinned

                membersCount: model.members ?? 0
                activeMembersCount: model.activeMembers ?? 0

                pending: model.pending ?? false
                banned: model.banned ?? false
            }
        }

        Component {
            id: settingsDelegate

            HomePageGridSettingsItem {
                width: root.delegateWidth
                height: root.delegateHeight
                itemId: model.id
                title: model.name
                icon.name: model.icon
                hasNotification: model.hasNotification
                notificationsCount: model.notificationsCount
                pinned: model.pinned
            }
        }

        Component {
            id: walletDelegate

            HomePageGridWalletItem {
                width: root.delegateWidth
                height: root.delegateHeight
                itemId: model.id
                title: model.name
                icon.name: model.icon
                icon.color: model.color
                hasNotification: model.hasNotification
                notificationsCount: model.notificationsCount
                pinned: model.pinned

                currencyBalance: model.currencyBalance ?? ""
                walletType: model.walletType ?? ""
            }
        }

        Component {
            id: chatDelegate

            HomePageGridChatItem {
                width: root.delegateWidth
                height: root.delegateHeight
                itemId: model.id
                title: chatType === Constants.chatType.communityChat ? "#" + model.name : model.name
                icon.name: model.icon
                icon.color: model.color
                hasNotification: model.hasNotification ?? false
                notificationsCount: model.notificationsCount ?? 0
                pinned: model.pinned
                sectionName: model.sectionName ?? ""
                lastMessageText: {
                    if (!!model.lastMessageText)
                        return model.lastMessageText
                    return ""
                }

                chatType: model.chatType ?? Constants.chatType.unknown
                onlineStatus: model.onlineStatus ?? Constants.onlineStatus.unknown
            }
        }

        Component {
            id: dappDelegate

            HomePageGridDAppItem {
                width: root.delegateWidth
                height: root.delegateHeight
                itemId: model.id
                title: model.name
                icon.name: model.icon
                icon.color: model.color
                pinned: model.pinned

                connectorBadge: model.connectorBadge ?? ""

                onDisconnectRequested: root.dappDisconnectRequested(itemId)
            }
        }
    }
}
