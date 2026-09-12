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

import "../helpers"
import "../controls"
import "../popups"
import "../panels"

/*
 Per-chat shell: banner, loading skeleton and the slot the SHARED
 ChatMessagesView is reparented into while this chat is active (see
 ChatColumnView) — one live messages view per section instead of one per
 visited chat.
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

    // reparenting target for the section's shared messages view
    readonly property alias messagesSlot: messagesSlot

    readonly property ChatStores.MessageStore messageStore: ChatStores.MessageStore {
        messageModule: chatContentModule ? chatContentModule.messagesModule : null
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

        // true while the shared messages view is parented here (the
        // skeleton below is also a child — don't count it)
        property bool occupied: false
        onChildrenChanged: {
            for (let i = 0; i < children.length; ++i) {
                if (children[i] !== chatMessagesSkeleton) {
                    occupied = true
                    return
                }
            }
            occupied = false
        }

        Loader {
            id: chatMessagesSkeleton
            anchors.fill: parent
            z: 1
            // covers the backend fetch; the shared view's own staged fill
            // covers the rows region until its atomic reveal. Built once and
            // kept: the skeleton is expensive (~200ms of tiles and masks) and
            // every chat switch needs it again — visibility does the toggling
            active: false
            visible: root.messageStore.loading || !messagesSlot.occupied
            onVisibleChanged: if (visible) active = true
            Component.onCompleted: if (visible) active = true
            sourceComponent: MessageRowsSkeleton {
                objectName: "chatMessagesSkeleton"
            }
        }
    }
}
