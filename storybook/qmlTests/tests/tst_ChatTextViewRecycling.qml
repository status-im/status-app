import QtQuick
import QtTest

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

    TestCase {
        id: testCase
        name: "ChatTextViewRecycling"
        when: windowShown

        property ChatTextView control: null

        function init() {
            control = createTemporaryObject(componentUnderTest, root)
            verify(control)
        }

        // Recursively collects the leaf text renderers (Text/TextEdit/Label) under `item`,
        // in document order — the items whose identity block recycling must preserve.
        function collectTextItems(item) {
            const out = []
            const walk = (it) => {
                if (typeof it.text === "string")
                    out.push(it)
                const kids = it.children
                for (let i = 0; i < kids.length; ++i)
                    walk(kids[i])
            }
            walk(item)
            return out
        }

        // True when some rendered text item under `item` contains `substr`.
        function renders(item, substr) {
            const items = collectTextItems(item)
            for (let i = 0; i < items.length; ++i)
                if (items[i].text.indexOf(substr) >= 0)
                    return true
            return false
        }

        // ── identity preservation (the fast path) ────────────────────────────────

        // Rebinding paragraph→paragraph (different text) keeps the same rendered item
        // instance and shows the new text.
        function test_paragraphRebindKeepsInstance() {
            control.blocks = [{ type: "text", html: "hello" }]
            tryVerify(() => control.implicitHeight > 0)

            const before = collectTextItems(control)
            compare(before.length, 1)
            verify(renders(control, "hello"))

            control.blocks = [{ type: "text", html: "world" }]

            const after = collectTextItems(control)
            compare(after.length, 1)
            verify(after[0] === before[0], "paragraph item was recreated instead of recycled")
            verify(renders(control, "world"), "new text not shown")
            verify(!renders(control, "hello"), "old text still shown")
        }

        // Same fast path in selectable mode (TextEdit renderers).
        function test_paragraphRebindKeepsInstance_selectable() {
            control.selectable = true
            control.blocks = [{ type: "text", html: "hello" }]
            tryVerify(() => control.implicitHeight > 0)

            const before = collectTextItems(control)
            compare(before.length, 1)

            control.blocks = [{ type: "text", html: "world" }]

            const after = collectTextItems(control)
            compare(after.length, 1)
            verify(after[0] === before[0], "selectable paragraph item was recreated")
            verify(renders(control, "world"))
            verify(!renders(control, "hello"))
        }

        // A multi-block rebind with an unchanged type sequence recycles every item.
        function test_sameShapeMultiBlockKeepsAllInstances() {
            control.blocks = [
                { type: "text", html: "para one" },
                { type: "code", code: "a = 1" }
            ]
            tryVerify(() => control.implicitHeight > 0)

            const before = collectTextItems(control)
            compare(before.length, 2)

            control.blocks = [
                { type: "text", html: "para two" },
                { type: "code", code: "b = 2" }
            ]

            const after = collectTextItems(control)
            compare(after.length, 2)
            for (let i = 0; i < before.length; ++i)
                verify(after[i] === before[i], "block " + i + " was recreated")
            verify(renders(control, "para two"))
            verify(renders(control, "b = 2"))
            verify(!renders(control, "para one"))
            verify(!renders(control, "a = 1"))
        }

        // Quote sub-blocks (replies render through this path) are recycled too.
        function test_quoteNestedRebindKeepsInstance() {
            control.blocks = [{ type: "quote", blocks: [{ type: "text", html: "inner one" }] }]
            tryVerify(() => control.implicitHeight > 0)

            const before = collectTextItems(control)
            compare(before.length, 1)

            control.blocks = [{ type: "quote", blocks: [{ type: "text", html: "inner two" }] }]

            const after = collectTextItems(control)
            compare(after.length, 1)
            verify(after[0] === before[0], "nested quote item was recreated")
            verify(renders(control, "inner two"))
            verify(!renders(control, "inner one"))
        }

        // ── shape change (the recreate fallback) ─────────────────────────────────

        // Renders `blocks` in a fresh view and compares its pixels against `ctrl` — the
        // recycled/rebuilt view must be indistinguishable from a fresh build.
        function verifyMatchesFreshBuild(ctrl, blocks) {
            const fresh = createTemporaryObject(componentUnderTest, root,
                                                { blocks: blocks, y: 200 })
            verify(fresh)
            // Both views relayout asynchronously — wait until their heights settle and agree.
            tryVerify(() => fresh.implicitHeight > 0 && ctrl.implicitHeight === fresh.implicitHeight,
                      5000, "rebound view height differs from a fresh build")
            verify(grabImage(ctrl).equals(grabImage(fresh)),
                   "rebound view renders differently from a fresh build")
        }

        // Count change (paragraph → paragraph+code) falls back to recreation and matches
        // a fresh build.
        function test_countChangeRecreatesAndMatchesFreshBuild() {
            control.blocks = [{ type: "text", html: "hello" }]
            tryVerify(() => control.implicitHeight > 0)
            compare(collectTextItems(control).length, 1)

            const blocks = [
                { type: "text", html: "hello" },
                { type: "code", code: "x = 1" }
            ]
            control.blocks = blocks
            tryVerify(() => collectTextItems(control).length === 2)
            verify(renders(control, "hello"))
            verify(renders(control, "x = 1"))

            verifyMatchesFreshBuild(control, blocks)
        }

        // Type change with an unchanged count (paragraph → code) rebuilds that block's
        // renderer and matches a fresh build.
        function test_typeChangeRecreatesRendererAndMatchesFreshBuild() {
            control.blocks = [{ type: "text", html: "hello" }]
            tryVerify(() => control.implicitHeight > 0)

            const blocks = [{ type: "code", code: "y = 2" }]
            control.blocks = blocks
            tryVerify(() => renders(control, "y = 2"))
            verify(!renders(control, "hello"), "old paragraph text still shown")

            verifyMatchesFreshBuild(control, blocks)
        }

        // Shrinking the count drops the extra items and matches a fresh build.
        function test_countShrinkMatchesFreshBuild() {
            control.blocks = [
                { type: "text", html: "hello" },
                { type: "code", code: "x = 1" },
                { type: "quote", blocks: [{ type: "text", html: "quoted" }] }
            ]
            tryVerify(() => control.implicitHeight > 0)

            const blocks = [{ type: "text", html: "bye" }]
            control.blocks = blocks
            tryVerify(() => collectTextItems(control).length === 1)
            verify(renders(control, "bye"))
            verify(!renders(control, "x = 1"))
            verify(!renders(control, "quoted"))

            verifyMatchesFreshBuild(control, blocks)
        }

        // ── no stale state across recycled rebinds ───────────────────────────────

        // Rebinding a mention/link/code-rich message to plain text (same shape → recycled
        // item) leaves no remnants of the old content.
        function test_noStaleRichContentAfterRecycledRebind() {
            control.blocks = [{
                type: "text",
                html: '<a href="0xabc" class="mention">@alice</a> see '
                      + '<a href="https://stale.example">https://stale.example</a> and <code>fooCode</code>'
            }]
            tryVerify(() => control.implicitHeight > 0)
            verify(renders(control, "@alice"))
            verify(renders(control, "stale.example"))
            verify(renders(control, "fooCode"))

            const before = collectTextItems(control)
            compare(before.length, 1)

            control.blocks = [{ type: "text", html: "plain text" }]

            const after = collectTextItems(control)
            compare(after.length, 1)
            verify(after[0] === before[0], "item was recreated instead of recycled")
            verify(renders(control, "plain text"))
            verify(!renders(control, "@alice"), "stale mention remnant")
            verify(!renders(control, "0xabc"), "stale mention href remnant")
            verify(!renders(control, "stale.example"), "stale link remnant")
            verify(!renders(control, "fooCode"), "stale code-span remnant")

            verifyMatchesFreshBuild(control, [{ type: "text", html: "plain text" }])
        }

        // ── edited marker across recycled rebinds ────────────────────────────────

        // Toggling `edited` recycles the text-last block (same shape) and the marker
        // appears/disappears correctly on the same item instance.
        function test_editedToggleOnRecycledTextBlock() {
            control.blocks = [{ type: "text", html: "hello" }]
            tryVerify(() => control.implicitHeight > 0)

            const before = collectTextItems(control)
            compare(before.length, 1)
            verify(!renders(control, "(edited)"))

            control.edited = true
            let after = collectTextItems(control)
            compare(after.length, 1)
            verify(after[0] === before[0], "edited:true recreated the text item")
            tryVerify(() => renders(control, "(edited)"), 1000, "marker not shown")
            verify(renders(control, "hello"))

            control.edited = false
            after = collectTextItems(control)
            compare(after.length, 1)
            verify(after[0] === before[0], "edited:false recreated the text item")
            tryVerify(() => !renders(control, "(edited)"), 1000, "marker not removed")
            verify(renders(control, "hello"))
        }

        // With a non-text last block the marker is its own trailing block: toggling `edited`
        // changes the count (recreate path) and the marker still comes and goes correctly.
        function test_editedToggleWithTrailingCodeBlock() {
            control.blocks = [
                { type: "text", html: "hello" },
                { type: "code", code: "x = 1" }
            ]
            tryVerify(() => control.implicitHeight > 0)
            compare(collectTextItems(control).length, 2)

            control.edited = true
            tryVerify(() => renders(control, "(edited)"), 1000, "marker not shown after code block")
            compare(collectTextItems(control).length, 3)

            control.edited = false
            tryVerify(() => !renders(control, "(edited)"), 1000, "marker not removed")
            compare(collectTextItems(control).length, 2)
            verify(renders(control, "hello"))
            verify(renders(control, "x = 1"))
        }
    }
}
