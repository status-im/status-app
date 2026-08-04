import QtQuick
import Qt5Compat.GraphicalEffects

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils

Item {
    id: root

    readonly property alias hoveredLink: chatTextView.hoveredLink
    readonly property string selectedText: chatTextView.selectedText

    property alias highlightedLink: chatTextView.highlightedLink
    property bool linkAddressAndEnsName
    property string disabledTooltipText

    property StatusMessageDetails messageDetails: StatusMessageDetails {}
    property bool isEdited: false
    property bool allowShowMore: true

    property bool isMobile

    property alias textField: chatTextView

    signal linkActivated(string link)
    signal contextMenuRequested(point pos)

    implicitHeight: chatTextView.height + d.showMoreHeight / 2

    QtObject {
        id: d
        property bool readMore: false
        readonly property int showMoreHeight: showMoreButtonLoader.visible ? showMoreButtonLoader.height : 0
        readonly property int maxHeight: 200

        // Plain message body for accessibility. The rendered text is RichText
        // (HTML), which Qt's Android a11y backend does not surface, so the body
        // is otherwise invisible to screen readers and e2e. Expose the unstyled
        // text via Accessible.name on the text element instead.
        readonly property string plainText: {
            // Plain text of the same source ChatTextView renders (unparsedText), with mentions
            // resolved to display names.
            const base = MarkdownUtils.plainText(root.messageDetails.unparsedText,
                                                 root.messageDetails.mentionsMap)
            // The "(edited)" indicator is only a visual HTML span in the rendered
            // text; append it here so it reaches Accessible.name too.
            return root.isEdited ? base + " " + qsTr("(edited)") : base
        }

        function showDisabledTooltipForAddressEnsName(link) {
            return link.startsWith('//send-via-personal-chat//') && !!root.disabledTooltipText
        }
    }

    // Client-side markdown render path (main desktop bubble): renders `unparsedText` via the
    // StatusQ parser + ChatTextView, matching the editor. Quote bars, code frames and link-hover
    // are drawn inside ChatTextView.
    ChatTextView {
        id: chatTextView
        objectName: "StatusTextMessage_chatText"
        readonly property string text: d.plainText // for e2e / a11y read
        Accessible.role: Accessible.StaticText
        Accessible.name: d.plainText

        readonly property int effectiveHeight:
            showMoreButtonLoader.active && !d.readMore ? d.maxHeight : implicitHeight

        height: effectiveHeight + d.showMoreHeight / 2
        anchors.left: parent.left
        anchors.right: parent.right

        selectable: !root.isMobile
        font.pixelSize: Theme.primaryTextFontSize

        opacity: !showMoreOpacityMask.active ? 1 : 0

        edited: root.isEdited
        blocks: MarkdownUtils.toBlocks(
                    root.messageDetails.unparsedText,
                    root.messageDetails.mentionsMap,
                    chatTextView.font,
                    false /*formatUnclosedCodeFence*/,
                    true /*fullLineHeightEmojis*/,
                    Theme.primaryTextFontSize /*emojiSizeOffset*/,
                    Emoji.base)

        // Reuse the existing linkActivated contract: "//<pubkey>" opens the profile, a URL opens.
        onMentionClicked: (pubKey) => root.linkActivated("//" + pubKey)
        onLinkClicked: (url) => root.linkActivated(url)

        HoverHandler {
            id: hoverHandler
        }
        StatusToolTip {
            id: disabledLinkTooltip
            text: root.disabledTooltipText
            delay: 100
            x: hoverHandler.point.position.x - 60
            y: -disabledLinkTooltip.height + hoverHandler.point.position.y - 10
        }
    }

    // Vertical "show more" mask + button
    Loader {
        id: showMoreMaskGradient
        anchors.fill: chatTextView
        active: showMoreButtonLoader.active && !d.readMore
        visible: false
        sourceComponent: LinearGradient {
            start: Qt.point(0, 0)
            end: Qt.point(0, chatTextView.height)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "white" }
                GradientStop { position: 0.85; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    Loader {
        id: showMoreOpacityMask
        active: showMoreButtonLoader.active && !d.readMore
        anchors.fill: chatTextView
        sourceComponent: OpacityMask {
            source: chatTextView
            maskSource: showMoreMaskGradient
        }
    }

    Loader {
        id: showMoreButtonLoader
        active: root.allowShowMore && chatTextView.implicitHeight > d.maxHeight
        visible: active
        anchors.verticalCenter: chatTextView.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: StatusRoundButton {
            implicitWidth: 24
            implicitHeight: 24
            type: StatusRoundButton.Type.Secondary
            icon.name: d.readMore ? "chevron-up":  "chevron-down"
            onClicked: {
                d.readMore = !d.readMore
            }
        }
    }
}
