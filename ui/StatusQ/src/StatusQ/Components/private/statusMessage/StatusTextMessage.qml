import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Components
import StatusQ.Controls
import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

Item {
    id: root

    readonly property alias hoveredLink: chatTextLoader.hoveredLink
    readonly property string selectedText: chatTextLoader.item && chatTextLoader.sourceComponent === chatTextDesktopComp ? chatTextLoader.item.selectedText
                                                                                                                         : ""

    property string highlightedLink: ""
    property bool linkAddressAndEnsName
    property string disabledTooltipText

    property StatusMessageDetails messageDetails: StatusMessageDetails {}
    property bool isEdited: false
    property bool convertToSingleLine: false
    property bool stripHtmlTags: false
    property bool allowShowMore: true
    property bool isReply

    property bool isMobile

    property alias textField: chatTextLoader

    signal linkActivated(string link)
    signal contextMenuRequested(point pos)

    implicitWidth: chatTextLoader.width
    implicitHeight: chatTextLoader.height + d.showMoreHeight / 2

    QtObject {
        id: d
        readonly property string hoveredLink: chatTextLoader.hoveredLink || root.highlightedLink

        property bool readMore: false
        readonly property int showMoreHeight: showMoreButtonLoader.visible ? showMoreButtonLoader.height : 0
        readonly property int maxHeight: 200

        // Simple heuristic to check if message contains quote block.
        readonly property bool hasBlockQuote: d.text.indexOf("<blockquote") !== -1

        // Character ranges ({ start, end }) of every quote block, used to draw a
        // vertical bar per quote block. layoutRevision is bumped on relayout to
        // force the bars' geometry bindings (positionToRectangle calls) to
        // re-evaluate, since method calls are not tracked by bindings.
        property var quoteRanges: []
        property int layoutRevision: 0
        function updateQuoteRanges() {
            const item = chatTextLoader.item
            d.quoteRanges = (item && item.textDocument)
                          ? TextDocumentUtils.blockquoteRanges(item.textDocument) : []
        }

        readonly property string text: {
            if (root.messageDetails.contentType === StatusMessage.ContentType.Sticker)
                return "";

            if (root.messageDetails.contentType === StatusMessage.ContentType.Emoji && !root.isEdited)
                return Emoji.parse(root.messageDetails.messageText, Emoji.size.middle);

            let formattedMessage = Utils.linkifyAndXSS(root.messageDetails.messageText, root.linkAddressAndEnsName);

            if (root.isEdited) {
                // insert "(edited)" just before the last closing tag (e.g. </p>,
                // </blockquote>); for code blocks and plain text, append at the end
                const index = formattedMessage.endsWith("code>") ? formattedMessage.length : (formattedMessage.endsWith(">") ? formattedMessage.lastIndexOf("</") : formattedMessage.length);
                const editedMessage = formattedMessage.slice(0, index)
                                    + ` <span class="isEdited">` + qsTr("(edited)") + `</span>`
                                    + formattedMessage.slice(index);
                return Utils.getMessageWithStyle(root.Theme.palette, Emoji.parse(editedMessage))
            }

            if (root.convertToSingleLine)
                formattedMessage = Utils.convertToSingleLine(formattedMessage)

            if (root.stripHtmlTags)
                formattedMessage = Utils.stripHtmlTags(formattedMessage)

            // add emoji tags even after html striped
            formattedMessage = Emoji.parse(formattedMessage)

            if (root.stripHtmlTags)
                // short return not to add styling when no html
                return formattedMessage

            return Utils.getMessageWithStyle(root.Theme.palette, formattedMessage,
                                             chatTextLoader.hoveredLink, !!root.disabledTooltipText)
        }

        // Plain message body for accessibility. The rendered text is RichText
        // (HTML), which Qt's Android a11y backend does not surface, so the body
        // is otherwise invisible to screen readers and e2e. Expose the unstyled
        // text via Accessible.name on the text element instead.
        readonly property string plainText: {
            const base = Utils.stripHtmlTags(root.messageDetails.messageText)
            // The "(edited)" indicator is only a visual HTML span in the rendered
            // text; append it here so it reaches Accessible.name too.
            return root.isEdited ? base + " " + qsTr("(edited)") : base
        }

        function showDisabledTooltipForAddressEnsName(link) {
            return link.startsWith('//send-via-personal-chat//') && !!root.disabledTooltipText
        }
    }

    Loader {
        id: chatTextLoader

        readonly property string hoveredLink: item ? item.hoveredLink : ""

        readonly property int effectiveHeight: showMoreButtonLoader.active && !d.readMore ? d.maxHeight
                                                                                          : item.implicitHeight
        height: effectiveHeight + d.showMoreHeight / 2
        anchors.left: parent.left
        anchors.right: parent.right

        opacity: !showMoreOpacityMask.active && !horizontalOpacityMask.active ? 1 : 0

        // Mobile uses the lightweight StatusBaseText, except for quote messages
        // which need StatusTextArea (textDocument/positionToRectangle) to draw the
        // quote bar. Desktop always uses StatusTextArea to allow selection by mouse.
        sourceComponent: (root.isMobile && !d.hasBlockQuote) ? chatTextMobileComp
                                                             : chatTextDesktopComp
        onItemChanged: d.updateQuoteRanges()

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

    Component {
        id: chatTextMobileComp
        StatusBaseText {
            objectName: "StatusTextMessage_chatText"
            text: d.text
            Accessible.role: Accessible.StaticText
            Accessible.name: d.plainText
            color: root.isReply ? Theme.palette.baseColor1 : Theme.palette.directColor1
            font.pixelSize: root.isReply ? Theme.secondaryTextFontSize : Theme.primaryTextFontSize
            textFormat: Text.RichText
            wrapMode: root.convertToSingleLine ? Text.NoWrap : Text.Wrap

            onLinkActivated: function(link) {
                if(d.showDisabledTooltipForAddressEnsName(link)) {
                    return
                }
                root.linkActivated(link)
            }
            onLinkHovered: (link) => disabledLinkTooltip.visible = d.showDisabledTooltipForAddressEnsName(link)
        }
    }

    Component {
        id: chatTextDesktopComp
        StatusTextArea {
            objectName: "StatusTextMessage_chatText"
            Accessible.role: Accessible.StaticText
            Accessible.name: d.plainText
            background: null
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            text: d.text
            selectedTextColor: Theme.palette.directColor1
            color: root.isReply ? Theme.palette.baseColor1 : Theme.palette.directColor1
            font.pixelSize: root.isReply ? Theme.secondaryTextFontSize : Theme.primaryTextFontSize
            textFormat: Text.RichText
            wrapMode: root.convertToSingleLine ? Text.NoWrap : Text.Wrap
            readOnly: true
            selectByMouse: !root.isMobile  // mouse selection is desktop-only

            // quote-bar overlay bookkeeping (initial compute handled by the
            // loader's onItemChanged)
            onTextChanged: d.updateQuoteRanges()
            onContentHeightChanged: d.layoutRevision++
            onContentWidthChanged: d.layoutRevision++
            onWidthChanged: d.layoutRevision++

            onLinkActivated: function(link) {
                if(d.showDisabledTooltipForAddressEnsName(link)) {
                    return
                }
                root.linkActivated(link)
                deselect()
            }
            onLinkHovered: (link) => disabledLinkTooltip.visible = d.showDisabledTooltipForAddressEnsName(link)

            // context menu handlers
            ContextMenu.menu: null // disable builtin "edit" menu; we're not an edit control
            inputMethodHints: Qt.ImhNoEditMenu

            // Workaround to ignore unnecessarily triggered onPressAndHold on mobile when dragging
            // chat content
            property int onPressY

            onPressAndHold: function(event) {
                if (onPressY !== Math.floor(mapToGlobal(0, 0).y))
                    return

                event.accepted = true
                root.contextMenuRequested(Qt.point(event.x, event.y))
            }
            onPressed: function(event) {
                onPressY = mapToGlobal(0, 0).y

                if (event.button === Qt.RightButton) {
                    event.accepted = true
                    root.contextMenuRequested(Qt.point(event.x, event.y))
                }
            }
        }
    }

    StatusSyntaxHighlighter {
        quickTextDocument: chatTextLoader.item?.textDocument ?? null
        hyperlinkHoverColor: Theme.palette.primaryColor3
        highlightedHyperlink: d.hoveredLink
        features: StatusSyntaxHighlighter.HighlightedHyperlink
    }

    // Horizontal crop mask
    Loader {
        id: horizontalClipMask
        anchors.fill: chatTextLoader
        active: horizontalOpacityMask.active
        visible: false
        sourceComponent: LinearGradient {
            start: Qt.point(0, 0)
            end: Qt.point(chatTextLoader.width, 0)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "white" }
                GradientStop { position: 0.85; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    Loader {
        id: horizontalOpacityMask
        active: root.convertToSingleLine && chatTextLoader.implicitWidth > chatTextLoader.width
        anchors.fill: chatTextLoader
        sourceComponent: OpacityMask {
            source: chatTextLoader
            maskSource: horizontalClipMask
        }
    }

    // Vertical "show more" mask + button
    Loader {
        id: showMoreMaskGradient
        anchors.fill: chatTextLoader
        active: showMoreButtonLoader.active && !d.readMore
        visible: false
        sourceComponent: LinearGradient {
            start: Qt.point(0, 0)
            end: Qt.point(0, chatTextLoader.height)
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
        anchors.fill: chatTextLoader
        sourceComponent: OpacityMask {
            source: chatTextLoader
            maskSource: showMoreMaskGradient
        }
    }

    // Vertical bar drawn for each quote block. Rendered whenever the text control
    // exposes a textDocument (StatusTextArea) - desktop, and mobile quote messages.
    Item {
        anchors.fill: chatTextLoader
        clip: true

        Repeater {
            model: d.quoteRanges
            delegate: Rectangle {
                id: quoteBar
                required property var modelData

                readonly property rect startRect: {
                    d.layoutRevision // dependency: re-evaluate on relayout
                    const item = chatTextLoader.item
                    return (item && item.positionToRectangle)
                         ? item.positionToRectangle(quoteBar.modelData.start) : Qt.rect(0, 0, 0, 0)
                }
                readonly property rect endRect: {
                    d.layoutRevision // dependency: re-evaluate on relayout
                    const item = chatTextLoader.item
                    return (item && item.positionToRectangle)
                         ? item.positionToRectangle(quoteBar.modelData.end) : Qt.rect(0, 0, 0, 0)
                }

                x: 0
                y: startRect.y
                width: 2
                radius: width / 2
                height: Math.max(0, endRect.y + endRect.height - startRect.y)
                color: Theme.palette.baseColor1
            }
        }
    }

    Loader {
        id: showMoreButtonLoader
        active: root.allowShowMore && chatTextLoader.item.implicitHeight > d.maxHeight
        visible: active
        anchors.verticalCenter: chatTextLoader.bottom
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
