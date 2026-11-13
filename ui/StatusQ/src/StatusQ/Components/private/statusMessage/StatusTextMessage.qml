pragma ComponentBehavior: Bound

import QtQuick

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils

// The parser and renderer share typed runs; decorations remain in the item.
// `text` (plain, mentions resolved, with the edited suffix) is the accessible
// name and what e2e reads; ChatTextItem provides both.
ChatTextItem {
    id: root

    property bool clearSelectionOnLostFocus: true
    property bool linkAddressAndEnsName
    property string disabledTooltipText

    property StatusMessageDetails messageDetails: StatusMessageDetails {}
    property bool isEdited: false

    property bool isMobile

    // ChatTextItem's own linkActivated carries the raw href; this one carries
    // the link in the form message consumers expect, and is not emitted for
    // send-via-personal-chat links while they are disabled.
    signal messageLinkActivated(string link)

    objectName: "StatusTextMessage_chatText"

    selectable: !root.isMobile
    persistentSelection: !root.clearSelectionOnLostFocus

    edited: root.isEdited
    segments: inlineLinkSupport.item ? inlineLinkSupport.item.segments : d.sourceSegments

    QtObject {
        id: d

        readonly property list<chatTextSegment> sourceSegments: root.messageDetails.textSegments
        readonly property var inlineLinks: {
            const inlineLinks = root.messageDetails.inlineLinks
            if (!Object.keys(inlineLinks).length)
                return inlineLinks
            // A lone URL keeps its existing preview presentation. Inline
            // wrappers are for links accompanied by other message content.
            const text = d.sourceSegments.map(segment => segment.text).join("").trim()
            const link = d.sourceSegments.find(segment => !!segment.href)
            return link && text === link.href ? ({}) : inlineLinks
        }
    }

    Loader {
        id: inlineLinkSupport
        objectName: "StatusTextMessage_inlineLinkSupport"
        active: Object.keys(d.inlineLinks).length > 0
        sourceComponent: StatusInlineLinkSupport {
            textItem: root
            sourceSegments: d.sourceSegments
            links: d.inlineLinks
        }
    }

    // Profile mentions use //<pubkey>; URLs and wallet intents keep their href.
    onLinkActivated: href => {
        if (disabledLinkTooltip.isDisabledLink(href))
            return
        const isLink = href.indexOf("://") >= 0 || href.startsWith("//")
        root.messageLinkActivated(isLink ? href : "//" + href)
    }

    StatusLazyToolTip {
        id: disabledLinkTooltip

        // Send-via-personal-chat links (addresses, ENS names) while disabled.
        function isDisabledLink(link: string): bool {
            return link.startsWith('//send-via-personal-chat//') && !!root.disabledTooltipText
        }

        objectName: "StatusTextMessage_disabledLinkTooltipLoader"
        tooltipObjectName: "StatusTextMessage_disabledLinkTooltip"
        target: root
        enabled: isDisabledLink(root.hoveredLink)
        text: root.disabledTooltipText
        delay: 100
    }
}
