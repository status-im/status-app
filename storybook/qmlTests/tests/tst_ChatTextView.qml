import QtQuick
import QtTest

import StatusQ

import shared.status

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
