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
        property bool isQuote: false
        readonly property int showMoreHeight: showMoreButtonLoader.visible ? showMoreButtonLoader.height : 0
        readonly property int maxHeight: 200

        readonly property string text: {
            if (root.messageDetails.contentType === StatusMessage.ContentType.Sticker)
                return "";

            if (root.messageDetails.contentType === StatusMessage.ContentType.Emoji && !root.isEdited)
                return Emoji.parse(root.messageDetails.messageText, Emoji.size.middle);

            let formattedMessage = Utils.linkifyAndXSS(root.messageDetails.messageText, root.linkAddressAndEnsName);

            isQuote = formattedMessage.startsWith("<blockquote>") && formattedMessage.endsWith("</blockquote>")

            if (root.isEdited) {
                const index = formattedMessage.endsWith("code>") ? formattedMessage.length : (formattedMessage.endsWith(">") ? formattedMessage.length - 4 : formattedMessage.length);
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

        function showDisabledTooltipForAddressEnsName(link) {
            return link.startsWith('//send-via-personal-chat//') && !!root.disabledTooltipText
        }
    }

    Rectangle {
        width: 1
        height: chatTextLoader.height
        radius: Theme.radius
        visible: d.isQuote
        color: Theme.palette.baseColor1
    }

    Loader {
        id: chatTextLoader

        readonly property string hoveredLink: item ? item.hoveredLink : ""

        readonly property int effectiveHeight: showMoreButtonLoader.active && !d.readMore ? d.maxHeight
                                                                                          : item.implicitHeight
        height: effectiveHeight + d.showMoreHeight / 2
        anchors.left: parent.left
        anchors.leftMargin: d.isQuote ? Theme.halfPadding : 0
        anchors.right: parent.right

        opacity: !showMoreOpacityMask.active && !horizontalOpacityMask.active ? 1 : 0

        sourceComponent: root.isMobile ? chatTextMobileComp : chatTextDesktopComp

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
            color: d.isQuote || root.isReply ? Theme.palette.baseColor1 : Theme.palette.directColor1
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
            background: null
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            text: d.text
            selectedTextColor: Theme.palette.directColor1
            color: d.isQuote || root.isReply ? Theme.palette.baseColor1 : Theme.palette.directColor1
            font.pixelSize: root.isReply ? Theme.secondaryTextFontSize : Theme.primaryTextFontSize
            textFormat: Text.RichText
            wrapMode: root.convertToSingleLine ? Text.NoWrap : Text.Wrap
            readOnly: true
            selectByMouse: true  // applies to mouse only, not touch

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
            onPressAndHold: function(event) {
                event.accepted = true
                root.contextMenuRequested(Qt.point(event.x, event.y))
            }
            onPressed: function(event) {
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
