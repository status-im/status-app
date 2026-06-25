import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ
import StatusQ.Controls
import StatusQ.Internal

Item {
    id: root

    ChatInputHighlighter {
        id: highlighter
        quickTextDocument: textArea.textDocument
        codeBackground: "#e8e8e8"
    }

    readonly property var emph: highlighter.emphasisAt(textArea.cursorPosition)
    readonly property var vemph: highlighter.emphasisAtInsertion(textArea.cursorPosition)

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

                StatusTextArea {
                    id: textArea

                    background: null

                    wrapMode: TextEdit.Wrap
                    font.pixelSize: 15
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

                    TextMetrics {
                        id: gtMetrics
                        font: textArea.font
                        text: ">"
                    }

                    // Quote-block vertical bar; positions come from the markdown parser.
                    Repeater {
                        model: {
                            if (!quoteBarSwitch.checked)
                                return null

                            highlighter.formatUnclosedCodeFence // re-eval on toggle
                            return highlighter.parseQuoteBlocks(textArea.text)
                        }

                        delegate: Rectangle {
                            required property var modelData

                            readonly property int startPosition: modelData.start
                            readonly property int lastLinePosition:
                                Math.max(modelData.start, modelData.end - 1)

                            readonly property rect _startRect: {
                                textArea.contentHeight; textArea.width // recompute on layout

                                // clamp: positions may briefly outrun a just-shrunk document
                                return textArea.positionToRectangle(Math.min(startPosition, textArea.length))
                            }
                            readonly property rect _lastRect: {
                                textArea.contentHeight; textArea.width
                                return textArea.positionToRectangle(Math.min(lastLinePosition, textArea.length))
                            }

                            x: _startRect.x
                            y: _startRect.y
                            width: gtMetrics.advanceWidth
                            height: _lastRect.y + _lastRect.height - _startRect.y
                            color: "white"

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 3
                                anchors.rightMargin: 3
                                color: "#4A90D9"
                            }
                        }
                    }

                    // Mention pills, rendered on top of the embedded objects.
                    Repeater {
                        model: highlighter.mentionsModel

                        delegate: Rectangle {
                            required property int position
                            required property string name
                            required property string pubKey

                            readonly property rect _r: {
                                textArea.contentHeight; textArea.width // recompute on layout
                                return textArea.positionToRectangle(Math.min(position, textArea.length))
                            }
                            readonly property real mentionWidth:
                                textArea.positionToRectangle(Math.min(position + 1, textArea.length)).x - _r.x

                            x: _r.x
                            y: _r.y + 1
                            // Math.min so a mention occupying the whole line doesn't overflow
                            width: Math.min(mentionWidth, parent.width - x)
                            height: _r.height - 2
                            radius: 3//height / 4
                            color: "#DD5B8DEF"

                            Text {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: parent.name
                                color: "white"
                                elide: Text.ElideRight
                                font.pixelSize: textArea.font.pixelSize - 2
                            }

                            ToolTip.visible: hover.hovered
                            ToolTip.text: "pub key: " + pubKey
                            HoverHandler { id: hover }
                        }
                    }

                    Keys.onPressed: (event) => {
                        // Intercept the 3rd backtick typed right after "``" and perform
                        // the "``" -> "```" replacement ourselves, as a single joinable
                        // edit block (see TextDocumentUtils.handleTripleBacktick).
                        if (event.key === Qt.Key_QuoteLeft
                                && textArea.selectionStart === textArea.selectionEnd
                                && textArea.cursorPosition >= 2
                                && textArea.getText(textArea.cursorPosition - 2,
                                                    textArea.cursorPosition) === "``") {
                            event.accepted = true
                            TextDocumentUtils.handleTripleBacktick(textArea.textDocument,
                                                                   textArea.cursorPosition)
                            return
                        }

                        // It's necessary to handle undo/redo in a loop in order to
                        // handle formatting changes of text blocks, detected as changes
                        // not changing the actual text (like indentation of quote blocks).
                        if (event.matches(StandardKey.Undo)) {
                            let text = ""
                            event.accepted = true

                            do {
                                if (!canUndo)
                                    return

                                text = textArea.text
                                undo()
                            } while (text === textArea.text)

                        } else if (event.matches(StandardKey.Redo)) {
                            let text = ""
                            event.accepted = true

                            do {
                                if (!canRedo)
                                    return

                                text = textArea.text
                                redo()

                            } while (text === textArea.text)
                        }
                    }
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
                                                    highlighter.formatUnclosedCodeFence,
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
                checked: highlighter.formatUnclosedCodeFence
                onToggled: highlighter.formatUnclosedCodeFence = checked
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
                    highlighter.insertMention(pos, root.randomName(), root.randomPubKey())
                    textArea.insert(textArea.cursorPosition, " ")
                }
            }
            Row {
                spacing: 16
                Text { text: "In unclosed code fence:" }
                Text {
                    text: {
                        textArea.text
                        return highlighter.inUnclosedCodeFence(textArea.cursorPosition) ? "true" : "false"
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

            model: highlighter.linksModel

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
