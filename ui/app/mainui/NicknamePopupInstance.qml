import AppLayouts.stores as AppLayoutStores

import shared.popups

NicknamePopup {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore

    onEditDone: {
        if (nickname !== newNickname) {
            root.contactsStore.changeContactNickname(publicKey, newNickname, optionalDisplayName, !!nickname)
        }
        close()
    }
    onRemoveNicknameRequested: {
        root.contactsStore.changeContactNickname(publicKey, "", optionalDisplayName, true)
        close()
    }
}
