import shared.popups

SendContactRequestModal {
    id: root

    onAccepted: root.contactsStore.sendContactRequest(publicKey, message)
}
