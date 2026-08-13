import QtQuick

// Functional stub mirroring the real MessageStore wrapper, minus the nim
// context-property dependencies. Works against a page-provided mock
// messageModule exposing at least { model, loading, getChatId() }.
QtObject {
    id: root

    property var messageModule
    property var messagesModel
    property var chatSectionModule

    readonly property bool loadingHistoryMessagesInProgress: chatSectionModule ?
                                                                 !!chatSectionModule.loadingHistoryMessagesInProgress : false
    readonly property int newMessagesCount: messagesModel && messagesModel.newMessagesCount !== undefined ?
                                                messagesModel.newMessagesCount : 0
    readonly property bool messageSearchOngoing: false
    readonly property bool loading: messageModule ? !!messageModule.loading : false
    readonly property bool amIChatAdmin: false
    readonly property bool isPinMessageAllowedForMembers: false
    readonly property string chatId: messageModule ? messageModule.getChatId() : ""
    readonly property int chatType: 0
    readonly property string chatColor: "#4360DF"
    readonly property string chatIcon: ""
    readonly property bool keepUnread: false
    readonly property bool isChatActive: true

    onMessageModuleChanged: {
        if (messageModule)
            messagesModel = messageModule.model
    }

    function loadMoreMessages() {
        if (messageModule && messageModule.loadMoreMessages)
            messageModule.loadMoreMessages()
    }
    function setKeepUnread(flag) {}
    function getMessageByIdAsJson(id) { return undefined }
    function getMessageByIndexAsJson(index) { return false }
    function getSectionId() { return "" }
    function getChatId() { return chatId }
    function getNumberOfPinnedMessages() { return 0 }
    function pinMessage(messageId) {}
    function unpinMessage(messageId) {}
    function toggleReaction(messageId, hexcode) {}
    function deleteMessage(messageId) {}
    function markMessageAsUnread(messageId) {}
    function warnAndDeleteMessage(messageId) {}
    function setEditModeOn(messageId) {}
    function setEditModeOnLastMessage(pubkey) {}
    function setEditModeOff(messageId) {}
    function editMessage(messageId, updatedMsg) {}
    function fillGaps(messageId) {}
    function leaveChat() {}
    function addNewMessagesMarker() {}
    function firstUnseenMentionMessageId() { return "" }
    function jumpToMessage(id) {}
    function createMessageLink(chatId, messageId) { return "" }
    function resendMessage(messageId) {}
}
