import QtQuick

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

    // Surface read by the chat views
    property bool isDebugEnabled: false
    property bool joined: true
    property bool isUserAllowedToSendMessage: true
    property string chatInputPlaceHolderText: "Message"
    property int activeChatType: 1
    property var assetsModel: ChatStoresConfig.assetsModel
    property var collectiblesModel: ChatStoresConfig.collectiblesModel
    property var communityItemsModel: chatCommunitySectionModule ? chatCommunitySectionModule.model : null
    property var communitiesModuleInst: null

    readonly property var sectionDetails: ChatStoresConfig.sectionDetails ?? defaultSectionDetails

    readonly property var defaultSectionDetails: QtObject {
        property bool joined: true
        property bool amIBanned: false
    }

    property UsersStore usersStore: UsersStore {}
    property StickersStore stickersStore: StickersStore {}

    function currentChatContentModule() {
        return ChatStoresConfig.currentChatContentModule
    }

    function amIChatAdmin() {
        return false
    }

    function cleanMessageText(text) {
        return text
    }

    function sendMessage() {
        return false
    }

    function sendSticker() {}
    function removeMemberFromGroupChat() {}

    // Community mutators proxied to the section module, like the real store
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
}
