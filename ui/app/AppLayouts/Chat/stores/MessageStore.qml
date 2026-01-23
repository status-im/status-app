import QtQuick

import StatusQ.Core.Theme

import utils

QtObject {
    id: root

    property var messageModule
    property var messagesModel
    property var chatSectionModule

    readonly property bool loadingHistoryMessagesInProgress: root.chatSectionModule? root.chatSectionModule.loadingHistoryMessagesInProgress : false
    readonly property int newMessagesCount: messagesModel ? messagesModel.newMessagesCount : 0
    readonly property bool messageSearchOngoing: messageModule ? messageModule.messageSearchOngoing : false
    readonly property bool loading: messageModule ? messageModule.loading : false

    readonly property bool amIChatAdmin: messageModule ? messageModule.amIChatAdmin : false
    readonly property bool isPinMessageAllowedForMembers: messageModule ? messageModule.isPinMessageAllowedForMembers : false
    readonly property string chatId: messageModule ? messageModule.getChatId() : ""
    readonly property int chatType: messageModule ? messageModule.chatType : Constants.chatType.unknown
    readonly property string chatColor: messageModule ? messageModule.chatColor : Theme.palette.primaryColor1
    readonly property string chatIcon: messageModule ? messageModule.chatIcon : ""
    readonly property bool keepUnread: messageModule ? messageModule.keepUnread : false

    onMessageModuleChanged: {
        if(!messageModule)
            return
        root.messagesModel = messageModule.model
    }

    function loadMoreMessages () {
        if(!messageModule)
            return

        if(root.loading)
            return

        messageModule.loadMoreMessages()
    }

    function setKeepUnread(flag: bool) {
        if (!messageModule) {
            return
        }

        messageModule.updateKeepUnread(flag)
    }

    function getMessageByIdAsJson (id) {
        if (!messageModule) {
            console.warn("getMessageByIdAsJson: Failed to parse message, because messageModule is not set")
            return false
        }

        const jsonObj = messageModule.getMessageByIdAsJson(id)
        if (jsonObj === "") {
            console.warn("getMessageByIdAsJson: Failed to get message, returned json is empty")
            return undefined
        }

        const obj = JSON.parse(jsonObj)
        if (obj.error) {
            // This log is available only in debug mode, if it's annoying we can remove it
            console.debug("getMessageByIdAsJson: Failed to parse message for index: ", id, " error: ", obj.error)
            return false
        }

        return obj
    }

    function getMessageByIndexAsJson (index) {
        if(!messageModule)
            return false

        let jsonObj = messageModule.getMessageByIndexAsJson(index)
        if(jsonObj === "")
            return

        let obj = JSON.parse(jsonObj)
        if (obj.error) {
            // This log is available only in debug mode, if it's annoying we can remove it
            console.debug("error parsing message for index: ", index, " error: ", obj.error)
            return false
        }

        return obj
    }

    function getSectionId () {
        if(!messageModule)
            return ""

        return messageModule.getSectionId()
    }

    function getChatId () {
        if(!messageModule)
            return ""

        return messageModule.getChatId()
    }

    function getNumberOfPinnedMessages () {
        if(!messageModule)
            return 0

        return messageModule.getNumberOfPinnedMessages()
    }

    function pinMessage (messageId) {
        if(!messageModule)
            return

        return messageModule.pinMessage(messageId)
    }

    function unpinMessage (messageId) {
        if(!messageModule)
            return

        return messageModule.unpinMessage(messageId)
    }

    function toggleReaction(messageId, hexcode) {
        if(!messageModule)
            return

        return messageModule.toggleReaction(messageId, hexcode)
    }

    function deleteMessage(messageId) {
        if(!messageModule)
            return
        messageModule.deleteMessage(messageId)
    }

    function markMessageAsUnread(messageId) {
        if (!messageModule) {
            return
        }
        messageModule.markMessageAsUnread(messageId)
    }

    function warnAndDeleteMessage(messageId) {
        if (localAccountSensitiveSettings.showDeleteMessageWarning)
            Global.openDeleteMessagePopup(messageId, this)
        else
            deleteMessage(messageId)
    }

    function setEditModeOn(messageId) {
        if(!messageModule)
            return
        messageModule.setEditModeOn(messageId)
    }

    function setEditModeOnLastMessage(pubkey) {
        if(!messageModule)
            return
        messageModule.setEditModeOnAndScrollToLastMessage(pubkey)
    }

    function setEditModeOff(messageId) {
        if(!messageModule)
            return
        messageModule.setEditModeOff(messageId)
    }

    function editMessage(messageId, updatedMsg) {
        if(!messageModule)
            return
        messageModule.editMessage(messageId, updatedMsg)
    }

    function interpretMessage(msg) {
        if (msg.startsWith("/shrug")) {
            return msg.replace("/shrug", "") + " ¯\\\\\\_(ツ)\\_/¯"
        }
        if (msg.startsWith("/tableflip")) {
            return msg.replace("/tableflip", "") + " (╯°□°）╯︵ ┻━┻"
        }

        return msg
    }

    function fillGaps(messageId) {
        if(!messageModule)
            return
        return messageModule.fillGaps(messageId)
    }

    function leaveChat() {
        if(!messageModule)
            return
        messageModule.leaveChat()
    }

    function addNewMessagesMarker() {
         if(!messageModule)
            return
        messageModule.addNewMessagesMarker()
    }

    readonly property bool isChatActive: {
        if (root.getSectionId() !== mainModule.activeSection.id)
            return false

        if (!root.chatSectionModule)
            return false

        if (root.getChatId() !== root.chatSectionModule.activeItem.id)
            return false

        return true
    }

    readonly property bool isOnline: mainModule.isOnline

    function resendMessage(messageId) {
        if(!messageModule)
            return
        messageModule.resendMessage(messageId)
    }

    function jumpToMessage(messageId) {
        if(!messageModule)
            return
        messageModule.jumpToMessage(messageId)
    }

    function firstUnseenMentionMessageId() {
        if(!messageModule)
            return ""
        return messageModule.firstUnseenMentionMessageId()
    }
}
