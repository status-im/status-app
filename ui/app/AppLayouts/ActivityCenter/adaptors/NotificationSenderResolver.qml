import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Profile.helpers
import AppLayouts.ActivityCenter.helpers

import utils

QtObject {
    id: root

    /*!
        Public key of the contact associated with the notification.

        For outgoing messages, this refers to the chat identifier.
        For incoming messages, this refers to the author.
    */
    required property string contactId

    /*!
        Model containing all known contacts.

        This model is used to resolve contact-specific data (display name,
        avatar, trust status, ENS verification) for notifications that
        reference a user.

        Expected to be a QAbstractItemModel (or compatible).
    */
    required property var contactsModel

    /*!
        It provides the details of a specific notifications sender given it's contactId.
    */
    readonly property StatusMessageSenderDetails sender: StatusMessageSenderDetails {
        compressedPubKey: d.contactDetails ? d.contactDetails.compressedPubKey : ""
        displayName: d.contactDetails ? ProfileUtils.displayName(d.contactDetails.localNickname,
                                                                 d.contactDetails.name,
                                                                 d.contactDetails.displayName,
                                                                 d.contactDetails.alias) : ""
        secondaryName: d.contactDetails && d.contactDetails.localNickname ?
                           ProfileUtils.displayName("",
                                                    d.contactDetails.name,
                                                    d.contactDetails.displayName,
                                                    d.contactDetails.alias) : ""
        trustIndicator: d.contactDetails ? d.contactDetails.trustStatus : Constants.trustStatus.unknown
        isEnsVerified: !!d.contactDetails && d.contactDetails.ensVerified
        isContact: !!d.contactDetails && d.contactDetails.isContact
        isBlocked: !!d.contactDetails && d.contactDetails.isBlocked
        profileImage {
            name: d.contactDetails ? d.contactDetails.thumbnailImage : ""
            pubkey: root.contactId
            color: Theme.palette.userCustomizationColors[Utils.colorIdForPubkey(root.contactId)]
        }
    }

    /*!
        True when the notification message was sent by the current user.
    */
    required property bool isOutgoingMessage

    /*!
        Emitted when additional details for a specific contact are required.

        Allows the adaptor to request contact data that is not yet available
        in the contacts model (e.g. profile details, ENS data).

        The request is identified by the contact's public key.
    */
    signal populateContactDetailsRequested(string contactId)

    /*!
        Internal helper object.

        Holds derived and private state used by the adaptor, including
        message direction, resolved contact identity and contact details.

        This object is intentionally private and not part of the public API.
    */
    readonly property QtObject d: QtObject {

        /*!
            Resolved contact details for the associated contact, if available.
        */
        readonly property var contactDetails: d.contactModelEntry ? d.contactModelEntry.contactDetails : null

        /*!
            Model entry used to resolve contact details for the associated contact.
        */
        readonly property ContactModelEntry contactModelEntry: ContactModelEntry {
            publicKey: root.contactId ?? ""
            contactsModel: root.contactsModel

            onPopulateContactDetailsRequested: root.populateContactDetailsRequested(root.contactId)
        }
    }
}
