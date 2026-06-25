import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Controls
import StatusQ.Internal

// Self-contained chat text input: a text area driving live, simplified-markdown
// syntax highlighting, with quote-block vertical bars and mention pills rendered on
// top, plus chat-specific key handling (triple-backtick fence completion and an
// undo/redo loop that absorbs format-only edit steps).
StatusTextArea {
    id: root

    // Toggles the quote-block vertical bar overlay.
    property bool quoteBarVisible: true

    property alias formatUnclosedCodeFence: highlighter.formatUnclosedCodeFence
    property alias codeBackground: highlighter.codeBackground

    readonly property alias linksModel: highlighter.linksModel
    readonly property alias mentionsModel: highlighter.mentionsModel

    function insertMention(pos, name, pubKey) {
        highlighter.insertMention(pos, name, pubKey)
    }
    function parseQuoteBlocks(text) {
        return highlighter.parseQuoteBlocks(text)
    }
    function emphasisAt(pos) {
        return highlighter.emphasisAt(pos)
    }
    function emphasisAtInsertion(pos) {
        return highlighter.emphasisAtInsertion(pos)
    }
    function inUnclosedCodeFence(pos) {
        return highlighter.inUnclosedCodeFence(pos)
    }

    wrapMode: TextEdit.Wrap

    ChatInputHighlighter {
        id: highlighter
        quickTextDocument: root.textDocument
        codeBackground: "#e8e8e8"
    }

    TextMetrics {
        id: gtMetrics
        font: root.font
        text: ">"
    }

    // Quote-block vertical bar; positions come from the markdown parser.
    Repeater {
        model: {
            if (!root.quoteBarVisible)
                return null

            root.formatUnclosedCodeFence // re-eval on toggle
            return highlighter.parseQuoteBlocks(root.text)
        }

        delegate: Rectangle {
            required property var modelData

            readonly property int startPosition: modelData.start
            readonly property int lastLinePosition:
                Math.max(modelData.start, modelData.end - 1)

            readonly property rect _startRect: {
                root.contentHeight; root.width // recompute on layout

                // clamp: positions may briefly outrun a just-shrunk document
                return root.positionToRectangle(Math.min(startPosition, root.length))
            }
            readonly property rect _lastRect: {
                root.contentHeight; root.width
                return root.positionToRectangle(Math.min(lastLinePosition, root.length))
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
                root.contentHeight; root.width // recompute on layout
                return root.positionToRectangle(Math.min(position, root.length))
            }
            readonly property real mentionWidth:
                root.positionToRectangle(Math.min(position + 1, root.length)).x - _r.x

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
                font.pixelSize: root.font.pixelSize - 2
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
                && root.selectionStart === root.selectionEnd
                && root.cursorPosition >= 2
                && root.getText(root.cursorPosition - 2,
                                root.cursorPosition) === "``") {
            event.accepted = true
            TextDocumentUtils.handleTripleBacktick(root.textDocument,
                                                   root.cursorPosition)
            return
        }

        // It's necessary to handle undo/redo in a loop in order to
        // handle formatting changes of text blocks, detected as changes
        // not changing the actual text (like indentation of quote blocks).
        if (event.matches(StandardKey.Undo)) {
            let text = ""
            event.accepted = true

            do {
                if (!root.canUndo)
                    return

                text = root.text
                root.undo()
            } while (text === root.text)

        } else if (event.matches(StandardKey.Redo)) {
            let text = ""
            event.accepted = true

            do {
                if (!root.canRedo)
                    return

                text = root.text
                root.redo()

            } while (text === root.text)
        }
    }
}
