pragma ComponentBehavior: Bound

import QtQuick

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils

Item {
    id: root

    readonly property alias hoveredLink: chatTextItem.hoveredLink
    readonly property string selectedText: chatTextItem.selectedText

    property alias highlightedLink: chatTextItem.highlightedLink
    property bool clearSelectionOnLostFocus: true
    property ChatTextAppearance appearance
    property bool linkAddressAndEnsName
    property string disabledTooltipText

    property StatusMessageDetails messageDetails: StatusMessageDetails {}
    property bool isEdited: false

    property bool isMobile

    property alias textField: chatTextItem

    signal linkActivated(string link)

    implicitHeight: chatTextItem.implicitHeight

    QtObject {
        id: d
        function showDisabledTooltipForAddressEnsName(link) {
            return link.startsWith('//send-via-personal-chat//') && !!root.disabledTooltipText
        }
    }

    // The parser and renderer share typed runs; decorations remain in the item.
    ChatTextItem {
        id: chatTextItem
        objectName: "StatusTextMessage_chatText"
        // `text` (plain, mentions resolved, with the edited suffix) is the
        // accessible name and what e2e reads; ChatTextItem provides both.

        anchors.left: parent.left
        anchors.right: parent.right

        appearance: root.appearance
        selectable: !root.isMobile
        persistentSelection: !root.clearSelectionOnLostFocus

        edited: root.isEdited
        segments: MarkdownUtils.toChatTextSegments(root.messageDetails.unparsedText, root.messageDetails.mentionsMap)

        // Profile mentions use //<pubkey>; URLs and wallet intents keep their href.
        onLinkActivated: href => {
            if (d.showDisabledTooltipForAddressEnsName(href))
                return
            const isLink = href.indexOf("://") >= 0 || href.startsWith("//")
            root.linkActivated(isLink ? href : "//" + href)
        }

        StatusLazyToolTip {
            id: disabledLinkTooltip
            objectName: "StatusTextMessage_disabledLinkTooltipLoader"
            tooltipObjectName: "StatusTextMessage_disabledLinkTooltip"
            target: chatTextItem
            enabled: d.showDisabledTooltipForAddressEnsName(chatTextItem.hoveredLink)
            text: root.disabledTooltipText
            delay: 100
        }
    }
}
