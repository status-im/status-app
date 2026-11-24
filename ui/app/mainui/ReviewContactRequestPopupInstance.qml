import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

ReviewContactRequestPopup {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore

    onAccepted: {
        root.contactsStore.acceptContactRequest(publicKey, contactRequestId)
        Global.displaySuccessToastMessage(qsTranslate("Popups", "Contact request accepted"))
        close()
    }
    onRejected: {
        root.contactsStore.dismissContactRequest(publicKey, contactRequestId)
        Global.displaySuccessToastMessage(qsTranslate("Popups", "Contact request ignored"))
        close()
    }
}
