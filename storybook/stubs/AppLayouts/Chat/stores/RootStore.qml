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

    // Surface read by the chat views
    property bool isDebugEnabled: false
    property bool joined: true
    property bool isUserAllowedToSendMessage: true
    property string chatInputPlaceHolderText: "Message"
    property int activeChatType: 1
    property var assetsModel: null
    property var collectiblesModel: null
    property var communityItemsModel: null

    readonly property var sectionDetails: QtObject {
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
}
