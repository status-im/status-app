import QtQuick
import QtQuick.Controls
import StatusQ

Item {
    id: root

    TextArea {
        id: textArea
        anchors.fill: parent
        anchors.margins: 16
        wrapMode: TextEdit.Wrap
        font.pixelSize: 15
        text: "**bold** text\n*italic* text\n~~strikethrough~~\n***bold italic***\n**bold** and *italic* together"

        ChatInputHighlighter {
            quickTextDocument: textArea.textDocument
        }
    }
}

// category: Chat
// status: good
