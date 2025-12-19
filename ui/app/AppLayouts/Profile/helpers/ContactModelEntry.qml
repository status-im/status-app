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

    signal populateContactDetailsRequested()

    onPublicKeyChanged: {
        if (root.publicKey && contactsModel && !contactsModel.hasUser(root.publicKey)) {
            // Fetch contact details
            root.populateContactDetailsRequested()
        }
    }

    readonly property ContactDetails contactDetails: ContactDetails {
        readonly property var entry: itemData.item

        publicKey: root.publicKey
        compressedPubKey:  entry.compressedPubKey ?? ""
        displayName: entry.displayName ?? ""
        ensName: entry.ensName ?? ""
        ensVerified: entry.isEnsVerified ?? false
        localNickname: entry.localNickname ?? ""
        alias: entry.alias ?? ""
        usesDefaultName: entry.usesDefaultName ?? false
        icon: entry.icon ?? ""
        colorId: entry.colorId ?? 0
        onlineStatus: entry.onlineStatus ?? Constants.onlineStatus.inactive
        isContact: entry.isContact ?? false
        isCurrentUser: entry.isCurrentUser ?? false
        isVerified: entry.isVerified ?? false
        isUntrustworthy: entry.isUntrustworthy ?? false
        isBlocked: entry.isBlocked ?? false
        contactRequestState: entry.contactRequest ?? Constants.ContactRequestState.None
        preferredDisplayName: entry.preferredDisplayName ?? ""
        lastUpdated: entry.lastUpdated ?? 0
        lastUpdatedLocally: entry.lastUpdatedLocally ?? 0
        thumbnailImage: entry.thumbnailImage ?? ""
        largeImage: entry.largeImage ?? ""
        isContactRequestReceived: entry.isContactRequestReceived ?? false
        isContactRequestSent: entry.isContactRequestSent ?? false
        removed: entry.isRemoved ?? false
        trustStatus: entry.trustStatus ?? Constants.trustStatus.unknown
        bio: entry.bio ?? ""

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
