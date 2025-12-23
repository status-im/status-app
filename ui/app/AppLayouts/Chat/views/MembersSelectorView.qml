import QtQuick
import QtQuick.Controls
import QtQml.Models

import StatusQ.Controls
import StatusQ.Components

import AppLayouts.Profile.helpers

import "private"

import shared.stores
import utils

MembersSelectorBase {
    id: root

    property UtilsStore utilsStore
    property var allContactsModel

    signal resolveENS(string address)
    signal populateContactDetails(string pubkey)

    limitReached: model.count >= membersLimit - 1 // -1 because creator is not on the list of members when creating chat

    function cleanup() {
        root.edit.clear()
        d.selectedMembers.clear()
    }

    function ensResolved(resolvedPubKey: string, resolvedAddress: string, uuid: string) {
        if (resolvedPubKey === "") {
            root.suggestionsDialog.forceHide = false
            return
        }
        d.processContact(resolvedPubKey)
    }

    onEntryAccepted: (suggestionsDelegate) => {
        if (suggestionsDelegate) {
            if (root.limitReached)
                return
            if (d.addMember(suggestionsDelegate._pubKey, suggestionsDelegate.userName, suggestionsDelegate.nickName))
                root.edit.clear()
        }
    }

    onEntryRemoved: (delegate) => {
        if (delegate) {
            d.removeMember(delegate._pubKey)
        }
    }

    edit.onTextChanged: {
        // When edited, give a small delay in case next character is printed soon
        contactLookupDelayTimer.start()
        root.pastedChatKey = ""
    }

    onTextPasted: (text) => {
        // When pasted, process text immediately
        contactLookupDelayTimer.stop() // when pasting, textChanged is still emitted first
        d.lookupContact(text)
    }

    model: d.selectedMembers

    delegate: StatusTagItem {
        readonly property string _pubKey: model.pubKey

        width: Math.min(implicitWidth, root.membersFlickContentWidth)
        text: model.localNickname || model.displayName
        elideMode: Text.ElideMiddle

        onClosed: root.entryRemoved(this)
    }

    QtObject {
        id: d

        property ListModel selectedMembers: ListModel {}

        property var sharedContactModelEntryLoader: Loader {
            property string publicKey: ""

            active: false

            sourceComponent: ContactModelEntry {
                publicKey: d.sharedContactModelEntryLoader.publicKey
                contactsModel: root.allContactsModel
                onPopulateContactDetailsRequested: {
                    root.populateContactDetails(d.sharedContactModelEntryLoader.publicKey)
                }
            }
        }

        function getContactModelEntry(pubkey) {
            d.sharedContactModelEntryLoader.active = false
            d.sharedContactModelEntryLoader.publicKey = pubkey
            d.sharedContactModelEntryLoader.active = true
            return d.sharedContactModelEntryLoader.item
        }

        function lookupContact(value) {
            const urlContactData = Utils.parseContactUrl(value)
            if (urlContactData) {
                // Ignore all the data from the link, because it might be malformed.
                // Except for the publicKey.
                processContact(urlContactData.publicKey)
                return
            }

            value = Utils.dropUserLinkPrefix(value.trim())

            if (root.utilsStore.isChatKey(value)) {
                processContact(value)
                return
            }

            if (Utils.isValidEns(value)) {
                root.resolveENS(value)
                return
            }

            root.suggestionsDialog.forceHide = false
        }

        function processContact(publicKey) {
            let fullPubkey = publicKey
            if (root.utilsStore.isCompressedPubKey(fullPubkey)) {
                fullPubkey = root.utilsStore.getDecompressedPk(publicKey)
            }
            const contactEntry = d.getContactModelEntry(fullPubkey)
            const contactDetails = contactEntry.contactDetails

            if (contactDetails.publicKey === "") {
                // not a valid key given
                root.suggestionsDialog.forceHide = false
                return
            }

            if (contactDetails.isContact) {
                // Is a contact, we add their name to the list
                root.pastedChatKey = contactDetails.publicKey
                root.suggestionsDialog.forceHide = false
                return
            }

            const hasPendingContactRequest = contactDetails.contactRequestState === Constants.ContactRequestState.Sent

            if ((root.model.count === 0 && hasPendingContactRequest) ||
                    contactDetails.isCurrentUser || contactDetails.isBlocked) {
                // List is empty and we have a contact request
                // OR it's our own chat key or a banned user
                // Then open the contact's profile popup
                Global.openProfilePopup(contactDetails.publicKey, null,
                                        popup => popup.closed.connect(root.rejected))
                return
            }

            if (root.model.count === 0 && !hasPendingContactRequest) {
                // List is empty and not a contact yet. Open the contact request popup
                Global.openContactRequestPopup(contactDetails.publicKey,
                                               popup => popup.closed.connect(root.rejected))
                return
            }

            root.suggestionsDialog.forceHide = false
        }

        function addMember(pubKey, displayName, localNickname) {
            for (let i = 0; i < d.selectedMembers.count; ++i) {
                if (d.selectedMembers.get(i).pubKey === pubKey)
                    return false
            }

            d.selectedMembers.append({pubKey, displayName, localNickname})
            return true
        }

        function removeMember(pubKey) {
            for(var i = 0; i < d.selectedMembers.count; i++) {
                const obj = d.selectedMembers.get(i)
                if(obj.pubKey === pubKey) {
                    d.selectedMembers.remove(i)
                    return
                }
            }
        }
    }

    Timer {
        id: contactLookupDelayTimer
        repeat: false
        interval: 500
        onTriggered: {
            d.lookupContact(edit.text)
        }
    }
}
