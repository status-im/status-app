import AppLayouts.stores as AppStores

import shared.status

StatusSearchListPopup {
    id: root

    required property AppStores.RootStore rootStore

    relativeX: root.directParent.width / 2 - root.width / 2
    relativeY: root.directParent.height / 2 - root.height / 2
    model: root.rootStore.chatSearchModel

    onSelected: function (sectionId, chatId) {
        root.rootStore.setActiveSectionChat(sectionId, chatId)
        root.close()
    }
}
