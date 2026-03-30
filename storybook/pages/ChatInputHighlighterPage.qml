import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ
import StatusQ.Controls

Item {
    id: root

    ChatInputHighlighter {
        id: highlighter
        quickTextDocument: textArea.textDocument
        codeBackground: "#e8e8e8"
    }

    readonly property var emph: highlighter.emphasisAt(textArea.cursorPosition)
    readonly property var vemph: highlighter.emphasisAtInsertion(textArea.cursorPosition)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            color: "transparent"

            ScrollView {
                anchors.fill: parent

                contentWidth: availableWidth

                StatusTextArea {
                    id: textArea

                    wrapMode: TextEdit.Wrap
                    font.pixelSize: 15
                    text:
`Some **bold** text there!
Some *italic* text text there!

This is ~~strikethrough~~ text.

Both bold and italics goes here: ***bold italic***
And **bold** and *italic* together in a single line.

**multi-
line bold here, works only in multi-line emphasis mode**

**Code:**

Sometimes it's enough to use \`inline code\`.

For bigger chunks of code it's better to use triple-ticks code block:

\`\`\`
#include <iostream>
using namespace std;

int main() {
    // This statement prints "Hello World"
    cout << "Hello World";

    return 0;
}
\`\`\`
`
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false

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
