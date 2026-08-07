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
}
