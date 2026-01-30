import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Profile.helpers

import utils

/*!
    \qmltype NotificationAdaptorMessenger
    \inqmlmodule AppLayouts.ActivityCenter.adaptors

    Base adaptor for notification-specific adaptors.

    This component provides shared logic and derived data used by
    messenger-related notification adaptors (e.g. mention, reply).

    Responsibilities:
    - Resolve contact-related information from the contacts model
    - Normalize sender identity, avatar, trust status and message metadata
    - Normalize notification context depending on community and / or chat objects information
    - Expose a stable API for higher-level adaptors and UI components

    This adaptor is non-visual and intentionally contains presentation
    logic that should not be duplicated in UI delegates.
*/
NotificationAdaptorSender {
    id: root

    // -------------------------
    // Header row related
    // -------------------------

    title: sender?.displayName ?? ""
    chatKey: sender?.compressedPubKey ?? ""
    isContact: sender?.isContact ?? false
    trustIndicator: sender?.trustIndicator ?? Constants.trustStatus.unknown
    isBlocked: sender?.isBlocked ?? false

    // -------------------------
    // Content block related
    // -------------------------

    content: notification && notification.message ? notification.message.messageText : ""
    attachments: {
        const msg = notification && notification.message
        const images = msg && msg.albumMessageImages
        return images && images.length > 0
            ? images.split(" ").filter(u => u.length > 0)
            : []
    }

    // -------------------------
    // Navigation related
    // -------------------------

    subsectionItemId: notification && notification.message ? notification.message.id : ""
    redirectToDetails: true
}
