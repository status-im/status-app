import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import SortFilterProxyModel
import AppLayouts.Chat.controls
import AppLayouts.Chat.panels
import AppLayouts.Chat.stores
import Models
import utils

SplitView {
    id: root

    property string lastAction: ""

    UsersModel {
        id: users
        function hasUser(publicKey) { return data.some(user => user.pubKey === publicKey) }
    }
    ListModel { id: emptyModel }
    QtObject {
        id: mockChatContent
        readonly property QtObject chatDetails: QtObject {
            readonly property bool canPost: true
            readonly property bool canView: true
            readonly property bool canPostReactions: true
        }
    }
    RootStore {
        id: mockRootStore
        property var contactsModel: users
        property string name: "You"
        function myPublicKey() { return "" }
        function generateAlias(publicKey) { return publicKey }
        function requestContactInfo(publicKey) {}
        function populateContactDetailsRequested(publicKey) {}
        function currentChatContentModule() { return mockChatContent }
    }
    MessageStore {
        id: mockMessageStore
        function unpinMessage(messageId) {
            for (let i = 0; i < pins.count; ++i) {
                if (pins.get(i).id === messageId) {
                    pins.remove(i)
                    break
                }
            }
            root.lastAction = "unpinMessageRequested: " + messageId
        }
    }
    ListModel {
        id: pins
        Component.onCompleted: reset()

        function reset() {
            clear()
            const texts = [
                "How long did the full pipeline take?",
                "About three hours. The builder writes code and the auditor verifies it. This longer message helps check wrapping and spacing in narrow panels.",
                "The updated designs are ready for review."
            ]
            for (let i = 0; i < texts.length; ++i) {
                const sender = users.data[i]
                append({
                    id: "pin-" + i,
                    senderId: sender.pubKey, senderDisplayName: sender.preferredDisplayName,
                    senderOptionalName: "", senderEnsVerified: false, senderIsAdded: true,
                    senderIcon: sender.icon, senderTrustStatus: Constants.trustStatus.unknown,
                    amISender: false, messageText: texts[i], unparsedText: texts[i],
                    timestamp: Date.now() - i * 60000, outgoingStatus: "",
                    contentType: Constants.messageContentType.messageType,
                    pinned: true, pinnedBy: users.data[(i + 1) % texts.length].pubKey,
                    responseToMessageWithId: "", messageImage: "", reactions: emptyModel,
                    sticker: "", stickerPack: -1, linkPreviewModel: emptyModel, links: "",
                    transactionParameters: "", quotedMessageParsedText: "", quotedMessageText: "",
                    quotedMessageFrom: "", quotedMessageContentType: Constants.messageContentType.messageType,
                    quotedMessageDeleted: false, quotedMessageAuthorName: "",
                    quotedMessageAuthorDisplayName: "", quotedMessageAuthorThumbnailImage: "",
                    quotedMessageAuthorEnsVerified: false, quotedMessageAuthorIsContact: false,
                    bridgeName: ""
                })
            }
        }
    }
    ListModel {
        id: participants
        ListElement { name: "You"; image: ""; colorId: 0 }
        ListElement { name: "Elena"; image: ""; colorId: 1 }
        ListElement { name: "Marcus"; image: ""; colorId: 2 }
    }
    ListModel {
        id: threads
        Component.onCompleted: {
            for (let i = 0; i < 5; ++i) {
                append({
                    key: "thread-" + i,
                    originalMessageId: "parent-" + i,
                    title: ["Threads MVP", "Design tokens migration", "Q3 roadmap", "Token cost breakdown", "Old release notes"][i],
                    messagesCount: 4 + i,
                    notificationCount: i < 2 ? 2 - i : 0,
                    participantsCount: 3,
                    participantsModel: participants,
                    lastMessageSenderName: "Alice",
                    lastMessageSenderImage: "",
                    lastMessageSenderColorId: 0,
                    lastMessageText: "Sharing the summary back to the channel too.",
                    lastMessageTimestamp: Date.now() - i * 3600000
                })
            }
        }
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.fill: info
            color: Theme.palette.baseColor4
            border.color: Theme.palette.separator
        }

        ChatInfoPanel {
            id: info
            objectName: "chatInfoPanelPreview"
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, panelWidth.value)
            membersAvailable: !directMessage.checked
            threadsEnabled: threadsEnabled.checked
            threadsModel: threads
            threadsLoading: loading.checked
            threadsError: failed.checked
            onTabRequested: tab => requestedTab = tab
            onLoadThreadsRequested: root.lastAction = "loadThreadsRequested"
            onOpenThreadRequested: threadId => root.lastAction = "openThreadRequested: " + threadId
            membersContent: Component {
                UserListPanel {
                    headerVisible: false
                    usersModel: UsersModel {}
                    searchText: info.searchText
                }
            }
            pinsContent: Component {
                Item {
                    PinnedMessagesList {
                        id: pinsList
                        objectName: "chatInfoPinsPreview"
                        anchors.fill: parent
                        spacing: Theme.halfPadding / 2
                        store: mockRootStore
                        messageStore: mockMessageStore
                        chatId: "storybook-chat"
                        joined: true
                        model: SortFilterProxyModel {
                            sourceModel: pins
                            filters: SQUtils.SearchFilter {
                                roleName: "unparsedText"
                                searchPhrase: info.searchText
                            }
                        }
                        onUnpinMessageRequested: messageId => mockMessageStore.unpinMessage(messageId)
                        onJumpToMessageRequested: messageId => root.lastAction = "jumpToMessageRequested: " + messageId
                    }
                    StatusBaseText {
                        anchors.centerIn: parent
                        visible: pinsList.count === 0
                        text: info.searchText ? qsTr("No pinned messages found") : qsTr("Pinned messages will appear here.")
                        color: Theme.palette.secondaryText
                    }
                }
            }
        }
    }

    Pane {
        SplitView.preferredWidth: 260
        ColumnLayout {
            anchors.fill: parent
            CheckBox { id: directMessage; text: "Direct message" }
            CheckBox { id: threadsEnabled; text: "Threads enabled"; checked: true }
            CheckBox { id: loading; text: "Loading threads" }
            CheckBox { id: failed; text: "Thread loading failed" }
            Button { text: "Reset pinned messages"; onClicked: pins.reset() }
            Label { text: "Panel width" }
            Slider { id: panelWidth; from: 260; to: 550; value: 400 }
            Label { Layout.fillWidth: true; text: root.lastAction; wrapMode: Text.Wrap }
            Item { Layout.fillHeight: true }

        }
    }
}
