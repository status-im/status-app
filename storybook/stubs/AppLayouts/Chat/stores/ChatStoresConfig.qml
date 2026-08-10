pragma Singleton
import QtQuick

// Storybook-only configuration hook: pages populate these before creating
// components that internally instantiate the stub ChatStores.RootStore
// (e.g. the section loaders), so the stub can hand out page-controlled mocks.
QtObject {
    // Mock of the nim chatCommunitySectionModule (chat list model, activeItem…)
    property var chatSectionModule: null
    // Mock of the currently active chat content module (chatDetails, messagesModule…)
    property var currentChatContentModule: null
    // Members model for the active chat (production UsersStore selects between
    // the section members and the channel members — mocks do it here)
    property var usersModel: null
    // Section details for the active section (id, name, image, joined, amIBanned…)
    property var sectionDetails: null
    // Wallet models used to resolve token-permission holdings to symbols/icons
    property var assetsModel: null
    property var collectiblesModel: null
}
