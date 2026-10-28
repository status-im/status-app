import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// DEMO: the raw message (unparsedText) in one plain Text. No markdown, mentions,
// links, emoji sizing, selection, "show more" or "(edited)" marker.
Item {
    id: root

    readonly property string hoveredLink: ""
    readonly property string selectedText: ""

    property string highlightedLink
    property bool clearSelectionOnLostFocus
    property bool linkAddressAndEnsName
    property string disabledTooltipText

    property StatusMessageDetails messageDetails: StatusMessageDetails {}
    property bool isEdited: false
    property bool allowShowMore: true

    property bool isMobile

    property alias textField: text

    signal linkActivated(string link)

    implicitHeight: text.implicitHeight

    Text {
        id: text
        objectName: "StatusTextMessage_chatText"
        Accessible.role: Accessible.StaticText
        Accessible.name: text.text

        anchors.left: parent.left
        anchors.right: parent.right

        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Theme.palette.directColor1
        font.family: Fonts.baseFont.family
        font.pixelSize: Theme.primaryTextFontSize
        text: root.messageDetails.unparsedText
    }
}
