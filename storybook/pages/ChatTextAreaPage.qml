import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ
import StatusQ.Core.Theme

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

            // Input (left) and static HTML render (right), side by side, 50% each.
            RowLayout {
                SplitView.fillHeight: true
                SplitView.minimumHeight: 160

                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1

                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        font.bold: true
                        text: "Input:"
                    }

                    ScrollView {
                        id: scrollView

                        Layout.fillWidth: true
                        Layout.fillHeight: true

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

Quote with nested code:
> A quote block here
> second quoted line
> \`\`\`
> code nested in the quote
> \`\`\`

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
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1

                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        font.bold: true
                        text: "Static HTML render:"
                    }

                    ScrollView {
                        id: htmlScroll

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        contentWidth: availableWidth

                        padding: 10

                        // One Label per block, so quote/code blocks can be decorated.
                        Column {
                            id: blocksColumn

                            width: htmlScroll.availableWidth
                            spacing: 8

                            Repeater {
                                model: {
                                    textArea.text // re-build on every edit
                                    return MarkdownUtils.toBlocks(textArea.textDocument,
                                                                  textArea.formatUnclosedCodeFence)
                                }

                                // Visibility-based (no Loader) to avoid Loader height binding
                                // loops; each delegate sizes to its visible child's content.
                                delegate: Item {
                                    id: blk

                                    required property var modelData
                                    readonly property var block: modelData

                                    width: blocksColumn.width
                                    implicitHeight: block.type === "quote" ? quoteRow.implicitHeight
                                                  : block.type === "code"  ? codeBox.implicitHeight
                                                                           : textLabel.implicitHeight
                                    height: implicitHeight

                                    Label {
                                        id: textLabel
                                        visible: blk.block.type === "text"
                                        width: parent.width
                                        wrapMode: Text.Wrap
                                        textFormat: Text.RichText
                                        font.family: Fonts.baseFont.family
                                        font.pixelSize: textArea.font.pixelSize
                                        // pre-wrap so extra/leading spaces are preserved
                                        text: visible ? "<span style=\"white-space:pre-wrap\">"
                                                        + blk.block.html + "</span>" : ""
                                    }

                                    Rectangle {
                                        id: codeBox
                                        visible: blk.block.type === "code"
                                        width: codeLabel.width + 16
                                        implicitHeight: codeLabel.implicitHeight + 16
                                        radius: 6
                                        border.width: 1
                                        border.color: "#cccccc"
                                        color: "#e8e8e8"
                                    }

                                    Label {
                                        id: codeLabel
                                        x: 8; y: 8
                                        width: Math.min(implicitWidth, parent.width - 16)
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                        font.family: Fonts.codeFont.family
                                        font.pixelSize: textArea.font.pixelSize
                                        font.bold: !!blk.block.bold
                                        font.italic: !!blk.block.italic
                                        font.strikeout: !!blk.block.strikethrough
                                        text: codeBox.visible ? blk.block.code : ""
                                    }

                                    Row {
                                        id: quoteRow
                                        visible: blk.block.type === "quote"
                                        width: parent.width
                                        spacing: 8

                                        Rectangle {
                                            width: 3
                                            height: quoteCol.height
                                            color: "#4A90D9"

                                            bottomLeftRadius: 3
                                            topLeftRadius: 3
                                        }
                                        Column {
                                            id: quoteCol
                                            width: parent.width - 11 // bar (3) + spacing (8)
                                            spacing: 8

                                            Repeater {
                                                model: quoteRow.visible ? blk.block.blocks : []

                                                delegate: Item {
                                                    id: sub

                                                    required property var modelData
                                                    readonly property var block: modelData

                                                    width: quoteCol.width
                                                    implicitHeight: block.type === "code"
                                                                    ? subCode.implicitHeight
                                                                    : subText.implicitHeight
                                                    height: implicitHeight

                                                    Label {
                                                        id: subText
                                                        visible: sub.block.type !== "code"
                                                        width: parent.width
                                                        wrapMode: Text.Wrap
                                                        textFormat: Text.RichText
                                                        font.family: Fonts.baseFont.family
                                                        font.pixelSize: textArea.font.pixelSize
                                                        // pre-wrap preserves extra/leading spaces
                                                        text: visible ? "<span style=\"white-space:pre-wrap\">"
                                                                        + sub.block.html + "</span>" : ""
                                                    }
                                                    Rectangle {
                                                        id: subCode
                                                        visible: sub.block.type === "code"
                                                        width: subCodeLabel.width + 16
                                                        implicitHeight: subCodeLabel.implicitHeight + 16
                                                        radius: 6
                                                        border.width: 1
                                                        border.color: "#cccccc"
                                                        color: "#e8e8e8"
                                                    }

                                                    Label {
                                                        id: subCodeLabel
                                                        x: 8; y: 8
                                                        width: Math.min(implicitWidth, parent.width - 16)
                                                        wrapMode: Text.Wrap
                                                        textFormat: Text.PlainText
                                                        font.family: Fonts.codeFont.family
                                                        font.pixelSize: textArea.font.pixelSize
                                                        font.bold: !!sub.block.bold
                                                        font.italic: !!sub.block.italic
                                                        font.strikeout: !!sub.block.strikethrough
                                                        text: subCode.visible ? sub.block.code : ""
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                SplitView.preferredHeight: 200
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
                        font.family: Fonts.codeFont.family
                        font.pixelSize: 13
                        text: MarkdownUtils.dumpAst(textArea.text,
                                                    textArea.formatUnclosedCodeFence,
                                                    rangesSwitch.checked)
                    }
                }
            }

            ColumnLayout {
                SplitView.preferredHeight: 160
                SplitView.minimumHeight: 80

                spacing: 4

                Text {
                    Layout.fillWidth: true
                    font.bold: true
                    text: "detected links:"
                }

                ListView {
                    id: linksListView

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
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
            Switch {
                text: "Enlarge emojis"
                checked: textArea.enlargeEmojis
                onToggled: textArea.enlargeEmojis = checked
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
}

// category: Chat
// status: good
