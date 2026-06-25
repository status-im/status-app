import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ

import shared.status

Item {
    id: root

    readonly property var emph: textArea.emphasisAt(textArea.cursorPosition)
    readonly property var vemph: textArea.emphasisAtInsertion(textArea.cursorPosition)

    function randomName() {
        const n = 1 + Math.floor(Math.random() * 5)
        let s = "@"
        for (let i = 0; i < n; ++i)
            s += String.fromCharCode(65 + Math.floor(Math.random() * 26))
        return s
    }
    function randomPubKey() {
        const chars = "0123456789abcdef"
        let s = "0x"
        for (let i = 0; i < 8; ++i)
            s += chars[Math.floor(Math.random() * chars.length)]
        return s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12

        SplitView {
            orientation: Qt.Vertical

            Layout.fillWidth: true
            Layout.fillHeight: true

            ScrollView {
                id: scrollView

                SplitView.fillHeight: true
                SplitView.minimumHeight: 120

                contentWidth: availableWidth

                ChatTextArea {
                    id: textArea

                    background: null

                    font.pixelSize: 15
                    codeBackground: "#e8e8e8"
                    quoteBarVisible: quoteBarSwitch.checked

                    text:
`Some **bold** text there!
Some *italic* text text there!

Some in-line emoji: 😎🤪🎃

This is ~~strikethrough~~ text.

Both bold and italics goes here: ***bold italic***
And **bold** and *italic* together in a single line.

**multi-
line bold here**

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

**Links:**

Plain link: https://status.im
Bold link: **https://status.im/bold**
Star in URL (no italic): https://x.com/a*b*c
Link in code (not highlighted): \`https://status.im\`

**Unclosed code fence (toggle flag above to format):**

\`\`\`
unclosed fence here (no closing triple-tick)
**bold suppressed when format unclosed code fence flag on**
`
                }
            }

            ColumnLayout {
                SplitView.preferredHeight: 260
                SplitView.minimumHeight: 80

                spacing: 4

                Text {
                    Layout.fillWidth: true
                    font.bold: true
                    text: "AST dump:"
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    contentWidth: availableWidth

                    TextArea {
                        readOnly: true
                        wrapMode: TextEdit.NoWrap
                        font.family: "Monospace"
                        font.pixelSize: 13
                        text: MarkdownUtils.dumpAst(textArea.text,
                                                    textArea.formatUnclosedCodeFence,
                                                    rangesSwitch.checked)
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false

            Switch {
                text: "Format unclosed code fence"
                checked: textArea.formatUnclosedCodeFence
                onToggled: textArea.formatUnclosedCodeFence = checked
            }
            Switch {
                id: rangesSwitch

                text: "AST ranges"
                checked: true
            }
            Switch {
               id: quoteBarSwitch

               text: "Quote block vertical line"
               checked: true
            }
            Button {
                text: "Add random mention"
                onClicked: {
                    const pos = textArea.cursorPosition
                    textArea.insertMention(pos, root.randomName(), root.randomPubKey())
                    textArea.insert(textArea.cursorPosition, " ")
                }
            }
            Row {
                spacing: 16
                Text { text: "In unclosed code fence:" }
                Text {
                    text: {
                        textArea.text
                        return textArea.inUnclosedCodeFence(textArea.cursorPosition) ? "true" : "false"
                    }
                }
            }

            Row {
                spacing: 16
                Text { text: "cursor: " + textArea.cursorPosition }
                Text {
                    readonly property bool hasSelection:
                        textArea.selectionStart !== textArea.selectionEnd
                    text: hasSelection
                          ? "selection: [" + textArea.selectionStart + ", " + textArea.selectionEnd + ")"
                          : "selection: none"
                }
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

    Rectangle {
        anchors.fill: linksColumn
        border.color: "lightblue"

        MouseArea {
            anchors.fill: parent
        }
    }

    ColumnLayout {
        id: linksColumn

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.rightMargin: scrollView.ScrollBar.vertical.width + 12

        width: 300
        height: 400

        Text {
            Layout.fillWidth: true
            font.bold: true
            text: "detected links:"
        }

        ListView {
            id: linksListView

            Layout.leftMargin: 5

            Layout.fillWidth: true
            Layout.fillHeight: true

            model: textArea.linksModel

            delegate: Text {
                width: ListView.view.width
                text: model.text + " @ " + model.start + " +" + model.length

                elide: Text.ElideMiddle

                MouseArea {
                    id: linkMouseArea

                    hoverEnabled: true

                    anchors.fill: parent
                }

                Rectangle {
                    parent: textArea

                    z: -1

                    visible: linkMouseArea.containsMouse

                    readonly property rect position: {
                        textArea.text
                        textArea.contentWidth

                        const start = textArea.positionToRectangle(model.start)
                        const end = textArea.positionToRectangle(model.start + model.length)

                        const rect = Qt.rect(
                            start.x,
                            start.y,
                            end.x - start.x,
                            start.height
                        )

                        return rect
                    }

                    x: position.x
                    y: position.y
                    width: position.width
                    height: position.height

                    border.color: "darkblue"
                    color: "lightblue"
                }
            }
        }
    }
}

// category: Chat
// status: good
