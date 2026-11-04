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
    property bool allowShowMore: true

    property bool isMobile

    property alias textField: chatTextItem

    signal linkActivated(string link)

    implicitHeight: chatTextItem.height + d.showMoreHeight / 2

    QtObject {
        id: d
        property bool readMore: false
        readonly property int showMoreHeight: showMoreButtonLoader.visible ? showMoreButtonLoader.height : 0
        readonly property int maxHeight: 200

        // Expose the unstyled body with resolved mention names to screen readers
        // and e2e consumers, independently of the painted document.
        readonly property string plainText: {
            const base = MarkdownUtils.plainText(root.messageDetails.unparsedText,
                                                 root.messageDetails.mentionsMap)
            // Include the visual suffix in the accessible text as well.
            return root.isEdited ? base + " " + qsTr("(edited)") : base
        }

        function showDisabledTooltipForAddressEnsName(link) {
            return link.startsWith('//send-via-personal-chat//') && !!root.disabledTooltipText
        }
    }


    // The parser and renderer share typed runs; decorations remain in the item.
    ChatTextItem {
        id: chatTextItem
        objectName: "StatusTextMessage_chatText"
        readonly property string text: d.plainText // for e2e / a11y read
        Accessible.role: Accessible.StaticText
        Accessible.name: d.plainText

        readonly property int effectiveHeight:
            showMoreButtonLoader.active && !d.readMore ? d.maxHeight : implicitHeight

        height: effectiveHeight + d.showMoreHeight / 2
        anchors.left: parent.left
        anchors.right: parent.right

        appearance: root.appearance
        selectable: !root.isMobile
        persistentSelection: !root.clearSelectionOnLostFocus

        // Collapsed: the last 15% fade out, computed by the shader on the
        // text's layer, with no second layer for a mask
        layer.enabled: showMoreButtonLoader.active && !d.readMore
        layer.effect: StatusEdgeFadeEffect {
            bottomFade: height * 0.15
        }
        // The layer shows only the collapsed bounds; skip painting the rest.
        clip: layer.enabled

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

    // "show more" button
    Loader {
        id: showMoreButtonLoader
        objectName: "StatusTextMessage_showMore"
        active: root.allowShowMore && chatTextItem.implicitHeight > d.maxHeight
        visible: active
        anchors.verticalCenter: chatTextItem.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: StatusButton {
            type: StatusBaseButton.Type.Primary
            size: StatusBaseButton.Size.Small
            spacing: 1
            icon.name: d.readMore ? "chevron-up": "chevron-down"
            onClicked: {
                d.readMore = !d.readMore
            }
        }
    }
}
