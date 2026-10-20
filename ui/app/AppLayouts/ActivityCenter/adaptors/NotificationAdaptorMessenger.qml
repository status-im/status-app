import QtQuick

import StatusQ
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

    /*!
        Display names of the users mentioned in the message text, keyed by
        public key, as returned by MentionResolver.resolveFor(). A mention
        missing from the map is rendered as its raw public key.
    */
    property var mentionsMap: ({})

    context.contextTertiaryName: notification?.threadId ? notification.threadName || qsTr("Thread") : ""
    context.tertiaryIconName: notification?.threadId ? "thread" : ""

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

    content: {
        const text = notification?.message?.unparsedText ?? ""
        if (!text)
            return ""
        return Utils.isGifOnlyText(text) ? qsTr("GIF")
                                         : MarkdownUtils.styledText(text, root.mentionsMap, {},
                                                                    true /*enlargeEmoji*/)
    }
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

    nestedSubsectionId: notification?.threadId ?? ""
    subsectionItemId: notification && notification.message ? notification.message.id : ""
    redirectToDetails: true
}
