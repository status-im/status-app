import StatusQ.Core.Utils

import utils

import QtModelsToolkit

/**
  * Wrapper over generic ModelEntry to expose entries from model of contacts.
  */
QObject {
    id: root

    required property string publicKey
    required property var contactsModel
    readonly property alias available: itemData.available

    signal populateContactDetailsRequested()

    onPublicKeyChanged: {
        if (root.publicKey && contactsModel && !contactsModel.hasUser(root.publicKey)) {
            // Fetch contact details
            root.populateContactDetailsRequested()
        }
    }

    readonly property ContactDetails contactDetails: ContactDetails {
        function fromEntry(key, defaultValue) {
            const currentItem = itemData.item
            if (!currentItem)
                return defaultValue

            const value = currentItem[key]
            return value === null || value === undefined ? defaultValue : value
        }

        publicKey: root.publicKey
        compressedPubKey: fromEntry("compressedPubKey", "")
        displayName: fromEntry("displayName", "")
        ensName: fromEntry("ensName", "")
        ensVerified: fromEntry("isEnsVerified", false)
        localNickname: fromEntry("localNickname", "")
        alias: fromEntry("alias", "")
        usesDefaultName: fromEntry("usesDefaultName", false)
        icon: fromEntry("icon", "")
        colorId: fromEntry("colorId", 0)
        onlineStatus: fromEntry("onlineStatus", Constants.onlineStatus.inactive)
        isContact: fromEntry("isContact", false)
        isCurrentUser: fromEntry("isCurrentUser", false)
        isVerified: fromEntry("isVerified", false)
        isUntrustworthy: fromEntry("isUntrustworthy", false)
        isBlocked: fromEntry("isBlocked", false)
        contactRequestState: fromEntry("contactRequest", Constants.ContactRequestState.None)
        preferredDisplayName: fromEntry("preferredDisplayName", "")
        lastUpdated: fromEntry("lastUpdated", 0)
        lastUpdatedLocally: fromEntry("lastUpdatedLocally", 0)
        thumbnailImage: fromEntry("thumbnailImage", "")
        largeImage: fromEntry("largeImage", "")
        isContactRequestReceived: fromEntry("isContactRequestReceived", false)
        isContactRequestSent: fromEntry("isContactRequestSent", false)
        removed: fromEntry("isRemoved", false)
        trustStatus: fromEntry("trustStatus", Constants.trustStatus.unknown)
        bio: fromEntry("bio", "")

        // Backwards compatibility properties - Don't use in new code
        // TODO: #14965 - Try to remove these properties
        name: ensName
    }

    ModelEntry {
        id: itemData
        sourceModel: root.contactsModel
        key: "pubKey"
        value: root.publicKey
        cacheOnRemoval: true
    }
}
