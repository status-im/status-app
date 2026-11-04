import QtQuick
import QtTest
import "ChatTextTestUtils.js" as ChatTextTestUtils

import StatusQ 0.1

// ChatTextItem renders a QTextDocument through QSGTextNode and handles its
// own mouse input. These tests drive it with synthetic events, standalone and
// outside any Flickable, so a failure here is the item's and not the page's.
Item {
    id: root

    width: 600
    height: 200

    readonly property var messageSegments: [
        { text: "Hey " },
        { text: "@Bob", href: "//0xc0ffee" },
        { text: ", the " },
        { text: "build", bold: true },
        { text: " is green again, see " },
        { text: "the run", href: "https://status.app/build/1234" },
        { text: " for details." }
    ]

    readonly property var quoteSegments: [
        { text: "Before the quote" },
        { text: "Quoted one with ", newBlock: true, quoteLevel: 1 },
        { text: "a link", href: "https://status.app" },
        { text: "Quoted two", newBlock: true, quoteLevel: 1 },
        { text: "After the quote", newBlock: true }
    ]

    // One window-level shortcut; temporary ones would linger between data
    // rows and make the next row's sequence ambiguous.
    Shortcut {
        id: windowShortcut
        enabled: false
        property int activations: 0
        onActivated: ++activations
    }

    Component {
        id: itemComponent

        ChatTextItem {
            appearance: ChatTextAppearance {
                lineHeight: 22
                selectionColor: "#8040ff"
            }

            width: 480
            segments: root.messageSegments
        }
    }

    Component {
        id: flickableComponent

        Flickable {
            readonly property alias textItem: inner

            width: 500
            height: 100
            contentWidth: 500
            contentHeight: 400

            ChatTextItem {
                appearance: ChatTextAppearance {
                    lineHeight: 22
                }

                id: inner

                width: 480
                segments: root.messageSegments
            }
        }
    }

    Component {
        id: focusSinkComponent

        Item {
            width: 10
            height: 10
        }
    }

    TestCase {

        readonly property var appearanceProperties: ChatTextTestUtils.appearanceProperties
        function createStyledTemporary(component, parent, properties) {
            return ChatTextTestUtils.create(testCase, component, parent, properties)
        }
        id: testCase

        name: "ChatTextItem"
        when: windowShown
        property list<chatTextSegment> initialSegments

        function createItem() {
            const item = createStyledTemporary(itemComponent, root)
            verify(!!item)
            verify(item.contentHeight > 0)
            return item
        }

        function test_semanticForegroundPrecedence() {
            const item = createItem()
            item.appearance.color = "black"
            item.appearance.quoteColor = "red"
            item.appearance.linkColor = "blue"
            item.appearance.mentionColor = "lime"
            item.appearance.mentionBackground = "transparent"
            item.segments = [
                {text: "WWWW ", quoteLevel: 1},
                {text: "WWWW ", quoteLevel: 1, href: "https://status.app"},
                {text: "WWWW", quoteLevel: 1, href: "https://status.app", mention: true}
            ]
            let image = grabImage(item)
            for (const color of ["red", "blue", "lime"])
                verify(colourShare(image, Qt.rect(0, 0, item.width, item.contentHeight), Qt.color(color)) > 0.001, "Missing semantic foreground " + color)
            item.appearance.quoteColor = "magenta"
            item.appearance.mentionColor = "yellow"
            image = grabImage(item)
            for (const color of ["magenta", "blue", "yellow"])
                verify(colourShare(image, Qt.rect(0, 0, item.width, item.contentHeight), Qt.color(color)) > 0.001, "Missing updated foreground " + color)
        }

        function test_selectAll() {
            const item = createItem()
            item.selectAll()
            verify(item.selectedText.startsWith("Hey @Bob"))
        }

        // A selection is a pair of positions into the old document; it must not
        // survive a rebuild and point into the new one.
        function test_newContentClearsSelection() {
            const item = createItem()
            item.selectAll()
            verify(item.selectedText.length > 0)

            item.segments = [{ text: "Hi" }]

            compare(item.selectionStart, -1)
            compare(item.selectionEnd, -1)
            compare(item.selectedText, "")
        }

        function test_appearanceChangesPreserveSelection_data() {
            const changes = [
                {property: "linkColor", value: "red"},
                {property: "mentionColor", value: "red"},
                {property: "mentionBackground", value: "blue"},
                {property: "quoteColor", value: "green"},
                {property: "codeBackground", value: "cyan"},
                {property: "lineHeight", value: 30},
                {property: "emojiOnlyPixelSize", value: 42},
                {property: "codeFontFamily", value: "serif"},
                {property: "editedMarkerFontSize", value: 20},
                {property: "editedMarkerColor", value: "green"},
                {property: "font", value: Qt.font({family: "serif", pixelSize: 20})},
                {property: "color", value: "purple"},
                {property: "quoteBarColor", value: "yellow"},
                {property: "quoteBarWidth", value: 5},
                {property: "quoteSpacing", value: 12},
                {property: "codeBlockPadding", value: 12},
                {property: "codeBorderColor", value: "green"},
                {property: "codeBlockRadius", value: 12},
                {property: "selectionColor", value: "navy"},
                {property: "selectionTextColor", value: "yellow"},
                {property: "hoverHighlightColor", value: "cyan"},
                {property: "width", value: 160},
                {property: "segments", value: "mention"},
                {property: "segments", value: "emphasis"}
            ]
            const rows = []
            for (const change of changes) {
                for (const backward of [false, true]) {
                    rows.push({
                        tag: change.property + "-" + change.value + (backward ? "-backward" : "-forward"),
                        property: change.property, value: change.value, backward: backward
                    })
                }
            }
            return rows
        }

        function test_appearanceChangesPreserveSelection(data) {
            const item = createItem()
            item.segments = [
                {text: "link", href: "https://a.test"},
                {text: " and 😎", italic: true},
                {text: "quoted", quoteLevel: 1, newBlock: true},
                {text: "code\nmore", codeBlock: true, quoteLevel: 1},
                {text: "end", newBlock: true}
            ]
            item.edited = true
            item.highlightedLink = "https://a.test"
            item.hoverAt(10, 11)
            compare(item.hoveredLink, "https://a.test")
            item.forceActiveFocus()
            item.selectAll()
            if (data.backward)
                item.select(item.selectionEnd, item.selectionStart)
            const start = item.selectionStart
            const end = item.selectionEnd
            const text = item.selectedText
            const spy = createStyledTemporary(Qt.createComponent("QtTest", "SignalSpy"), root,
                                               {target: item, signalName: "selectionChanged"})

            if (data.property === "segments") {
                const style = data.value === "mention" ? {mention: true}
                                                       : {bold: true, italic: true, strikethrough: true}
                item.segments = item.segments.map(segment => Object.assign({}, segment, style))
            } else {
                (appearanceProperties.indexOf(data.property) >= 0 ? item.appearance : item)[data.property] = data.value
            }
            compare(item.selectionStart, start)
            compare(item.selectionEnd, end)
            compare(item.selectedText, text)
            compare(spy.count, 0, "appearance changes must not transiently clear selection")
            verify(item.activeFocus)
            compare(item.hoveredLink, "https://a.test")
            compare(item.highlightedLink, "https://a.test")
            ClipboardUtils.setText("")
            keySequence(StandardKey.Copy)
            compare(ClipboardUtils.text, text)
        }

        function test_appearanceChangeDuringDragKeepsAnchor() {
            const item = createItem()
            item.segments = [{text: "hello world foo bar baz"}]
            mousePress(item, 2, 11)
            mouseMove(item, 70, 11)
            const text = item.selectedText
            verify(text.length > 0)
            item.appearance.linkColor = "red"
            compare(item.selectedText, text)
            mouseMove(item, 150, 11)
            mouseRelease(item, 150, 11)
            verify(item.selectedText.length > text.length, "selection must keep extending after restyling")
            verify(item.selectedText.startsWith("hello"))
        }

        function test_appearanceChangeBetweenClicksKeepsCycle() {
            const item = createItem()
            item.segments = [{text: "hello world"}]
            mouseClick(item, 2, 11)
            item.appearance.linkColor = "red"
            mouseClick(item, 2, 11)
            compare(item.selectedText, "hello")
            item.appearance.codeBackground = "blue"
            mouseClick(item, 2, 11)
            compare(item.selectedText, "hello world")
        }

        function test_appearanceChangeKeepsSelectionPainted() {
            const item = selectionItem([{text: "aaaa bbbb cccc"}])
            item.select(5, 9)
            item.appearance.linkColor = "red"
            const image = grabImage(item)
            verify(selectedShare(item, image, 11, 5, 9) > 0.3,
                   "restyling must preserve the visible selection")
            compare(selectedShare(item, image, 11, 0, 4), 0)
        }

        function test_contentChangesStillResetSelection_data() {
            return ["text", "href", "newBlock", "codeBlock", "quoteLevel", "edited"].map(key => ({tag: key, key: key}))
        }

        function test_contentChangesStillResetSelection(data) {
            const item = createItem()
            item.segments = [{text: "hello", href: "https://a.test"}, {text: " world"}]
            item.selectAll()
            if (data.key === "edited") {
                item.edited = true
            } else {
                const changes = {text: "changed", href: "https://b.test", newBlock: true, codeBlock: true, quoteLevel: 1}
                const segments = item.segments.map(segment => Object.assign({}, segment))
                segments[1][data.key] = changes[data.key]
                item.segments = segments
            }
            compare(item.selectedText, "")
            compare(item.selectionStart, -1)
            compare(item.selectionEnd, -1)
        }

        function test_editedMarkerPlacement_data() {
            return [
                {tag: "text", segments: [{text: "Hello"}], expected: "Hello (edited)", separate: false},
                {tag: "quote", segments: [{text: "Quoted", quoteLevel: 1}], expected: "> Quoted\n (edited)", separate: true},
                {tag: "code", segments: [{text: "code", codeBlock: true}], expected: "code\n (edited)", separate: true},
                {tag: "quoted-code", segments: [{text: "code", codeBlock: true, quoteLevel: 1}], expected: "> code\n (edited)", separate: true}
            ]
        }

        function test_editedMarkerPlacement(data) {
            const item = createItem()
            item.segments = data.segments
            const height = item.contentHeight
            const bars = item.quoteBarRects()
            const frames = item.codeBlockRects()
            item.edited = true
            item.selectAll()
            compare(item.selectedText, data.expected)
            compareSegmentFields(item.segments, data.segments) // the input remains untouched
            compare(item.quoteBarRects(), bars)
            compare(item.codeBlockRects(), frames)
            if (data.separate)
                verify(item.contentHeight > height)
            else
                compare(item.contentHeight, height)
            item.edited = false
            item.selectAll()
            verify(item.selectedText.indexOf("(edited)") < 0)
            compare(item.contentHeight, height)
        }

        function test_editedEmptyContent() {
            const item = createItem()
            item.segments = []
            item.edited = true
            item.selectAll()
            compare(item.selectedText, "")
        }

        function test_editedMarkerDoesNotInheritLink() {
            const item = createItem()
            item.segments = [{text: "Hello", href: "https://status.app", bold: true}]
            item.edited = true
            const markerStart = xOf(item, 11, 6)
            verify(markerStart > 0)
            compare(item.linkAt(markerStart + 2, 11), "")
            item.selectAll()
            compare(item.selectedText, "Hello (edited)")
            item.segments = [{text: "Updated"}]
            item.selectAll()
            compare(item.selectedText, "Updated (edited)")
        }

        function test_editedEmojiKeepsItsSize() {
            const item = createItem()
            item.appearance.emojiOnlyPixelSize = 40
            item.segments = [{text: "😎"}]
            const height = item.contentHeight
            verify(item.emojiOnly)
            item.edited = true
            verify(item.emojiOnly)
            compare(item.contentHeight, height)
        }

        function test_mentionAppearanceSurvivesHighlightRestoration() {
            const item = createItem()
            item.appearance.mentionColor = "blue"
            item.appearance.mentionBackground = "blue"
            item.segments = [{text: "WWWWWW", href: "https://a.test", mention: true},
                         {text: "WWWWWW", href: "https://b.test", newBlock: true},
                         {text: "WWWWWW", code: true, mention: true, newBlock: true},
                         {text: "WWWWWW", code: true, newBlock: true}]
            item.appearance.hoverHighlightColor = "yellow"
            item.highlightedLink = "https://a.test"
            item.appearance.linkColor = "red"
            item.appearance.codeBackground = "lime"
            item.highlightedLink = ""
            verify(rowColorShare(item, 0, "blue") > 0.01)
            verify(rowColorShare(item, 1, "red") > 0.01)
            verify(rowColorShare(item, 2, "blue") > 0.1)
            verify(rowColorShare(item, 3, "lime") > 0.1)
        }

        function test_emojiSizeFollowsFontAndEmojiOnlyFallback() {
            const item = createItem()
            item.appearance.font.pixelSize = 12
            item.segments = [{text: "hello 😎"}]
            item.selectAll()
            const selected = item.selectedText
            const natural = item.contentHeight
            item.appearance.font.pixelSize = 32
            verify(item.contentHeight > natural)
            compare(item.selectedText, selected)
            item.appearance.font.pixelSize = 12
            compare(item.contentHeight, natural)
            item.segments = [{text: "😎"}]
            item.appearance.emojiOnlyPixelSize = 70
            const enlarged = item.contentHeight
            item.appearance.font.pixelSize = 20
            compare(item.contentHeight, enlarged)
            item.appearance.emojiOnlyPixelSize = 0
            verify(item.contentHeight < enlarged)
        }

        function test_editedMarkerAppearance() {
            const item = createItem()
            item.segments = [{text: "Hello"}]
            item.appearance.color = "red"
            item.appearance.editedMarkerColor = "lime"
            item.appearance.editedMarkerFontSize = 12
            item.edited = true
            let image = grabImage(item)
            const rect = Qt.rect(0, 0, item.width, item.contentHeight)
            verify(colourShare(image, rect, Qt.color("lime")) > 0.001)
            const height = item.contentHeight
            item.appearance.editedMarkerFontSize = 40
            verify(item.contentHeight > height)
            item.appearance.editedMarkerColor = "blue"
            image = grabImage(item)
            verify(colourShare(image, Qt.rect(0, 0, item.width, item.contentHeight), Qt.color("blue")) > 0.001)
        }

        // Colours of what the item paints, read back from a grab: share of
        // pixels in a rect whose colour is close to `target`.
        function colourShare(image, rect, target) {
            let hits = 0, total = 0
            for (let x = Math.floor(rect.x); x < rect.x + rect.width; ++x) {
                for (let y = Math.floor(rect.y); y < rect.y + rect.height; ++y) {
                    const c = image.pixel(x, y)
                    total++
                    if (Math.abs(c.r - target.r) < 0.25 && Math.abs(c.g - target.g) < 0.25
                            && Math.abs(c.b - target.b) < 0.25 && c.a > 0.5)
                        hits++
                }
            }
            return total ? hits / total : 0
        }

        // Paragraphs without characters still paint their decorations: the
        // document is empty, the frame is not.
        function test_decorationsWithoutText_data() {
            return [
                {tag: "empty-fence", source: "```\n```", frames: 1, bars: 0}
            ]
        }

        function test_decorationsWithoutText(data) {
            const item = createItem()
            item.appearance.codeBackground = "lime"
            item.appearance.quoteBarColor = "lime"
            item.segments = MarkdownUtils.toChatTextSegments(data.source)
            verify(item.contentHeight > 0)
            const rects = item.codeBlockRects().concat(item.quoteBarRects())
            compare(item.codeBlockRects().length, data.frames)
            compare(item.quoteBarRects().length, data.bars)
            const r = rects[0]
            // Sample the interior, clear of the frame's border and rounding.
            const inner = Qt.rect(r.x + r.width / 4, r.y + r.height / 4,
                                  Math.max(1, r.width / 2), Math.max(1, r.height / 2))
            verify(colourShare(grabImage(item), inner, Qt.color("lime")) > 0.9,
                   "the decoration must be painted")
        }

        // The item takes Copy and Select All from a window-level Shortcut on
        // the same keys, as QQuickTextEdit does; Copy only with a selection.
        function test_shortcutOverride_data() {
            return [
                {tag: "copy-with-selection", key: StandardKey.Copy, select: true, claimed: true},
                {tag: "copy-without-selection", key: StandardKey.Copy, select: false, claimed: false},
                {tag: "select-all", key: StandardKey.SelectAll, select: false, claimed: true},
                {tag: "select-all-not-selectable", key: StandardKey.SelectAll, select: false,
                 selectable: false, claimed: false}
            ]
        }

        function test_shortcutOverride(data) {
            const item = createItem()
            item.selectable = data.selectable ?? true
            windowShortcut.sequences = [data.key]
            windowShortcut.activations = 0
            windowShortcut.enabled = true
            try {
                item.forceActiveFocus()
                if (data.select)
                    item.select(0, 3)

                keySequence(data.key)

                compare(windowShortcut.activations, data.claimed ? 0 : 1)
                if (data.key === StandardKey.SelectAll && data.claimed)
                    verify(item.selectedText.startsWith("Hey @Bob"))
            } finally {
                windowShortcut.enabled = false
            }
        }

        // Frame edges are antialiased over one device pixel, so a 1 px border
        // keeps a band in its own colour on a high-DPI screen.
        function test_codeFrameBorderIsSolidOnHighDpi() {
            const item = createItem()
            item.appearance.codeBackground = "white"
            item.appearance.codeBorderColor = "blue"
            item.segments = [{text: "before"}, {text: "a long enough line of code", codeBlock: true}]
            const frame = item.codeBlockRects()[0]
            const image = grabImage(item)
            const scale = image.width / item.width
            if (scale < 2)
                skip("needs a device pixel ratio of at least 2")
            const x = Math.round((frame.x + frame.width / 2) * scale)
            const top = Math.floor(frame.y * scale)
            let solid = false
            for (let y = top - 2; y <= top + 2 * scale; ++y) {
                const c = image.pixel(x, y)
                solid |= c.a > 0.95 && c.r < 0.05 && c.g < 0.05 && c.b > 0.95
            }
            verify(solid, "the top border has a pixel in exactly its colour")
        }

        function highlightItem() {
            const item = createItem()
            item.appearance.hoverHighlightColor = "lime"
            item.appearance.mentionBackground = "blue"
            item.segments = [
                {text: "WWWWWW", href: "https://a.test"},
                {text: "WWWWWW", href: "https://b.test", mention: true, newBlock: true},
                {text: "WWWWWW", href: "https://a.test", quoteLevel: 1, newBlock: true},
                {text: "WWWWWW", newBlock: true}
            ]
            return item
        }

        function rowColorShare(item, row, color) {
            let y = row * item.appearance.lineHeight
            const bars = item.quoteBarRects()
            if (row >= 2 && bars.length)
                y = bars[0].y + (row - 2) * (item.appearance.lineHeight + item.appearance.codeBlockPadding)
            return colourShare(grabImage(item), Qt.rect(0, y, 100, item.appearance.lineHeight), Qt.color(color))
        }

        function test_externalHighlightAllOccurrences() {
            const item = highlightItem()
            item.highlightedLink = "https://a.test"
            compare(item.hoveredLink, "")
            verify(rowColorShare(item, 0, "lime") > 0.1)
            verify(rowColorShare(item, 2, "lime") > 0.1)
            compare(rowColorShare(item, 1, "lime"), 0)
            compare(rowColorShare(item, 3, "lime"), 0) // no empty-href/plain-text match
            item.highlightedLink = "https://b.test"
            compare(rowColorShare(item, 0, "lime"), 0)
            compare(rowColorShare(item, 2, "lime"), 0)
            verify(rowColorShare(item, 1, "lime") > 0.1)
        }

        function test_externalHighlightAndHoverCoexist() {
            const item = highlightItem()
            item.highlightedLink = "https://a.test"
            item.hoverAt(10, 33)
            compare(item.hoveredLink, "https://b.test")
            verify(rowColorShare(item, 0, "lime") > 0.1)
            verify(rowColorShare(item, 1, "lime") > 0.1)
            item.clearHover()
            verify(rowColorShare(item, 0, "lime") > 0.1)
            verify(rowColorShare(item, 1, "blue") > 0.1)
            item.hoverAt(10, 33)
            item.highlightedLink = ""
            compare(rowColorShare(item, 0, "lime"), 0)
            verify(rowColorShare(item, 1, "lime") > 0.1)
            item.clearHover()
            verify(rowColorShare(item, 1, "blue") > 0.1)
        }

        function test_highlightSameAsHoverRestoresOriginalBackground() {
            const item = highlightItem()
            item.highlightedLink = "https://b.test"
            item.hoverAt(10, 33)
            item.clearHover()
            verify(rowColorShare(item, 1, "lime") > 0.1)
            item.highlightedLink = ""
            verify(rowColorShare(item, 1, "blue") > 0.1)
            compare(rowColorShare(item, 1, "lime"), 0)
        }

        function test_highlightPreservesSelectionAndReappliesAfterRebuild() {
            const item = highlightItem()
            item.select(1, 4)
            const selected = item.selectedText
            item.highlightedLink = "https://a.test"
            item.hoverAt(10, 33)
            item.appearance.hoverHighlightColor = "yellow"
            item.clearHover()
            compare(item.selectedText, selected)
            compare(item.selectionStart, 1)
            compare(item.selectionEnd, 4)
            item.clearSelection()
            verify(rowColorShare(item, 0, "yellow") > 0.1)
            item.appearance.linkColor = "red" // changing the base color keeps the active highlight
            verify(rowColorShare(item, 0, "yellow") > 0.1)
            item.hoverAt(10, 33)
            item.segments = [{text: "plain"}]
            compare(item.hoveredLink, "")
            compare(item.highlightedLink, "https://a.test")
            compare(rowColorShare(item, 0, "yellow"), 0)
            item.segments = [{text: "WWWWWW", href: "https://a.test"}]
            verify(rowColorShare(item, 0, "yellow") > 0.1)
        }

        // A link segment carries no foreground of its own, so linkColor -- set
        // here after segments -- has to reach it at paint time.
        function test_linkIsPaintedInLinkColor() {
            const item = createItem()
            item.segments = [{ text: "WWWWWWWWWW", href: "https://status.app" }]
            item.appearance.color = "black"
            item.appearance.linkColor = "red"

            const image = grabImage(item)
            const linkRect = Qt.rect(0, 0, 80, item.appearance.lineHeight)
            verify(colourShare(image, linkRect, Qt.color("red")) > 0.05,
                   "the link is not painted in linkColor")
            compare(colourShare(image, linkRect, Qt.color("black")), 0)
        }

        // Emoji /////////////////////////////////////////////////////////////

        // Left edge of the character at `position` on the line at `y`.
        function xOf(item, y, position) {
            for (let x = 0; x < item.width; ++x) {
                if (item.positionAt(x, y) >= position)
                    return x
            }
            return -1
        }

        // Emoji sequences follow font changes while retaining their classification.
        function test_emojiSequencesAreEnlarged() {
            const item = createItem()
            item.segments = [{ text: "Hi 👍🏽👍🏽 there" }]
            const after = "Hi 👍🏽👍🏽 ".length
            const plain = xOf(item, 11, after)
            item.appearance.font.pixelSize = 20

            verify(xOf(item, 11, after) > plain + 4, "emoji did not grow")
            verify(!item.emojiOnly)
            verify(item.contentHeight >= item.appearance.lineHeight)
        }

        // lineHeight is a minimum, like the px line-height it stands in for.
        function test_tallEmojiGrowsItsLine() {
            const item = createItem()
            item.appearance.font.pixelSize = 32
            item.segments = [{ text: "Big 🎉" }, { text: "small", newBlock: true }]

            verify(item.contentHeight >= 40 + item.appearance.lineHeight,
                   "line did not grow: " + item.contentHeight)
        }

        function test_emojiOnlyGrowsTheLine() {
            const item = createItem()
            item.appearance.emojiOnlyPixelSize = 40

            item.segments = [{ text: "🎉 🎉" }]
            verify(item.emojiOnly)
            verify(item.contentHeight >= 40, "line did not grow: " + item.contentHeight)

            item.segments = [{ text: "Party 🎉" }]
            verify(!item.emojiOnly)
            compare(item.contentHeight, item.appearance.lineHeight)
        }

        // A ZWJ family and a keycap are single grapheme clusters with non-emoji
        // code points inside; per-code-point classification gets both wrong.
        function test_emojiClustersCountAsEmoji() {
            const item = createItem()
            item.appearance.emojiOnlyPixelSize = 40

            item.segments = [{ text: "👨‍👩‍👧 1️⃣" }]
            verify(item.emojiOnly)

            item.selectAll()
            compare(item.selectedText, "👨‍👩‍👧 1️⃣")
        }

        function test_structuredEmojiClassification_data() {
            return [
                {tag: "plain", segment: {text: "😎"}, only: true},
                {tag: "bold", segment: {text: "😎", bold: true}, only: false},
                {tag: "quote", segment: {text: "😎", quoteLevel: 1}, only: false},
                {tag: "inline-code", segment: {text: "😎", code: true}, only: false},
                {tag: "code-block", segment: {text: "😎", codeBlock: true}, only: false},
                {tag: "link", segment: {text: "😎", href: "https://status.app"}, only: false}
            ]
        }

        function test_structuredEmojiClassification(data) {
            const item = createItem()
            item.segments = [data.segment]
            compare(item.emojiOnly, data.only)
        }

        function test_emojiSizeChangeReapplies() {
            const item = createItem()
            item.appearance.emojiOnlyPixelSize = 30
            item.segments = [{ text: "🎉" }]
            const smaller = item.contentHeight

            item.appearance.emojiOnlyPixelSize = 60

            verify(item.contentHeight > smaller)
        }

        // Painted selection ///////////////////////////////////////////////
        //
        // selectedText alone proves nothing about what the user sees: these
        // read the selection back from a grab.

        function selectionItem(segments) {
            const item = createItem()
            item.segments = segments
            item.appearance.color = "black"
            item.appearance.selectionColor = "red"
            item.appearance.selectionTextColor = "white"
            return item
        }

        // Share of selection colour over the characters [from, to) of the
        // line at y. Selected glyphs are drawn in white over it, so a selected
        // character reads about 0.5, an unselected one exactly 0: anything
        // over 0.3 is painted.
        function selectedShare(item, image, y, from, to) {
            const x0 = xOf(item, y, from)
            const x1 = xOf(item, y, to)
            return colourShare(image, Qt.rect(x0 + 1, y - 4, x1 - x0 - 2, 8), Qt.color("red"))
        }

        function test_selectionInTheMiddleIsPainted() {
            const item = selectionItem([{ text: "aaaa bbbb cccc dddd" }])

            item.select(5, 9)
            const image = grabImage(item)

            compare(item.selectedText, "bbbb")
            verify(selectedShare(item, image, 11, 5, 9) > 0.3, "selection not painted")
            compare(selectedShare(item, image, 11, 0, 4), 0, "painted before the selection")
            compare(selectedShare(item, image, 11, 10, 14), 0, "painted after the selection")
        }

        function test_selectionKeepsFormattedGlyphsAcrossParagraphs_data() {
            return [
                {tag: "italic", style: {italic: true}},
                {tag: "bold", style: {bold: true}},
                {tag: "strikeout", style: {strikethrough: true}},
                {tag: "inline-code", style: {code: true}}
            ]
        }

        function test_selectionKeepsFormattedGlyphsAcrossParagraphs(data) {
            const item = selectionItem([
                {text: "regular text first"},
                Object.assign({text: "formatted text", newBlock: true}, data.style),
                {text: "regular text last", newBlock: true}
            ])
            item.appearance.color = "lime"
            item.appearance.selectionTextColor = "lime"
            const before = grabImage(item)
            item.selectAll()
            const after = grabImage(item)
            const rect = Qt.rect(0, item.appearance.lineHeight, 100, item.appearance.lineHeight)
            const beforeShare = colourShare(before, rect, Qt.color("lime"))
            verify(beforeShare > 0.01)
            verify(colourShare(after, rect, Qt.color("lime")) >= beforeShare * 0.8,
                   "selection hides formatted glyphs")
        }

        function test_selectionPaintsItsLastCharacter() {
            const item = selectionItem([{ text: "aaaa bbbb cccc dddd" }])

            item.select(0, 9)
            const image = grabImage(item)

            verify(selectedShare(item, image, 11, 8, 9) > 0.3, "last character not painted")
            compare(selectedShare(item, image, 11, 10, 14), 0, "painted past the end")
        }

        function test_dragFromTheMiddleIsPainted() {
            const item = selectionItem([{ text: "aaaa bbbb cccc dddd" }])
            const y = 11

            mousePress(item, xOf(item, y, 5) + 1, y, Qt.LeftButton)
            mouseMove(item, xOf(item, y, 7), y)
            mouseMove(item, xOf(item, y, 14) + 1, y)
            mouseRelease(item, xOf(item, y, 14) + 1, y, Qt.LeftButton)
            const image = grabImage(item)

            compare(item.selectedText, "bbbb cccc")
            verify(selectedShare(item, image, y, 5, 14) > 0.3, "drag selection not painted")
            compare(selectedShare(item, image, y, 0, 4), 0)
        }

        // A backwards drag selects the same range as a forwards one.
        function test_backwardDragIsPainted() {
            const item = selectionItem([{ text: "aaaa bbbb cccc dddd" }])
            const y = 11

            mousePress(item, xOf(item, y, 14) + 1, y, Qt.LeftButton)
            mouseMove(item, xOf(item, y, 12), y)
            mouseMove(item, xOf(item, y, 5) + 1, y)
            mouseRelease(item, xOf(item, y, 5) + 1, y, Qt.LeftButton)
            const image = grabImage(item)

            compare(item.selectedText, "bbbb cccc")
            verify(selectedShare(item, image, y, 5, 14) > 0.3, "backward selection not painted")
        }

        function test_selectionAcrossAQuoteIsPainted() {
            const item = selectionItem(root.quoteSegments)
            item.appearance.quoteBarColor = "transparent"

            const quotedLine = item.quoteBarRects()[0].y + item.appearance.lineHeight / 2
            const start = "Before the quote".length + 1
            item.select(3, start + 8)
            const image = grabImage(item)

            verify(selectedShare(item, image, item.appearance.lineHeight / 2, 3, 16) > 0.3,
                   "first paragraph not painted")
            verify(selectedShare(item, image, quotedLine, start, start + 8) > 0.3,
                   "quoted paragraph not painted")
        }

        function test_selectionInACodeBlockIsPainted() {
            const item = selectionItem([{ text: "Before" },
                                        { text: "let x = 1", codeBlock: true }])
            item.appearance.codeBackground = "white"
            item.appearance.codeBorderColor = "white"

            const frame = item.codeBlockRects()[0]
            const y = frame.y + frame.height / 2
            const start = "Before".length + 1
            item.select(start + 4, start + 9)
            const image = grabImage(item)

            compare(item.selectedText, "x = 1")
            verify(selectedShare(item, image, y, start + 4, start + 9) > 0.3,
                   "code selection not painted")
        }

        // A drag that starts on a link selects, like TextEdit; only a click
        // activates the link.
        function test_dragStartingOnALinkSelects() {
            const item = createItem()
            item.segments = [{ text: "see " }, { text: "the link", href: "https://status.app" },
                         { text: " for more" }]
            const spy = createStyledTemporary(
                          Qt.createComponent("QtTest", "SignalSpy"), root,
                          { target: item, signalName: "linkActivated" })
            const y = 11

            const linkX = xOf(item, y, 5) + 1
            verify(item.linkAt(linkX, y) !== "")

            mousePress(item, linkX, y, Qt.LeftButton)
            mouseMove(item, linkX + 10, y)
            mouseMove(item, xOf(item, y, 16) + 1, y)
            mouseRelease(item, xOf(item, y, 16) + 1, y, Qt.LeftButton)

            compare(spy.count, 0)
            compare(item.selectedText, "he link for")
        }

        // Keyboard and focus ////////////////////////////////////////////////

        function test_pressTakesFocus() {
            const item = createItem()
            verify(!item.activeFocus)

            mouseClick(item, 4, 8, Qt.LeftButton)

            verify(item.activeFocus)
        }

        function test_pressOnNonSelectableTextLeavesFocus() {
            const item = createItem()
            item.selectable = false

            mouseClick(item, 4, 8, Qt.LeftButton)

            verify(!item.activeFocus)
        }

        function test_copyShortcutCopiesSelection() {
            const item = createItem()
            ClipboardUtils.setText("")
            item.forceActiveFocus()
            item.select(0, 3)

            keySequence(StandardKey.Copy)

            compare(ClipboardUtils.text, "Hey")
        }

        // Copying quoted text intentionally emits Markdown quote prefixes,
        // even for a partial selection. The prefixes
        // are synthesized for the clipboard; they are not document characters.
        function test_copyQuotePreservesMarkdownPrefixes_data() {
            return [
                {tag: "single-line", segments: [{text: "quoted", quoteLevel: 1}], expected: "> quoted"},
                {tag: "partial", segments: [{text: "quoted", quoteLevel: 1}], start: 2, end: 5, expected: "> ote"},
                {tag: "partial-backward", segments: [{text: "quoted", quoteLevel: 1}], start: 5, end: 2, expected: "> ote"},
                {tag: "paragraph-break", segments: [{text: "first\nsecond", quoteLevel: 1}], expected: "> first\n> second"},
                {tag: "soft-break", segments: [{text: "first\u2028second", quoteLevel: 1}], expected: "> first\n> second"},
                {tag: "blank-line", segments: [{text: "first\n\nlast", quoteLevel: 1}], expected: "> first\n> \n> last"},
                {tag: "nested", segments: [{text: "nested", quoteLevel: 2}], expected: "> > nested"},
                {tag: "quoted-code", segments: [{text: "first\nsecond", codeBlock: true, quoteLevel: 1}], expected: "> first\n> second"},
                {tag: "mixed-levels", segments: [
                    {text: "before"},
                    {text: "first", quoteLevel: 1, newBlock: true},
                    {text: "deep", quoteLevel: 2, newBlock: true},
                    {text: "last", quoteLevel: 1, newBlock: true},
                    {text: "after", newBlock: true}
                ], expected: "before\n> first\n> > deep\n> last\nafter"}
            ]
        }

        function test_copyQuotePreservesMarkdownPrefixes(data) {
            const item = createItem()
            item.segments = data.segments
            item.forceActiveFocus()
            if (data.start !== undefined)
                item.select(data.start, data.end)
            else
                item.selectAll()
            compare(item.selectedText, data.expected)
            compareSegmentFields(item.segments, data.segments)

            // Check both public copy routes, not just the selectedText getter.
            // Offscreen tests use a process-local clipboard.
            ClipboardUtils.setText("")
            verify(item.copySelection())
            compare(ClipboardUtils.text, data.expected)
            ClipboardUtils.setText("")
            keySequence(StandardKey.Copy)
            compare(ClipboardUtils.text, data.expected)
        }

        function test_selectAllShortcut() {
            const item = createItem()
            item.forceActiveFocus()

            keySequence(StandardKey.SelectAll)

            verify(item.selectedText.startsWith("Hey @Bob"))
        }

        function test_selectionClearsWhenFocusMovesOn() {
            const item = createItem()
            const other = createStyledTemporary(focusSinkComponent, root)
            item.forceActiveFocus()
            item.select(0, 3)

            other.forceActiveFocus()

            compare(item.selectedText, "")
        }

        function test_persistentSelectionSurvivesFocusLoss() {
            const item = createItem()
            const other = createStyledTemporary(focusSinkComponent, root)
            item.persistentSelection = true
            item.forceActiveFocus()
            item.select(0, 3)

            other.forceActiveFocus()

            compare(item.selectedText, "Hey")
        }

        // Code blocks ///////////////////////////////////////////////////////

        readonly property var codeSegments: [
            { text: "Before" },
            { text: "let x = 1\nlet y = 2", codeBlock: true },
            { text: "After" } // no newBlock: a code block always ends its paragraph
        ]

        function test_codeBlockIsFramedAndSetApart() {
            const item = createItem()
            item.segments = codeSegments

            const frames = item.codeBlockRects()
            compare(frames.length, 1)
            const frame = frames[0]
            const padding = item.appearance.codeBlockPadding

            compare(frame.x, 0)
            // Hugs the code rather than taking the full width.
            verify(frame.width > 2 * padding && frame.width < item.width / 2,
                   "frame width " + frame.width)
            // One line of text, then a gap of one padding before the frame.
            fuzzyCompare(frame.y, item.appearance.lineHeight + padding, 1)

            // The code starts one padding inside the frame...
            const codeStart = "Before".length + 1
            compare(item.positionAt(padding + 1, frame.y + padding + 2), codeStart)
            // ...and the paragraph after it one padding below.
            compare(item.positionAt(1, frame.y + frame.height + padding + 2),
                    codeStart + "let x = 1\nlet y = 2".length + 1)
        }

        function test_codeBlockKeepsItsLines() {
            const item = createItem()
            item.segments = codeSegments

            item.selectAll()

            compare(item.selectedText, "Before\nlet x = 1\nlet y = 2\nAfter")
        }

        function test_codeBlockUsesTheCodeFont() {
            const item = createItem()

            item.segments = [{ text: "iiiiiiiiii", codeBlock: true }]
            const narrow = item.codeBlockRects()[0].width
            item.segments = [{ text: "WWWWWWWWWW", codeBlock: true }]
            const wide = item.codeBlockRects()[0].width

            // Within glyph side bearings; a proportional font is ~100px apart.
            verify(Math.abs(narrow - wide) <= 2, "code is not monospaced: " + narrow + " vs " + wide)
        }

        // The first block's top margin and the last one's bottom margin are
        // not laid out, so a code block at either end needs the root frame.
        function test_codeBlockAloneIsPaddedAllRound() {
            const item = createItem()
            item.segments = [{ text: "code", codeBlock: true }]

            const frame = item.codeBlockRects()[0]
            compare(frame.y, 0)
            fuzzyCompare(frame.height, item.contentHeight, 1)
        }

        function test_quotedCodeBlock() {
            const item = createItem()
            item.segments = [
                { text: "Quoted", quoteLevel: 1 },
                { text: "code", codeBlock: true, quoteLevel: 1 }
            ]

            const frame = item.codeBlockRects()[0]
            compare(frame.x, item.appearance.quoteBarWidth + item.appearance.quoteSpacing)

            const bars = item.quoteBarRects()
            compare(bars.length, 1)
            fuzzyCompare(bars[0].y + bars[0].height, frame.y + frame.height, 1)
        }

        // Holds on both scene graph backends: the GPU one draws the rounded
        // frame, the software one (offscreen tests) the square fallback.
        function test_codeBlockFrameIsPainted() {
            const item = createItem()
            item.segments = codeSegments
            item.appearance.codeBackground = "lime"
            item.appearance.codeBorderColor = "red"

            const frame = item.codeBlockRects()[0]
            const image = grabImage(item)

            // Inside the padding, left of the text: background.
            verify(colourShare(image, Qt.rect(frame.x + 3, frame.y + frame.height / 2 - 1, 3, 3),
                               Qt.color("lime")) > 0.9, "no frame background")
            // The top edge, away from the rounded corners: border.
            verify(colourShare(image, Qt.rect(frame.x + 10, frame.y, 10, 1),
                               Qt.color("red")) > 0.9, "no frame border")
            // Right of the frame: nothing.
            compare(colourShare(image, Qt.rect(frame.x + frame.width + 2, frame.y + 4, 10, 10),
                                Qt.color("lime")), 0)
        }

        // Line breaks inside a single code segment stay inside its one frame.
        function test_multilineCodeSegmentHasOneFrame() {
            const item = createItem()
            item.segments = [{ text: "Before" },
                         { text: "let x = 1\nlet y = 2", codeBlock: true },
                         { text: "After" }]

            const frames = item.codeBlockRects()
            compare(frames.length, 1)

            const padding = item.appearance.codeBlockPadding
            compare(item.positionAt(padding + 1, frames[0].y + padding + 2), "Before".length + 1)
            verify(frames[0].height > 2 * padding + 20, "frame does not span both lines")
        }

        function test_adjacentCodeSegmentsHaveSeparateFrames_data() {
            return [{tag: "unquoted", quoteLevel: 0}, {tag: "quoted", quoteLevel: 1}]
        }

        function test_adjacentCodeSegmentsHaveSeparateFrames(data) {
            const item = createItem()
            item.segments = [
                {text: "first much wider code", codeBlock: true, quoteLevel: data.quoteLevel},
                {text: "second", codeBlock: true, quoteLevel: data.quoteLevel},
                {text: "third", codeBlock: true, quoteLevel: data.quoteLevel}
            ]
            const frames = item.codeBlockRects()
            compare(frames.length, 3)
            verify(frames[0].width > frames[1].width, "each frame must hug its own content")
            for (let i = 1; i < frames.length; ++i) {
                const gap = frames[i].y - frames[i - 1].y - frames[i - 1].height
                fuzzyCompare(gap, item.appearance.codeBlockPadding, 1)
                fuzzyCompare(frames[i].height, frames[0].height, 1)
            }
            compare(item.quoteBarRects().length, data.quoteLevel ? 1 : 0)
            item.appearance.codeBackground = "lime"
            const image = grabImage(item)
            for (const frame of frames) {
                verify(colourShare(image, Qt.rect(frame.x + 2, frame.y + frame.height - 5,
                                                  frame.width - 4, 1), Qt.color("lime")) > 0.8,
                       "each code frame must be painted")
            }
            for (let i = 1; i < frames.length; ++i) {
                const previousBottom = frames[i - 1].y + frames[i - 1].height
                const middle = (previousBottom + frames[i].y) / 2
                compare(colourShare(image, Qt.rect(frames[i].x + 5, middle, 10, 1), Qt.color("lime")), 0,
                        "the gap between fences must not be filled")
            }
            item.selectAll()
            const prefix = data.quoteLevel ? "> " : ""
            compare(item.selectedText, prefix + "first much wider code\n" + prefix + "second\n" + prefix + "third")
        }

        function test_emojiInCodeIsNotEnlarged() {
            const item = createItem()
            item.appearance.emojiOnlyPixelSize = 40
            item.segments = [{ text: "🎉", codeBlock: true }]

            verify(!item.emojiOnly)
            verify(item.contentHeight < 40, "code emoji enlarged: " + item.contentHeight)
        }

        // Quotes /////////////////////////////////////////////////////////////

        function test_quoteAndCodeBoundarySpacing_data() {
            const cases = [
                {tag: "text-quote", first: {}, second: {quoteLevel: 1}, gap: true},
                {tag: "quote-text", first: {quoteLevel: 1}, second: {}, gap: true},
                {tag: "within-quote", first: {quoteLevel: 1}, second: {quoteLevel: 1}, gap: false},
                {tag: "nested-quote", first: {quoteLevel: 1}, second: {quoteLevel: 2}, gap: true},
                {tag: "leave-nested-quote", first: {quoteLevel: 2}, second: {quoteLevel: 1}, gap: true},
                {tag: "quote-code", first: {quoteLevel: 1}, second: {codeBlock: true}, gap: true},
                {tag: "code-quote", first: {codeBlock: true}, second: {quoteLevel: 1}, gap: true},
                {tag: "within-quote-enter-code", first: {quoteLevel: 1}, second: {quoteLevel: 1, codeBlock: true}, gap: true},
                {tag: "within-quote-leave-code", first: {quoteLevel: 1, codeBlock: true}, second: {quoteLevel: 1}, gap: true},
                {tag: "quoted-code-text", first: {quoteLevel: 1, codeBlock: true}, second: {}, gap: true},
                {tag: "text-quoted-code", first: {}, second: {quoteLevel: 1, codeBlock: true}, gap: true},
                {tag: "separate-code", first: {codeBlock: true}, second: {codeBlock: true}, gap: true},
                {tag: "plain-paragraphs", first: {}, second: {}, gap: false}
            ]
            const rows = []
            for (const data of cases) {
                for (const padding of [8, 12])
                    rows.push(Object.assign({}, data, {tag: data.tag + "-" + padding, padding: padding}))
            }
            return rows
        }

        function test_quoteAndCodeBoundarySpacing(data) {
            const firstSegment = Object.assign({text: "first"}, data.first)
            const secondSegment = Object.assign({text: "second", newBlock: true}, data.second)
            function measure(segments) {
                const item = createItem()
                item.appearance.codeBlockPadding = data.padding
                item.segments = segments
                return item.contentHeight
            }
            const standaloneHeight = measure([firstSegment]) + measure([secondSegment])
            const combinedHeight = measure([firstSegment, secondSegment])
            fuzzyCompare(combinedHeight - standaloneHeight, data.gap ? data.padding : 0, 1)
        }

        function test_quoteSpacingPreservesBlankLinesAndNoOuterGap() {
            const item = createItem()
            item.segments = [{text: "first\n\nlast", quoteLevel: 1}]
            fuzzyCompare(item.contentHeight, 3 * item.appearance.lineHeight, 1)
            item.segments = [{text: "before"}, {text: "first\n\nlast", quoteLevel: 1, newBlock: true},
                         {text: "after", newBlock: true}]
            fuzzyCompare(item.contentHeight, 5 * item.appearance.lineHeight + 2 * item.appearance.codeBlockPadding, 1)
            fuzzyCompare(item.quoteBarRects()[0].height, 3 * item.appearance.lineHeight, 1)
            item.selectAll()
            compare(item.selectedText, "before\n> first\n> \n> last\nafter")
        }

        function test_quoteSegmentsGetOneBar() {
            const item = createItem()
            item.segments = root.quoteSegments

            const bars = item.quoteBarRects()
            compare(bars.length, 1)
            compare(bars[0].x, 0)
            compare(bars[0].width, item.appearance.quoteBarWidth)
            // Two quoted paragraphs, one line each, between two unquoted ones.
            fuzzyCompare(bars[0].y, item.appearance.lineHeight + item.appearance.codeBlockPadding, 1)
            fuzzyCompare(bars[0].height, 2 * item.appearance.lineHeight, 1)
        }

        function test_quoteBarIsPainted() {
            const item = createItem()
            item.segments = root.quoteSegments
            item.appearance.quoteBarColor = "red"

            const bar = item.quoteBarRects()[0]
            const image = grabImage(item)

            // Inset by a pixel: edges are antialiased against the background.
            verify(colourShare(image, Qt.rect(bar.x + 1, bar.y + 1, 1, bar.height - 2),
                               Qt.color("red")) > 0.9, "no bar painted")
            compare(colourShare(image, Qt.rect(0, 0, bar.width, item.appearance.lineHeight - 1),
                                Qt.color("red")), 0)
        }

        function test_quotedTextIsIndented() {
            const item = createItem()
            item.segments = root.quoteSegments

            // The bar column holds no text: a hit there lands on the first
            // character of the quoted line, not inside it.
            const quotedStart = "Before the quote".length + 1
            compare(item.positionAt(1, item.quoteBarRects()[0].y + item.appearance.lineHeight / 2), quotedStart)
        }

        function test_nestedQuotesGetABarPerLevel() {
            const item = createItem()
            item.segments = [
                { text: "Outer", quoteLevel: 1 },
                { text: "Inner", newBlock: true, quoteLevel: 2 },
                { text: "Outer again", newBlock: true, quoteLevel: 1 }
            ]

            const bars = item.quoteBarRects()
            compare(bars.length, 2)

            const outer = bars.find(b => b.x === 0)
            const inner = bars.find(b => b.x > 0)
            verify(!!outer && !!inner)
            fuzzyCompare(outer.height, 3 * item.appearance.lineHeight + 2 * item.appearance.codeBlockPadding, 1)
            fuzzyCompare(inner.height, item.appearance.lineHeight, 1)
            compare(inner.x, item.appearance.quoteBarWidth + item.appearance.quoteSpacing)
        }

        function test_barWidthChangeNeedsNoNewContent() {
            const item = createItem()
            item.segments = root.quoteSegments
            const before = item.positionAt(item.appearance.quoteBarWidth + item.appearance.quoteSpacing + 1,
                                           item.quoteBarRects()[0].y + item.appearance.lineHeight / 2)

            item.appearance.quoteBarWidth = 5

            compare(item.quoteBarRects()[0].width, 5)
            // The quoted text moved right with the wider bar.
            compare(item.positionAt(item.appearance.quoteBarWidth + item.appearance.quoteSpacing + 1,
                                    item.quoteBarRects()[0].y + item.appearance.lineHeight / 2), before)
        }

        // The point of keeping quotes in the one document: a drag runs through
        // a quote like any other paragraph, and the copy keeps its markers.
        function test_dragSelectionRunsThroughQuote() {
            const item = createItem()
            item.segments = root.quoteSegments

            mousePress(item, 2, item.appearance.lineHeight * 0.5, Qt.LeftButton)
            mouseMove(item, 100, item.appearance.lineHeight * 2)
            mouseMove(item, 300, item.contentHeight - item.appearance.lineHeight / 2)
            mouseRelease(item, 300, item.contentHeight - item.appearance.lineHeight / 2, Qt.LeftButton)

            compare(item.selectedText,
                    "Before the quote\n> Quoted one with a link\n> Quoted two\nAfter the quote")
        }

        function test_linkInsideQuoteActivates() {
            const item = createItem()
            item.segments = root.quoteSegments
            const spy = createStyledTemporary(
                          Qt.createComponent("QtTest", "SignalSpy"), root,
                          { target: item, signalName: "linkActivated" })

            const y = item.quoteBarRects()[0].y + item.appearance.lineHeight / 2
            let linkX = -1
            for (let x = 0; x < item.width; x += 2) {
                if (item.linkAt(x, y) === "https://status.app") {
                    linkX = x
                    break
                }
            }
            verify(linkX > item.appearance.quoteBarWidth + item.appearance.quoteSpacing, "no link inside the quote")

            mouseClick(item, linkX, y, Qt.LeftButton)

            compare(spy.count, 1)
        }

        // The case that matters: a press, a drag and a release, delivered as
        // real events rather than by calling select() directly.
        function test_selectByMouseDrag() {
            const item = createItem()

            mousePress(item, 4, 8, Qt.LeftButton)
            mouseMove(item, 120, 8)
            mouseMove(item, 200, 8)
            mouseRelease(item, 200, 8, Qt.LeftButton)

            verify(item.selectedText.length > 0,
                   "drag produced no selection: '" + item.selectedText + "'")
            verify(item.selectionStart !== item.selectionEnd)
        }

        function test_doubleClickSelectsWord() {
            const item = createItem()

            mouseDoubleClickSequence(item, 10, 8, Qt.LeftButton)

            compare(item.selectedText, "Hey")
        }

        function test_multiClickCycleRepeats() {
            const item = createItem()
            item.segments = [{text: "hello world foo"}]
            const expected = ["", "hello", "hello world foo", "", "", "hello", "hello world foo", ""]
            for (const text of expected) {
                mouseClick(item, 2, 11)
                compare(item.selectedText, text)
            }
        }

        function test_nativeDoubleClickThenTripleAndFourth() {
            const item = createItem()
            item.segments = [{text: "hello world foo"}]
            mouseDoubleClickSequence(item, 2, 11)
            compare(item.selectedText, "hello")
            mouseClick(item, 2, 11)
            compare(item.selectedText, "hello world foo")
            mouseClick(item, 2, 11)
            compare(item.selectedText, "")
        }

        function test_tripleClickLogicalLine_data() {
            return [
                {tag: "paragraph-first", segments: [{text: "first line\nsecond line"}], line: 0, expected: "first line"},
                {tag: "paragraph-second", segments: [{text: "first line\nsecond line"}], line: 1, expected: "second line"},
                {tag: "soft-break", segments: [{text: "first line\u2028second line"}], line: 1, expected: "second line"},
                {tag: "wrapped", segments: [{text: "hello world foo bar baz"}], line: 0, expected: "hello world foo bar baz", width: 70},
                {tag: "formatted", segments: [{text: "hello "}, {text: "world", bold: true}, {text: " foo", italic: true}], line: 0, expected: "hello world foo"},
                {tag: "code-first", segments: [{text: "first line\nsecond line", codeBlock: true}], line: 0, expected: "first line", code: true},
                {tag: "code-second", segments: [{text: "first line\nsecond line", codeBlock: true}], line: 1, expected: "second line", code: true},
                {tag: "quote", segments: [{text: "quoted line", quoteLevel: 1}], line: 0, expected: "> quoted line"},
                {tag: "emoji", segments: [{text: "hello 👨‍👩‍👧 world"}], line: 0, expected: "hello 👨‍👩‍👧 world"}
            ]
        }

        function test_tripleClickLogicalLine(data) {
            const item = createItem()
            item.segments = data.segments
            if (data.width)
                item.width = data.width
            let x = 15
            let y = item.appearance.lineHeight * (data.line + 0.5)
            if (data.code) {
                const frame = item.codeBlockRects()[0]
                const lineHeight = (frame.height - 2 * item.appearance.codeBlockPadding) / 2
                y = frame.y + item.appearance.codeBlockPadding + (data.line + 0.5) * lineHeight
            }
            for (let i = 0; i < 3; ++i)
                mouseClick(item, x, y)
            compare(item.selectedText, data.expected)
        }

        function test_multiClickSelectionDoesNotActivateLink() {
            const item = createItem()
            item.segments = [{text: "hello world", href: "https://status.app"}]
            const spy = createStyledTemporary(Qt.createComponent("QtTest", "SignalSpy"), root,
                                               {target: item, signalName: "linkActivated"})
            for (let i = 0; i < 4; ++i)
                mouseClick(item, 2, 11)
            compare(spy.count, 1, "only the initial single click may activate the link")
            compare(item.selectedText, "")
        }

        function test_multiClickResetsWhenPointerMovesAway() {
            const item = createItem()
            item.segments = [{text: "hello world"}]
            mouseClick(item, 2, 11)
            const secondWord = xOf(item, 11, 6) + 2
            mouseClick(item, secondWord, 11)
            compare(item.selectedText, "")
            mouseClick(item, secondWord, 11)
            compare(item.selectedText, "world")
        }

        function test_multiClickResetsAfterTimeout() {
            const item = createItem()
            item.segments = [{text: "hello world"}]
            mouseClick(item, 2, 11)
            wait(Qt.styleHints.mouseDoubleClickInterval + 30)
            mouseClick(item, 2, 11)
            compare(item.selectedText, "")
            mouseClick(item, 2, 11)
            compare(item.selectedText, "hello")
        }

        function test_nonSelectableMultiClickDoesNotSelect() {
            const item = createItem()
            item.selectable = false
            for (let i = 0; i < 4; ++i)
                mouseClick(item, 2, 11)
            compare(item.selectedText, "")
        }

        // The regression that started this: inside a Flickable the drag was
        // being stolen, so selection worked only via selectAll().
        function test_selectByMouseDragInsideFlickable() {
            const flickable = createStyledTemporary(flickableComponent, root)
            verify(!!flickable)

            const item = flickable.textItem
            verify(!!item)
            verify(item.contentHeight > 0)

            mousePress(item, 4, 8, Qt.LeftButton)
            mouseMove(item, 120, 8)
            mouseMove(item, 220, 8)
            mouseRelease(item, 220, 8, Qt.LeftButton)

            verify(item.selectedText.length > 0,
                   "drag inside a Flickable produced no selection")
        }

        function test_dragIsIgnoredWhenNotSelectable() {
            const item = createItem()
            item.selectable = false

            mousePress(item, 4, 8, Qt.LeftButton)
            mouseMove(item, 200, 8)
            mouseRelease(item, 200, 8, Qt.LeftButton)

            compare(item.selectedText, "")
        }

        function test_cachedDecorationsFollowAppearanceAndReplacement() {
            const item = createItem()
            item.segments = [{text: "WWWWWW", codeBlock: true, quoteLevel: 1}]
            item.appearance.quoteBarColor = "lime"
            item.appearance.codeBackground = "blue"
            item.appearance.codeBorderColor = "blue"
            let image = grabImage(item)
            const bar = item.quoteBarRects()[0]
            const frame = item.codeBlockRects()[0]
            verify(colourShare(image, bar, Qt.color("lime")) > 0.5)
            verify(colourShare(image, frame, Qt.color("blue")) > 0.5)
            item.select(0, 3)
            image = grabImage(item)
            verify(colourShare(image, bar, Qt.color("lime")) > 0.5)
            item.clearSelection()
            item.appearance.quoteBarColor = "red"
            item.appearance.codeBackground = "yellow"
            image = grabImage(item)
            verify(colourShare(image, bar, Qt.color("red")) > 0.5)
            verify(colourShare(image, frame, Qt.color("yellow")) > 0.5)
            item.segments = [{text: "plain"}]
            image = grabImage(item)
            compare(colourShare(image, Qt.rect(0, 0, item.width, item.contentHeight), Qt.color("yellow")), 0)
        }

        function compareSegmentFields(actual, expected) {
            compare(actual.length, expected.length)
            for (let i = 0; i < expected.length; ++i) {
                for (const key of Object.keys(expected[i]))
                    compare(actual[i][key], expected[i][key])
            }
        }

        function test_typedSegmentCopyPreservesMissingClassification() {
            const item = createItem()
            item.segments = [{text: "😎"}]
            verify(item.emojiOnly)
            compare(item.segments[0].hasSourceClassification, false)
            item.segments = item.segments.map(segment => Object.assign({}, segment))
            verify(item.emojiOnly)
            item.segments = [{text: "😎", sourceIsOnlyEmoji: false}]
            compare(item.emojiOnly, false)
            item.segments = item.segments.map(segment => Object.assign({}, segment))
            compare(item.emojiOnly, false)
        }

        function test_typedInitialPropertiesPreserveSegments() {
            initialSegments = [{text: "hello", bold: true, mention: true},
                               {text: "world", newBlock: true, code: true}]
            const item = createStyledTemporary(itemComponent, root,
                {segments: initialSegments})
            verify(!!item)
            compare(item.segments[0].text, "hello")
            compare(item.segments[0].bold, true)
            verify(item.segments[0].mention)
            compare(item.segments[1].text, "world")
            compare(item.segments[1].code, true)
            item.selectAll()
            compare(item.selectedText, "hello\nworld")
        }

        function test_segmentPropertyRoundTrip() {
            const item = createItem()
            item.segments = [{text: "😎", sourceIsOnlyEmoji: false, bold: false},
                         {text: "link", href: "https://status.app", mention: true,
                          italic: true, underline: true,
                          strikethrough: true, newBlock: true, quoteLevel: 2},
                         {text: "code", code: true},
                         {text: "block", codeBlock: true}]
            const segments = item.segments
            compare(segments.length, 4)
            compare(segments[0].sourceIsOnlyEmoji, false)
            compare(segments[0].bold, false)
            compare(segments[0].italic, false)
            compare(segments[1].href, "https://status.app")
            verify(segments[1].mention)
            compare(segments[1].quoteLevel, 2)
            verify(segments[1].italic && segments[1].underline && segments[1].strikethrough)
            verify(segments[1].newBlock && segments[2].code && segments[3].codeBlock)
            item.segments = segments
            compare(item.segments[1].text, "link")
        }

        function test_plainFastPathResetsDecorationState() {
            const item = createItem()
            item.segments = [{text: "plain"}]
            const plainHeight = item.contentHeight
            item.segments = [{text: "code", codeBlock: true, quoteLevel: 2}]
            verify(item.codeBlockRects().length > 0)
            verify(item.quoteBarRects().length > 0)
            item.segments = [{text: "plain"}]
            compare(item.contentHeight, plainHeight)
            compare(item.codeBlockRects().length, 0)
            compare(item.quoteBarRects().length, 0)
            item.appearance.quoteBarWidth = 5
            item.appearance.quoteSpacing = 15
            item.appearance.codeBlockPadding = 12
            compare(item.contentHeight, plainHeight)
            item.segments = [{text: "code", codeBlock: true, quoteLevel: 2}]
            verify(item.codeBlockRects().length > 0)
            compare(item.quoteBarRects()[0].width, 5)
            verify(item.contentHeight > plainHeight + 12)
            item.segments = [{text: "plain"}]
            compare(item.contentHeight, plainHeight)
        }

        function test_replacementPublishesFinalGeometryImmediately() {
            const item = createItem()
            item.segments = [{text: "quoted", quoteLevel: 1},
                         {text: "first\nsecond", codeBlock: true},
                         {text: "end", newBlock: true}]
            const decoratedHeight = item.contentHeight
            verify(decoratedHeight > 4 * item.appearance.lineHeight)
            compare(item.implicitHeight, decoratedHeight)
            item.segments = [{text: "https://status.app", href: "https://status.app"}]
            verify(item.contentHeight < decoratedHeight)
            compare(item.implicitHeight, item.contentHeight)
            compare(item.linkAt(5, 8), "https://status.app")
            compare(item.quoteBarRects().length, 0)
            compare(item.codeBlockRects().length, 0)
        }

        function test_clickOnLinkActivatesItAndDoesNotSelect() {
            const item = createItem()
            const spy = createStyledTemporary(
                          Qt.createComponent("QtTest", "SignalSpy"), root,
                          { target: item, signalName: "linkActivated" })

            // Find a pixel covered by the mention anchor.
            let linkX = -1
            for (let x = 0; x < item.width; x += 2) {
                if (item.linkAt(x, 8) === "//0xc0ffee") {
                    linkX = x
                    break
                }
            }
            verify(linkX >= 0, "no mention anchor found on the first line")

            mousePress(item, linkX, 8, Qt.LeftButton)
            mouseRelease(item, linkX, 8, Qt.LeftButton)

            compare(spy.count, 1)
            compare(item.selectedText, "")
        }
    }
}
