import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Profile.helpers

import utils

/*!
    \qmltype NotificationAdaptorSender
    \inqmlmodule AppLayouts.ActivityCenter.adaptors

    Notification contact adaptor that maps contact model data to
    UI-facing properties and avatar configuration.

    Responsibilities:
    - Resolve contact-related information from the contacts model
    - Normalize sender identity, avatar, trust status and message metadata
    - Expose a stable API for higher-level adaptors and UI components

    This adaptor is non-visual and intentionally contains presentation
    logic that should not be duplicated in UI delegates.
*/
NotificationAdaptorBase {
    id: root

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
    readonly property alias sender: d.senderResolver.sender

    /*!
        Public key of the contact associated with the notification.

        For outgoing messages, this refers to the chat identifier.
        For incoming messages, this refers to the author.
    */
    readonly property alias contactId: d.senderResolver.contactId

    /*!
        True when the notification message was sent by the current user.
    */
    readonly property alias isOutgoingMessage: d.senderResolver.isOutgoingMessage

    /*!
        Emitted when additional details for a specific contact are required.

        Allows the adaptor to request contact data that is not yet available
        in the contacts model (e.g. profile details, ENS data).

        The request is identified by the contact's public key.
    */
    signal populateContactDetailsRequested(string contactId)

    QtObject {
        id: d

        /*!
            Resolves sender details for the current notification using the contacts model.
        */
        readonly property NotificationSenderResolver senderResolver: NotificationSenderResolver {
            isOutgoingMessage: root.notification?.message?.amISender ?? false
            contactId: root.notification ? (isOutgoingMessage ? root.notification.chatId : root.notification.author) : ""
            contactsModel: root.contactsModel

            onPopulateContactDetailsRequested: (contactId) => root.populateContactDetailsRequested(contactId)
        }
    }

    // -------------------------
    // Avatar related
    // -------------------------

    avatarSource: sender?.profileImage.name ?? ""
    isCircularAvatar: true
    isAvatarClickable: true
    avatarId: contactId
    avatarLetterColor: sender?.profileImage.color ?? Theme.palette.miscColor5
    avatarLetterText: sender?.displayName ?? ""
    isAvatarLetterAcronym: true
    avatarMaxTextLen: 2
}
