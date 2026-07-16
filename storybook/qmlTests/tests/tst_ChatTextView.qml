import QtQuick
import QtTest

import StatusQ
import StatusQ.Components

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest

        ChatTextView {
            width: 400
            font.pixelSize: 15
        }
    }

    // An editable control that grabs keyboard focus before the ChatTextView selection —
    // mirrors the real chat where the composer holds focus. Without the ChatTextView taking
    // focus on selection, this field would preempt the Ctrl+C copy shortcut.
    TextEdit {
        id: otherEditor
        objectName: "otherEditor"
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 200
        height: 30
        text: "editable field"
    }

    SignalSpy {
        id: mentionSpy
        target: testCase.control
        signalName: "mentionClicked"
    }
    SignalSpy {
        id: linkSpy
        target: testCase.control
        signalName: "linkClicked"
    }

    TestCase {
        id: testCase
        name: "ChatTextView"
        when: windowShown

        property ChatTextView control: null

        // The suite runs with `-platform offscreen` (storybook/CMakeLists.txt), whose clipboard is
        // process-isolated (starts empty, never touches the real system clipboard), so the copy
        // tests below don't clobber the user's clipboard and need no save/restore.
        function init() {
            control = createTemporaryObject(componentUnderTest, root)
            verify(control)
        }

        // The `blocks` property drives the rendered content: a non-empty list produces
        // visible content (implicitHeight > 0), an empty list collapses it.
        function test_blocksDriveContent() {
            compare(control.blocks.length, 0)
            tryCompare(control, "implicitHeight", 0)

            control.blocks = [
                { type: "text", html: "hello" },
                { type: "code", code: "x = 1" },
                { type: "quote", blocks: [{ type: "text", html: "quoted" }] }
            ]
            tryVerify(() => control.implicitHeight > 0)

            const withBlocks = control.implicitHeight

            // Clearing the blocks collapses the content again.
            control.blocks = []
            tryCompare(control, "implicitHeight", 0)
            verify(withBlocks > 0)
        }

        // Recursively true when some rendered Text/TextEdit under `item` contains `substr`.
        function renders(item, substr) {
            if (typeof item.text === "string" && item.text.indexOf(substr) >= 0)
                return true
            const kids = item.children
            for (let i = 0; i < kids.length; ++i)
                if (renders(kids[i], substr))
                    return true
            return false
        }

        // The "(edited)" marker is rendered only when `edited` is set (appended after the text).
        function test_editedMarkerRendered() {
            control.blocks = [
                { type: "text", html: "first" },
                { type: "text", html: "hello" }
            ]
            tryVerify(() => control.implicitHeight > 0)
            verify(!renders(control, "(edited)"), "marker shown without edited")

            control.edited = true
            tryVerify(() => renders(control, "(edited)"), 1000, "marker not rendered when edited")

            control.edited = false
            tryVerify(() => !renders(control, "(edited)"), 1000, "marker not removed")
        }

        // When the last block isn't text (code/quote), the marker is still rendered (as its own
        // trailing text block).
        function test_editedMarkerAfterNonTextBlock() {
            control.blocks = [
                { type: "text", html: "hello" },
                { type: "code", code: "x = 1" }
            ]
            control.edited = true
            tryVerify(() => control.implicitHeight > 0)
            tryVerify(() => renders(control, "(edited)"), 1000, "marker not rendered after code block")
        }

        // A quote block carrying a nested code sub-block renders without errors.
        function test_quoteWithNestedCode() {
            control.blocks = [
                { type: "quote", blocks: [
                    { type: "text", html: "intro" },
                    { type: "code", code: "nested" }
                ] }
            ]
            tryVerify(() => control.implicitHeight > 0)
        }

        // ── mouse selection (selectable mode) ────────────────────────────────────

        // Without `selectable`, blocks are plain Labels — a drag selects nothing.
        function test_notSelectable_noSelection() {
            control.blocks = [
                { type: "text", html: "first line" },
                { type: "text", html: "second line" }
            ]
            tryVerify(() => control.implicitHeight > 0)

            mousePress(control, 4, 4)
            mouseMove(control, control.width - 4, control.implicitHeight - 4)
            mouseRelease(control, control.width - 4, control.implicitHeight - 4)

            compare(control.selectedText, "")
        }

        // With `selectable`, dragging from the first block into the second selects across
        // both — the combined selectedText contains text from each.
        function test_crossBlockSelection() {
            control.selectable = true
            control.blocks = [
                { type: "text", html: "first line" },
                { type: "text", html: "second line" }
            ]
            tryVerify(() => control.implicitHeight > 0)

            // Press at x=0 so the anchor is the very start of the first block (positionAt(0)
            // is reliably position 0, independent of glyph widths).
            mousePress(control, 0, 3)
            mouseMove(control, control.width - 4, control.implicitHeight - 4)
            mouseRelease(control, control.width - 4, control.implicitHeight - 4)

            verify(control.selectedText.indexOf("first") >= 0, "first block not selected")
            verify(control.selectedText.indexOf("second") >= 0, "second block not selected")
        }

        // Double-click selects the word under the cursor (not the whole line).
        function test_doubleClickSelectsWord() {
            control.selectable = true
            control.blocks = [{ type: "text", html: "hello world" }]
            tryVerify(() => control.implicitHeight > 0)

            mouseClick(control, 2, 3)
            mouseClick(control, 2, 3)

            compare(control.selectedText, "hello")
        }

        // Triple-click selects the whole (logical) line — here the first line of a two-line text
        // block, not the entire block ("aaabbb").
        function test_tripleClickSelectsLine() {
            control.selectable = true
            control.blocks = [{ type: "text", html: "aaa<br/>bbb" }]
            tryVerify(() => control.implicitHeight > 0)

            mouseClick(control, 2, 3)
            mouseClick(control, 2, 3)
            mouseClick(control, 2, 3)

            compare(control.selectedText, "aaa")
        }

        // Triple-click on a single-line block selects the entire line.
        function test_tripleClickSelectsFullSingleLine() {
            control.selectable = true
            control.blocks = [{ type: "text", html: "hello world foo" }]
            tryVerify(() => control.implicitHeight > 0)

            mouseClick(control, 2, 3)
            mouseClick(control, 2, 3)
            mouseClick(control, 2, 3)

            compare(control.selectedText, "hello world foo")
        }

        // Clicking in place cycles: click, word, line, then a fourth click deselects.
        function test_fourthClickDeselects() {
            control.selectable = true
            control.blocks = [{ type: "text", html: "hello world" }]
            tryVerify(() => control.implicitHeight > 0)

            mouseClick(control, 2, 3) // plain click
            mouseClick(control, 2, 3) // word
            verify(control.selectedText.length > 0, "second click should select a word")
            mouseClick(control, 2, 3) // line
            verify(control.selectedText.length > 0, "third click should select the line")
            mouseClick(control, 2, 3) // deselect
            compare(control.selectedText, "", "fourth click should deselect")
        }

        // Loosing focus clears the selection.
        function test_clickingAnotherViewDeselectsPrevious() {
            const blocks = [
                { type: "text", html: "first line" },
                { type: "text", html: "second line" }
            ]
            const first = createTemporaryObject(componentUnderTest, root,
                                                { selectable: true, blocks: blocks, y: 0 })
            const second = createTemporaryObject(componentUnderTest, root,
                                                 { selectable: true, blocks: blocks, y: 200 })
            verify(first && second)
            tryVerify(() => first.implicitHeight > 0 && second.implicitHeight > 0)

            // Select in the first view.
            mousePress(first, 0, 3)
            mouseMove(first, first.width - 4, first.implicitHeight - 4)
            mouseRelease(first, first.width - 4, first.implicitHeight - 4)
            verify(first.selectedText.length > 0, "first view not selected")

            // A plain click (no drag) in the second view must clear the first's selection.
            mousePress(second, 5, 3)
            mouseRelease(second, 5, 3)
            compare(second.selectedText, "", "click should not select the second view")

            tryCompare(first, "selectedText", "")
        }

        // Toggling `selectable` after blocks are set rebuilds each block's renderer (Loader
        // swap) and the coordinator re-collects the newly-created editors.
        function test_selectableToggledAfterBlocks() {
            control.selectable = false
            control.blocks = [
                { type: "text", html: "first line" },
                { type: "text", html: "second line" }
            ]
            tryVerify(() => control.implicitHeight > 0)

            control.selectable = true
            Qt.callLater(() => {}) // let the Loaders swap in

            mousePress(control, 0, 3)
            mouseMove(control, control.width - 4, control.implicitHeight - 4)
            mouseRelease(control, control.width - 4, control.implicitHeight - 4)

            verify(control.selectedText.indexOf("first") >= 0, "first block not selected")
            verify(control.selectedText.indexOf("second") >= 0, "second block not selected")
        }

        // Hovering a link/mention rebuilds a selectable block's rich-text document (the hover
        // background is baked into the HTML via richTextFor), which clears that editor's
        // selection. The coordinator must restore it. Here we trigger the same document rebuild
        // deterministically by changing a richTextFor input (linkColor) and assert the active
        // cross-block selection survives.
        function test_selectionSurvivesTextRebuild() {
            control.selectable = true
            control.blocks = [
                { type: "text", html: "first line" },
                { type: "text", html: "second line" }
            ]
            tryVerify(() => control.implicitHeight > 0)

            mousePress(control, 0, 3)
            mouseMove(control, control.width - 4, control.implicitHeight - 4)
            mouseRelease(control, control.width - 4, control.implicitHeight - 4)

            verify(control.selectedText.indexOf("first") >= 0, "first block not selected")
            verify(control.selectedText.indexOf("second") >= 0, "second block not selected")

            const screenshot = grabImage(control)

            // Rebuild the rich-text documents (as a hover would) and confirm
            // the selection is restored rather than dropped.
            control.linkColor = "#123456"
            verify(control.selectedText.indexOf("first") >= 0,
                   "selection lost on text rebuild (first)")
            verify(control.selectedText.indexOf("second") >= 0,
                   "selection lost on text rebuild (second)")

            const screenshot2 = grabImage(control)
            verify(screenshot.equals(screenshot2))
        }

        function test_selectionNotSurvivesTextReset() {
            control.selectable = true
            control.blocks = [
                { type: "text", html: "first line" },
                { type: "text", html: "second line" }
            ]
            tryVerify(() => control.implicitHeight > 0)

            mousePress(control, 0, 3)
            mouseMove(control, control.width - 4, control.implicitHeight - 4)
            mouseRelease(control, control.width - 4, control.implicitHeight - 4)

            verify(control.selectedText.indexOf("first") >= 0, "first block not selected")
            verify(control.selectedText.indexOf("second") >= 0, "second block not selected")

            const screenshot = grabImage(control)

            control.blocks = [
                { type: "text", html: "first line2" },
                { type: "text", html: "second line" }
            ]

            control.blocks = [
                { type: "text", html: "first line" },
                { type: "text", html: "second line" }
            ]

            verify(control.selectedText.indexOf("first") === -1,
                   "selection survived text reset (first)")
            verify(control.selectedText.indexOf("second") === -1,
                   "selection survived text reset (second)")

            const screenshot2 = grabImage(control)
            verify(!screenshot.equals(screenshot2))
        }

        // copySelection() puts the combined selection on the clipboard.
        function test_copySelection() {
            control.selectable = true
            control.blocks = [
                { type: "text", html: "alpha" },
                { type: "text", html: "beta" }
            ]
            tryVerify(() => control.implicitHeight > 0)

            mousePress(control, 0, 3)
            mouseMove(control, control.width - 4, control.implicitHeight - 4)
            mouseRelease(control, control.width - 4, control.implicitHeight - 4)
            verify(control.selectedText.length > 0)

            control.copySelection()
            compare(ClipboardUtils.text, control.selectedText)
        }

        // Ctrl+C copies the selection even when another editable control held keyboard focus
        // first. Selecting in the ChatTextView must move focus to it (onSelectedTextChanged:
        // forceActiveFocus), so the previously-focused editor no longer preempts the window
        // Copy shortcut.
        function test_ctrlCCopiesWhenAnotherEditorHadFocus() {
            control.selectable = true
            control.blocks = [
                { type: "text", html: "alpha" },
                { type: "text", html: "beta" }
            ]
            tryVerify(() => control.implicitHeight > 0)

            // Known, different clipboard value so a successful copy is unambiguous.
            ClipboardUtils.setText("sentinel-not-copied")

            // Another editable control takes keyboard focus first.
            otherEditor.forceActiveFocus()
            verify(otherEditor.activeFocus, "other editor did not take focus")

            // Select across both blocks.
            mousePress(control, 0, 3)
            mouseMove(control, control.width - 4, control.implicitHeight - 4)
            mouseRelease(control, control.width - 4, control.implicitHeight - 4)
            verify(control.selectedText.length > 0, "nothing selected")

            // Selecting moved focus off the other editor onto the ChatTextView.
            verify(control.activeFocus, "ChatTextView did not take focus on selection")
            verify(!otherEditor.activeFocus, "focus not moved away from the other editor")

            // Ctrl+C copies the ChatTextView selection (not the other editor's content).
            keySequence(StandardKey.Copy)
            tryCompare(ClipboardUtils, "text", control.selectedText)
        }

        // ── link / mention click signals ─────────────────────────────────────────

        // Non-selectable (Label): clicking a mention <a> emits mentionClicked(pubKey).
        function test_mentionClicked_nonSelectable() {
            control.selectable = false
            control.blocks = [{ type: "text", html: '<a href="0xabc">@alice</a>' }]
            tryVerify(() => control.implicitHeight > 0)

            mentionSpy.clear()
            mouseClick(control, 10, 5)
            compare(mentionSpy.count, 1)
            compare(mentionSpy.signalArguments[0][0], "0xabc")
        }

        // Non-selectable: clicking a URL <a> emits linkClicked(url).
        function test_linkClicked_nonSelectable() {
            control.selectable = false
            control.blocks = [{ type: "text", html: '<a href="https://status.im">https://status.im</a>' }]
            tryVerify(() => control.implicitHeight > 0)

            linkSpy.clear()
            mouseClick(control, 10, 5)
            compare(linkSpy.count, 1)
            compare(linkSpy.signalArguments[0][0], "https://status.im")
        }

        // Selectable (TextEdit under the overlay): a click — not a drag — still routes the link.
        function test_mentionClicked_selectable() {
            control.selectable = true
            control.blocks = [{ type: "text", html: '<a href="0xabc">@alice</a>' }]
            tryVerify(() => control.implicitHeight > 0)

            mentionSpy.clear()
            mousePress(control, 10, 5)
            mouseRelease(control, 10, 5)
            compare(mentionSpy.count, 1)
            compare(mentionSpy.signalArguments[0][0], "0xabc")
        }

        // A drag (selection) must NOT be treated as a link click.
        function test_dragDoesNotClickLink() {
            control.selectable = true
            control.blocks = [{ type: "text", html: '<a href="0xabc">@alice</a>' }]
            tryVerify(() => control.implicitHeight > 0)

            mentionSpy.clear()
            mousePress(control, 2, 5)
            mouseMove(control, control.width - 4, 5)
            mouseRelease(control, control.width - 4, 5)
            compare(mentionSpy.count, 0)
        }
    }
}
