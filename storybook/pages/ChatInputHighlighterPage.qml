import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ

Item {
    id: root

    ChatInputHighlighter {
        id: highlighter
        quickTextDocument: textArea.textDocument
    }

    readonly property var emph: highlighter.emphasisAt(textArea.cursorPosition)
    readonly property var vemph: highlighter.emphasisAtInsertion(textArea.cursorPosition)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 16
        color: "transparent"

        TextArea {
            id: textArea
            anchors.fill: parent
            wrapMode: TextEdit.Wrap
            font.pixelSize: 15
            text: "**bold** text\n*italic* text\n~~strikethrough~~\n***bold italic***\n**bold** and *italic* together\n**multi-\nline bold**"
        }

        ColumnLayout {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 8

            CheckBox {
                text: "Multi-line emphasis"
                checked: highlighter.multilineEmphasis
                onToggled: highlighter.multilineEmphasis = checked
            }

            Row {
                spacing: 16
                Text { text: "emphasis at:\t"}
                Text { text: "bold: "          + emph.bold }
                Text { text: "italic: "        + emph.italic }
                Text { text: "strikethrough: " + emph.strikethrough }
            }
            Row {
                spacing: 16

                Text { text: "emphasis at insertion:\t"}
                Text { text: "bold: "          + vemph.bold }
                Text { text: "italic: "        + vemph.italic }
                Text { text: "strikethrough: " + vemph.strikethrough }
            }
        }
    }
}

// category: Chat
// status: good
