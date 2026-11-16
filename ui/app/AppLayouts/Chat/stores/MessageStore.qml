import QtQuick

import StatusQ.Core.Theme

import utils

QtObject {
    id: root

    property var messageModule
    property var messagesModel
    property var chatSectionModule
    readonly property var inlineCommunitiesModel: typeof communitiesModule !== "undefined" ? communitiesModule.model : null
    property var sharedUrlParser: typeof sharedUrlsModule !== "undefined" ? sharedUrlsModule : null

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
    readonly property string threadId: messageModule ? messageModule.threadId : ""
    readonly property string threadName: messageModule ? messageModule.threadName : ""
    readonly property string threadParentChatName: messageModule ? messageModule.threadParentChatName : ""
    readonly property bool canEditThread: messageModule ? messageModule.canEditThread : false
    readonly property bool threadEditPending: messageModule ? messageModule.threadEditPending : false

    readonly property bool threadMuted: messageModule ? messageModule.threadMuted : false
    readonly property real threadMuteTill: messageModule ? messageModule.threadMuteTill : 0

    function setThreadMuted(interval: int) {
        if (root.messageModule)
            root.messageModule.setThreadMuted(interval)
    }

    function setThreadMutedById(threadId: string, interval: int) {
        if (root.messageModule)
            root.messageModule.setThreadMutedById(threadId, interval)
    }

    readonly property bool threadDeleted: messageModule?.threadDeleted ?? false
    readonly property bool threadFollowed: messageModule?.threadFollowed ?? false
    readonly property bool threadDeletePending: (root.messageModule?.threadDeletePending ?? false) ||
                                                root.threadDeleteRequestedById
    property bool threadDeleteRequestedById: false
    property var pendingThreadDeleteModule: null

    function canManageThreadById(threadId: string): bool {
        return root.messageModule?.canManageThreadById(threadId) ?? false
    }

    function threadDeleteErrorMessage(error: string): string {
        if (error === "thread-delete-permission-denied")
            return qsTr("Only the thread creator or an admin can delete this thread")
        return error
    }

    function setThreadFollowedById(threadId: string, followed: bool) {
        if (!root.messageModule) {
            console.error("setThreadFollowedById: message module is not set")
            return
        }
        root.messageModule.setThreadFollowedById(threadId, followed)
    }

    function setThreadFollowed(followed: bool) {
        root.setThreadFollowedById(root.threadId, followed)
    }

    function deleteThreadById(threadId: string) {
        if (!root.messageModule) {
            console.error("deleteThreadById: message module is not set")
            return
        }
        if (root.threadDeleteRequestedById || root.threadDeletePending || root.threadEditPending)
            return
        root.pendingThreadDeleteModule = root.messageModule
        root.threadDeleteRequestedById = true
        root.pendingThreadDeleteModule.deleteThreadById(threadId)
    }

    readonly property Connections threadDeletionConnections: Connections {
        target: root.pendingThreadDeleteModule
        function onThreadDeleteFinished(error: string) {
            const requestedHere = root.threadDeleteRequestedById
            root.threadDeleteRequestedById = false
            root.pendingThreadDeleteModule = null
            if (error && requestedHere && !root.threadId)
                Global.displayToastMessage(qsTr("Couldn't delete thread"), root.threadDeleteErrorMessage(error), "warning", false,
                                           Constants.ephemeralNotificationType.danger, "")
        }
    }

    function deleteThread() {
        if (root.messageModule)
            root.messageModule.deleteThread()
    }

    function editThread(name: string) {
        if (!root.messageModule) {
            console.error("editThread: message module is not set")
            return
        }
        root.messageModule.editThread(name)
    }

    onMessageModuleChanged: {
        root.inlineParsedLinks?.clear()
        ++root.inlineLinkRevision
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
        if (localAccountSettings.showDeleteMessageWarning)
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

    function createMessageLink(chatId, messageId) {
        if (!chatId || !messageId || !sharedUrlsModule) {
            return ""
        }

        return sharedUrlsModule.createMessageUrl(chatId, messageId)
    }

    function createThreadLink(chatId, threadId) {
        if (!chatId || !threadId || typeof sharedUrlsModule === "undefined" || !sharedUrlsModule)
            return ""
        return sharedUrlsModule.createThreadUrl(chatId, threadId)
    }

    readonly property QtObject profileUrlResolver: typeof sharedUrlsModule === "undefined" ? null : sharedUrlsModule

    property var inlineParsedLinks: new Map()
    onSharedUrlParserChanged: root.inlineParsedLinks?.clear()
    property int inlineLinkRevision: 0
    signal inlineLinkDataChanged(var changes)
    property var pendingInlineChanges: ({chats: {}, communities: {}})
    readonly property Connections inlineLinkConnections: Connections {
        target: root.messageModule ?? null
        function onInlineLinkDataChanged(payload) {
            const changes = JSON.parse(payload)
            for (const id of changes.chats) if (id) root.pendingInlineChanges.chats[id] = true
            for (const id of changes.communities) if (id) root.pendingInlineChanges.communities[id] = true
            Qt.callLater(root.flushInlineChanges)
        }
    }
    function flushInlineChanges() {
        const changes = root.pendingInlineChanges
        root.pendingInlineChanges = {chats: {}, communities: {}}
        root.inlineLinkDataChanged(changes)
    }

    function parseInlineLink(url) {
        if (root.inlineParsedLinks.has(url))
            return root.inlineParsedLinks.get(url)
        try {
            const canonical = Utils.canonicalStatusUrl(url)
            const prefix = Constants.externalStatusLinkWithHttps + "/"
            if (!canonical.startsWith(prefix))
                return null
            const path = canonical.slice(prefix.length)
            let data
            if (/^(cc|g|p)\//.test(path) && /^[^#]*[?&]thread-id=/.test(canonical)) {
                data = JSON.parse(root.sharedUrlParser.parseThreadUrl(canonical))
                if (!data.chatId || !data.threadId) return null
                data.kind = "thread"
                if (data.communityId) {
                    const parent = JSON.parse(root.sharedUrlParser.parseSharedUrl(canonical.replace(/\?[^#]*/, "")))
                    data.communityName = parent.community?.displayName || ""
                    data.chatName = parent.channel?.displayName || ""
                }
            } else if (path.startsWith("m/")) {
                data = JSON.parse(root.sharedUrlParser.parseMessageUrl(canonical))
                if (!data.chatId || !data.messageId) return null
                data.kind = "message"
            } else if (/^(c[\/#]|cc\/)/.test(path)) {
                const shared = JSON.parse(root.sharedUrlParser.parseSharedUrl(canonical))
                if (!shared.community?.communityId) return null
                data = {kind: shared.channel?.uuid ? "channel" : "community",
                    communityId: shared.community.communityId, communityName: shared.community.displayName,
                    chatId: shared.channel?.uuid ? shared.community.communityId + shared.channel.uuid : "",
                    chatName: shared.channel?.displayName || ""}
            } else {
                return null
            }
            const target = Object.freeze(Object.assign({url}, data))
            if (root.inlineParsedLinks.size >= 256)
                root.inlineParsedLinks.delete(root.inlineParsedLinks.keys().next().value)
            root.inlineParsedLinks.set(url, target)
            return target
        } catch (error) {
            return null
        }
    }

    function chatModelForInlineLink(communityId) {
        if (typeof mainModule === "undefined")
            return null
        if (!communityId)
            return mainModule.getChatSectionModule().model
        mainModule.prepareCommunitySectionModuleForCommunityId(communityId)
        return mainModule.getCommunitySectionModule()?.model ?? null
    }

    function resolveInlineLink(target) {
        if (!target)
            return null
        const data = Object.assign({}, target)
        if (target.chatId && root.messageModule) {
            Object.assign(data, JSON.parse(root.messageModule.getInlineThreadDetails(target.chatId,
                                                                                   target.threadId || "", target.messageId || "")))
        }
        return data
    }

    function createThread(parentMessageId) {
        if (!messageModule)
            return
        messageModule.createThread(parentMessageId)
    }
}
