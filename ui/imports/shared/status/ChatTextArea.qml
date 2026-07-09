import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Controls
import StatusQ.Core.Theme
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
    property alias enlargeEmojis: highlighter.enlargeEmojis
    property alias codeBackground: highlighter.codeBackground
    property alias delimiterColor: highlighter.delimiterColor
    property alias linkColor: highlighter.linkColor

    // Background color needed for proper rendering of quote block's vertical line.
    property color backgroundColor: Theme.palette.background

    readonly property alias linksModel: highlighter.linksModel
    readonly property alias mentionsModel: highlighter.mentionsModel

    // True when the caret is in the middle of typing a mention: an "@" at line/text start
    // or right after whitespace, followed only by non-whitespace up to the caret, and not
    // inside a code span/block.
    readonly property bool enteringSuggestion: d.mentionContext.entering

    // The partial name typed after that "@" (up to the caret); "" when not entering a
    // suggestion.
    readonly property string mentionsFilter: d.mentionContext.filter

    // True when the caret is in the middle of typing an emoji shortcode: a ":" at line/text
    // start or right after whitespace, followed by at least two token chars ([a-zA-Z0-9_]) up
    // to the caret, and not inside a code span/block.
    readonly property bool enteringEmoji: d.emojiContext.entering

    // The partial shortcode typed after that ":" (up to the caret); "" when not entering one.
    readonly property string emojiFilter: d.emojiContext.filter

    function insertMention(pos, name, pubKey) {
        highlighter.insertMention(pos, name, pubKey)
    }
    // Returns the content as plain text with mention pills as their "@"+pubKey wire form.
    // (Named to avoid shadowing TextArea's built-in getText(start, end).)
    function textWithMentions() {
        return highlighter.textWithMentions()
    }
    // Loads `text`, converting textual mentions ("@0x…", "@0x00001") into pills. `names` maps
    // pubKey → display name.
    function loadText(text, names) {
        highlighter.setTextWithMentions(text, names || ({}))
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

    // Keep the caret out of the "> " quote prefix so it feels atomic. Self-terminating:
    // re-firing with an already-snapped position is a no-op.
    onCursorPositionChanged: {
        if (root.selectionStart === root.selectionEnd) {
            const snapped = highlighter.snapToQuoteContent(root.cursorPosition)
            if (snapped !== root.cursorPosition)
                root.cursorPosition = snapped
        }
    }

    ChatInputHighlighter {
        id: highlighter

        quickTextDocument: root.textDocument
        delimiterColor: Theme.palette.baseColor1
        linkColor: Theme.palette.primaryColor1
    }

    QtObject {
        id: d

        // {entering, filter} for the mention being typed at the caret. Recomputed on text
        // or caret changes; isInsideCode reuses the highlighter's cached AST.
        readonly property var mentionContext: {
            root.text
            root.cursorPosition
            return d.computeMentionContext()
        }

        function computeMentionContext() {
            const text = root.text
            const cursor = root.cursorPosition
            const none = { entering: false, filter: "" }

            // Walk back from the caret: only non-whitespace may precede it, and we must
            // reach an "@". Whitespace before any "@" means no mention in progress.
            let at = -1
            for (let i = cursor; i > 0; --i) {
                const ch = text.charAt(i - 1)
                if (ch === "@") { at = i - 1; break }
                if (/\s/.test(ch)) return none
            }
            if (at < 0)
                return none

            // The "@" must start a token: at text/line start, or right after whitespace.
            if (at > 0 && !/\s/.test(text.charAt(at - 1)))
                return none

            // Mentions are not allowed inside code spans/blocks.
            if (highlighter.isInsideCode(at))
                return none

            return { entering: true, filter: text.substring(at + 1, cursor) }
        }

        // {entering, filter} for the emoji shortcode being typed at the caret. Recomputed on
        // text or caret changes; isInsideCode reuses the highlighter's cached AST.
        readonly property var emojiContext: {
            root.text
            root.cursorPosition
            return d.computeEmojiContext()
        }

        function computeEmojiContext() {
            const text = root.text
            const cursor = root.cursorPosition
            const none = { entering: false, filter: "" }

            // Walk back from the caret: only shortcode chars ([a-zA-Z0-9_]) may precede it, and
            // we must reach a ":". Any other char before a ":" means no emoji in progress.
            let colon = -1
            for (let i = cursor; i > 0; --i) {
                const ch = text.charAt(i - 1)
                if (ch === ":") { colon = i - 1; break }
                if (!/[a-zA-Z0-9_]/.test(ch)) return none
            }
            if (colon < 0)
                return none

            // The ":" must start a token: at text/line start, or right after whitespace.
            if (colon > 0 && !/\s/.test(text.charAt(colon - 1)))
                return none

            // Emoji shortcodes are not allowed inside code spans/blocks.
            if (highlighter.isInsideCode(colon))
                return none

            const filter = text.substring(colon + 1, cursor)

            // Trigger only after at least two shortcode chars have been typed.
            if (filter.length < 2)
                return none

            return { entering: true, filter: filter }
        }
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

        delegate: ChatTextAreaQuoteBar {
            required property var modelData

            readonly property int lastLinePosition:
                Math.max(startPosition, endPosition - 1)

            // The quote group's document range (a ChatInputHighlighter.parseQuoteBlocks
            // entry's start/end).
            readonly property int startPosition: modelData.start
            readonly property int endPosition: modelData.end

            readonly property rect startRect: {
                root.leftPadding; root.topPadding // recompute on layout change
                root.contentHeight; root.width

                // clamp: positions may briefly outrun a just-shrunk document
                return root.positionToRectangle(Math.min(startPosition, root.length))
            }
            readonly property rect lastRect: {
                root.leftPadding; root.topPadding // recompute on layout change
                root.contentHeight; root.width
                return root.positionToRectangle(Math.min(lastLinePosition, root.length))
            }

            x: startRect.x
            y: startRect.y

            // Width of the bar's cell (the "> " prefix advance width).
            width: gtMetrics.advanceWidth
            height: lastRect.y + lastRect.height - startRect.y

            backgroundColor: root.backgroundColor
            barColor: Theme.palette.baseColor1
        }
    }

    // Mention pills, rendered on top of the embedded objects.
    Repeater {
        model: highlighter.mentionsModel

        delegate: ChatTextAreaMentionPill {
            readonly property int position: model.position

            readonly property rect _r: {
                root.leftPadding; root.topPadding // recompute on layout change
                root.contentHeight; root.width
                return root.positionToRectangle(Math.min(position, root.length))
            }
            readonly property real mentionWidth:
                root.positionToRectangle(
                    Math.min(position + 1, root.length)).x - _r.x

            x: _r.x
            y: _r.y + 1

            // Math.min so a mention occupying the whole line doesn't overflow
            width: Math.min(mentionWidth, root.width - x)
            height: _r.height - 2

            name: model.name
            pubKey: model.pubKey

            font.family: root.font.family
            font.pixelSize: root.font.pixelSize - 2
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

        // Custom copy/paste so mentions survive round-trips inside the editor (via a private
        // clipboard MIME) and collapse to their name text when pasted into other apps.
        if (event.matches(StandardKey.Copy)
                && root.selectionStart !== root.selectionEnd) {
            event.accepted = true
            highlighter.copySelectionToClipboard(root.selectionStart, root.selectionEnd)
            return
        }
        if (event.matches(StandardKey.Cut)
                && root.selectionStart !== root.selectionEnd) {
            event.accepted = true
            highlighter.copySelectionToClipboard(root.selectionStart, root.selectionEnd)
            // deleteRange (not root.remove) so a reactive mention demotion folds into one
            // undo step, matching the mention-aware deletion below.
            TextDocumentUtils.deleteRange(root.textDocument,
                                          root.selectionStart, root.selectionEnd)
            return
        }
        if (event.matches(StandardKey.Paste)) {
            event.accepted = true
            highlighter.pasteFromClipboard(root.selectionStart, root.selectionEnd,
                                           root.cursorPosition)
            return
        }

        // Quote-block continuation and atomic "> " editing. These mirror the
        // ChatInputMentions UX: Enter/Shift+Enter inside a quote start a new "> " line (two
        // on an empty quote line exit), a single Backspace at the start of quote content removes
        // the whole "> " prefix, Delete at a line end before a quote joins the lines, and Left at
        // content-start jumps to the previous line.
        const noShift = !(event.modifiers & Qt.ShiftModifier)
        const noSelection = root.selectionStart === root.selectionEnd

        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && highlighter.isInQuoteBlock(root.cursorPosition)) {
            event.accepted = true
            const prevPos = highlighter.endOfPreviousBlock(root.cursorPosition)
            if (prevPos !== root.cursorPosition
                    && highlighter.isEmptyQuoteBlock(root.cursorPosition)
                    && highlighter.isEmptyQuoteBlock(prevPos)) {
                // Two consecutive empty quote lines — drop them to exit the quote.
                // prevPos sits at offset 2 of the previous empty line, so prevPos - 2
                // is that line's start.
                root.remove(prevPos - 2, root.cursorPosition)
            } else {
                root.insert(root.cursorPosition, "\n> ")
            }
            return
        }

        // Outside a quote, Shift+Enter must also behave like Enter: insert a real newline (a new
        // block) instead of QQuickTextEdit's default soft line separator (U+2028), which stays
        // inside the current block and breaks the one-line-per-block model the parser and the
        // quote-bar overlay rely on. (insert() turns "\n" into a block separator.)
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true
            if (!noSelection)
                root.remove(root.selectionStart, root.selectionEnd)
            root.insert(root.cursorPosition, "\n")
            return
        }

        if (event.key === Qt.Key_Backspace && noSelection
                && highlighter.isQuoteContentStart(root.cursorPosition)) {
            event.accepted = true
            root.remove(root.cursorPosition - 2, root.cursorPosition)
            return
        }

        if (event.key === Qt.Key_Delete && noSelection
                && highlighter.isLineEndBeforeQuoteBlock(root.cursorPosition)) {
            // Empty line: remove only the paragraph separator (the caret snap lands
            // it after "> "). Non-empty line: also drop the "> " so content joins.
            const count = highlighter.isBlockEmpty(root.cursorPosition) ? 1 : 3
            event.accepted = true
            root.remove(root.cursorPosition, root.cursorPosition + count)
            return
        }

        if (event.key === Qt.Key_Left && noShift
                && highlighter.isQuoteContentStart(root.cursorPosition)) {
            event.accepted = true
            root.cursorPosition = highlighter.endOfPreviousBlock(root.cursorPosition)
            return
        }

        // A deletion can move a mention into code (and trigger a demotion) only when it
        // removes a backtick or a mention. In that case perform it ourselves as a raw,
        // joinable edit so the reactive demotion folds into the same undo command (same
        // idea as handleTripleBacktick). Plain Backspace/Delete only; word-delete
        // (Ctrl/Alt) and unrelated deletions fall through to native handling.
        if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)
                && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            let from = -1, to = -1
            if (root.selectionStart !== root.selectionEnd) {
                from = root.selectionStart
                to = root.selectionEnd
            } else if (event.key === Qt.Key_Backspace && root.cursorPosition > 0) {
                from = root.cursorPosition - 1
                to = root.cursorPosition
            } else if (event.key === Qt.Key_Delete && root.cursorPosition < root.length) {
                from = root.cursorPosition
                to = root.cursorPosition + 1
            }

            if (from >= 0) {
                const removed = root.getText(from, to)
                const objectChar = String.fromCharCode(0xFFFC)
                if (removed.indexOf("`") >= 0 || removed.indexOf(objectChar) >= 0) {
                    event.accepted = true
                    TextDocumentUtils.deleteRange(root.textDocument, from, to)
                    return
                }
            }
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
