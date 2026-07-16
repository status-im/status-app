import QtQuick
import QtQuick.Layouts

import StatusQ.Controls

Item {
    id: root

    property alias inputComponent: chatInputLoader.sourceComponent
    property alias active: chatInputLoader.active

    property string messageText: ""

    signal editCancelled()
    signal editCompleted(string newMsgText)

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    function editedMessageText() {
        const input = chatInputLoader.item
        if (!input)
            return ""

        if (input.getTextWithPublicKeys)
            return input.getTextWithPublicKeys()

        return input.messageText || ""
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 4

        Loader {
            id: chatInputLoader
            Layout.fillWidth: true

            /*
                NOTE: sourceComponent must have `messageText` property
                TODO: Replace with StatusChatInput once its moved to StatusQ.
            */

            sourceComponent: StatusInput {
                readonly property string messageText: input.text
                width: parent.width
                input.placeholderText: ""
                input.text: root.messageText
                maximumHeight: 40
            }
        }
    }

    Connections {
        target: chatInputLoader.item
        ignoreUnknownSignals: true

        function onEditCancelRequested() {
            root.editCancelled()
        }

        function onEditAcceptRequested() {
            root.editCompleted(root.editedMessageText())
        }

        function onSendMessageRequested() {
            root.editCompleted(root.editedMessageText())
        }
    }
}
