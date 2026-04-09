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

    readonly property alias hoveredLink: chatText.hoveredLink

    property string highlightedLink: ""
    property bool linkAddressAndEnsName
    property string disabledTooltipText

    property StatusMessageDetails messageDetails: StatusMessageDetails {}
    property bool isEdited: false
    property bool convertToSingleLine: false
    property bool stripHtmlTags: false

    property alias textField: chatText
    property bool allowShowMore: true

    signal linkActivated(string link)

    implicitWidth: chatText.implicitWidth
    implicitHeight: chatText.height + d.showMoreHeight / 2

    QtObject {
        id: d
        property string hoveredLink: chatText.hoveredLink || root.highlightedLink

        property bool readMore: false
        property bool isQuote: false
        readonly property int showMoreHeight: showMoreButtonLoader.visible ? showMoreButtonLoader.height : 0

        readonly property string text: {
            if (root.messageDetails.contentType === StatusMessage.ContentType.Sticker)
                return "";

            if (root.messageDetails.contentType === StatusMessage.ContentType.Emoji && !root.isEdited)
                return Emoji.parse(root.messageDetails.messageText, Emoji.size.middle);

            let formattedMessage = Utils.linkifyAndXSS(root.messageDetails.messageText, root.linkAddressAndEnsName);

            isQuote = (formattedMessage.startsWith("<blockquote>") && formattedMessage.endsWith("</blockquote>"));

            if (root.isEdited) {
                const index = formattedMessage.endsWith("code>") ? formattedMessage.length : (formattedMessage.endsWith(">") ? formattedMessage.length - 4 : formattedMessage.length);
                const editedMessage = formattedMessage.slice(0, index)
                                    + ` <span class="isEdited">` + qsTr("(edited)") + `</span>`
                                    + formattedMessage.slice(index);
                return Utils.getMessageWithStyle(root.Theme.palette, Emoji.parse(editedMessage))
            }

            if (root.convertToSingleLine || isQuote)
                formattedMessage = Utils.convertToSingleLine(formattedMessage)

            if (root.stripHtmlTags)
                formattedMessage = Utils.stripHtmlTags(formattedMessage)

            // add emoji tags even after html striped
            formattedMessage = Emoji.parse(formattedMessage)

            if (root.stripHtmlTags)
                // short return not to add styling when no html
                return formattedMessage

            return Utils.getMessageWithStyle(root.Theme.palette, formattedMessage,
                                             chatText.hoveredLink, !!root.disabledTooltipText)
        }

        function showDisabledTooltipForAddressEnsName(link) {
            return link.startsWith('//send-via-personal-chat//') && !!root.disabledTooltipText
        }
    }

    Rectangle {
        width: 1
        height: chatText.height
        radius: Theme.radius
        visible: d.isQuote
        color: Theme.palette.baseColor1
    }

    TextEdit {
        id: chatText
        objectName: "StatusTextMessage_chatText"

        readonly property int effectiveHeight: showMoreButtonLoader.active && !d.readMore
                                               ? 200
                                               : chatText.implicitHeight

        height: effectiveHeight + d.showMoreHeight / 2
        anchors.left: parent.left
        anchors.leftMargin: d.isQuote ? Theme.halfPadding : 0
        anchors.right: parent.right
        opacity: !showMoreOpacityMask.active && !horizontalOpacityMask.active ? 1 : 0
        text: d.text
        selectedTextColor: Theme.palette.directColor1
        selectionColor: Theme.palette.primaryColor3
        color: d.isQuote ? Theme.palette.baseColor1 : Theme.palette.directColor1
        font.family: Fonts.baseFont.family
        font.pixelSize: Theme.primaryTextFontSize
        textFormat: Text.RichText
        wrapMode: root.convertToSingleLine ? Text.NoWrap : Text.Wrap
        readOnly: true
        selectByMouse: true  // applies to mouse only, not touch
        enabled: !Utils.isMobile // eats the internal touch events to enable the external context menu on long press

        // disable native (edit) context menu; we're really not an edit control
        inputMethodHints: Qt.ImhNoEditMenu

        onLinkActivated: function(link) {
            if(d.showDisabledTooltipForAddressEnsName(link)) {
                return
            }
            root.linkActivated(link)
        }
        onLinkHovered: (link) => disabledLinkTooltip.visible = d.showDisabledTooltipForAddressEnsName(link)
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

    StatusSyntaxHighlighter {
        quickTextDocument: chatText.textDocument
        hyperlinkHoverColor: Theme.palette.primaryColor3
        highlightedHyperlink: d.hoveredLink
        features: StatusSyntaxHighlighter.HighlightedHyperlink
    }

    // Horizontal crop mask
    Loader {
        id: horizontalClipMask
        anchors.fill: chatText
        active: horizontalOpacityMask.active
        visible: false
        sourceComponent: LinearGradient {
            start: Qt.point(0, 0)
            end: Qt.point(chatText.width, 0)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "white" }
                GradientStop { position: 0.85; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    Loader {
        id: horizontalOpacityMask
        active: root.convertToSingleLine && chatText.implicitWidth > chatText.width
        anchors.fill: chatText
        sourceComponent: OpacityMask {
            source: chatText
            maskSource: horizontalClipMask
        }
    }

    // Vertical "show more" mask

    Loader {
        id: showMoreMaskGradient
        anchors.fill: chatText
        active: showMoreButtonLoader.active && !d.readMore
        visible: false
        sourceComponent: LinearGradient {
            start: Qt.point(0, 0)
            end: Qt.point(0, chatText.height)
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
        anchors.fill: chatText
        sourceComponent: OpacityMask {
            source: chatText
            maskSource: showMoreMaskGradient
        }
    }

    Loader {
        id: showMoreButtonLoader
        active: root.allowShowMore && chatText.implicitHeight > 200
        visible: active
        anchors.verticalCenter: chatText.bottom
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
