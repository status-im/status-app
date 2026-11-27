import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls

import utils
import shared
import shared.status

import AppLayouts.Chat.stores as ChatStores

import "../panels"

/*
  The per-chat shell: the blocked banner, the loading skeleton and the slot the
  section's shared ChatMessagesView is reparented into while this chat is the
  active one (see ChatColumnView) - one messages view per section instead of
  one per visited chat.
*/
ColumnLayout {
    id: root

    // Important: each chat/channel has its own ChatContentModule
    property var chatContentModule
    property var chatSectionModule

    property ChatStores.RootStore rootStore
    property string chatId
    property int chatType: Constants.chatType.unknown

    property bool isBlocked: false

    // Where the shared messages view goes while this chat is active.
    readonly property alias messagesSlot: messagesSlot
    property ChatMessagesView messagesView

    readonly property ChatStores.MessageStore messageStore: ChatStores.MessageStore {
        messageModule: root.chatContentModule ? root.chatContentModule.messagesModule : null
        chatSectionModule: root.rootStore.chatCommunitySectionModule
    }

    objectName: "chatContentViewColumn"
    spacing: 0

    Loader {
        objectName: "blockedBannerLoader"

        Layout.fillWidth: true
        active: root.isBlocked
        visible: active
        sourceComponent: StatusBanner {
            type: StatusBanner.Type.Danger
            statusText: qsTr("Blocked")
        }
    }

    Item {
        id: messagesSlot

        Layout.fillWidth: true
        Layout.fillHeight: true

        readonly property bool hasMessagesView: root.messagesView?.parent === messagesSlot
        readonly property bool viewShowsFill: hasMessagesView
            && root.messagesView.messageStore === root.messageStore
            && root.messagesView.fillPlaceholderVisible

        Loader {
            id: chatMessagesSkeleton

            anchors.fill: parent
            z: 1

            // Cover loading until this chat's messages view shows its own fill.
            active: (root.messageStore.loading || !messagesSlot.hasMessagesView)
                    && !messagesSlot.viewShowsFill
            visible: active
            sourceComponent: MessageRowsSkeleton {
                objectName: "chatMessagesSkeleton"
            }
        }
    }
}
