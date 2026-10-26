import QtQuick

import utils

QtObject {
    id: root

    // Wired from ChatStoresConfig so pages can inject mocks even when this
    // store is created internally by a component under test (section loaders)
    property var chatCommunitySectionModule: ChatStoresConfig.chatSectionModule
    property var contactsStore
    property bool isChatSectionModule
    property var communityId

    // Properties assigned by the section loaders
    property var currencyStore
    property var communityTokensStore
    property var networkConnectionStore
    property bool openCreateChat: false
    property bool loadingHistoryMessagesInProgress: false
    readonly property string openThreadId: chatCommunitySectionModule?.openThreadId ?? ""
    readonly property string openThreadName: chatCommunitySectionModule?.openThreadName ?? ""
    readonly property string openThreadParentChatId: chatCommunitySectionModule?.openThreadParentChatId ?? ""

    // Surface read by the chat views. Derived like the real store so the
    // injected content module's permissions (canPost, admin role) gate the
    // input area instead of being hardcoded no-ops.
    property bool isDebugEnabled: false
    property bool joined: true
    readonly property bool isUserAllowedToSendMessage: {
        if (activeChatType === Constants.chatType.communityChat)
            return !!(currentChatContentModule()?.chatDetails?.canPost ?? false)
        return true
    }
    readonly property string chatInputPlaceHolderText: qsTr("Type something")
    readonly property int activeChatType: chatCommunitySectionModule?.activeItem?.type ?? -1
    property var assetsModel: ChatStoresConfig.assetsModel
    property var collectiblesModel: ChatStoresConfig.collectiblesModel
    property var communityItemsModel: chatCommunitySectionModule ? chatCommunitySectionModule.model : null
    property var communitiesModuleInst: null

    readonly property var sectionDetails: ChatStoresConfig.sectionDetails ?? defaultSectionDetails

    readonly property var defaultSectionDetails: QtObject {
        property bool joined: true
        property bool amIBanned: false
    }

    // The local user's name and every known contact, as the mention names read them
    property string name
    property var contactsModel: null

    property UsersStore usersStore: UsersStore {}
    property StickersStore stickersStore: StickersStore {}

    function currentChatContentModule() {
        return ChatStoresConfig.currentChatContentModule
    }

    function amIChatAdmin() {
        return currentChatContentModule()?.amIChatAdmin() ?? false
    }

    function generateAlias(publicKey) {
        return ""
    }

    function requestContactInfo(publicKey) {}

    function cleanMessageText(text) {
        return text
    }

    function sendMessage() {
        return false
    }

    function sendSticker() {}
    function removeMemberFromGroupChat() {}

    // Community mutators proxied to the section module, like the real store
    function openThreadPanel(threadId, threadName, parentChatId) {
        chatCommunitySectionModule.openThreadPanel(threadId, threadName, parentChatId)
    }
    function closeThreadPanel() {
        chatCommunitySectionModule.closeThreadPanel()
    }
    function toggleCollapsedCommunityCategory(categoryId, collapsed) {
        chatCommunitySectionModule?.toggleCollapsedCommunityCategory(categoryId, collapsed)
    }
    function reorderCommunityChat(categoryId, chatId, to) {
        chatCommunitySectionModule?.reorderCommunityChat(categoryId, chatId, to)
    }
    function reorderCommunityCategories(categoryId, to) {
        chatCommunitySectionModule?.reorderCommunityCategories(categoryId, to)
    }
    function removeCommunityChat(chatId) {}
    function deleteCommunityCategory(categoryId) {}
    function prepareEditCategoryModel(categoryId) {}
    function leaveCommunity() {}

    function loadMembersForSectionId(sectionId) {}
    function loadAdminMembersForSectionId(sectionId) {}
    function releaseAdminMembersForSectionId(sectionId) {}
}
