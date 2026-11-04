import QtQuick
import QtTest
import "ChatTextTestUtils.js" as ChatTextTestUtils
import StatusQ
import StatusQ.Components

Item {
    id: root
    width: 1000
    height: 160

    FontMetrics { id: referenceMetrics }
    Text { id: referenceEmoji; textFormat: Text.RichText; visible: false }

    Component {
        id: itemComponent
        ChatSingleLineTextItem {
            appearance: ChatTextAppearance {
                font.pixelSize: 16
            }

            width: 900
        }
    }
    Component {
        id: inputFixture
        Item {
            width: 400
            height: 100
            property alias textItem: preview
            property alias mouseArea: mouseArea
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
            }
            ChatSingleLineTextItem {
                appearance: ChatTextAppearance {
                    font.pixelSize: 16
                }

                id: preview
                width: parent.width
                segments: [{text: "https://status.app", href: "https://status.app"}]
            }
        }
    }
    Component { id: clickSpy; SignalSpy { signalName: "clicked" } }
    TestCase {
        id: testCase

        readonly property var appearanceProperties: ChatTextTestUtils.appearanceProperties
        property list<chatTextSegment> initialSegments
        function createStyledTemporary(component, parent, properties) {
            return ChatTextTestUtils.create(testCase, component, parent, properties)
        }
        name: "ChatSingleLineTextItem"
        when: windowShown

        function create(text, properties) {
            const item = createStyledTemporary(itemComponent, root, properties || {})
            verify(item)
            item.segments = MarkdownUtils.toChatTextSegments(text, {})
            return item
        }

        function test_semanticForegroundPrecedence() {
            const item = create("")
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
                verify(colorPixels(image, Qt.color(color)) > 2, "Missing semantic foreground " + color)
            item.appearance.quoteColor = "magenta"
            item.appearance.mentionColor = "yellow"
            image = grabImage(item)
            for (const color of ["magenta", "blue", "yellow"])
                verify(colorPixels(image, Qt.color(color)) > 2, "Missing updated foreground " + color)
        }

        function test_flatten_data() {
            return [
                {tag: "line breaks", source: "first\nsecond", expected: "first second"},
                {tag: "quote", source: "before\n> quoted\nafter", expected: "before > quoted after"},
                {tag: "quote continuation", source: "> outer\n> > inner", expected: "> outer > inner"},
                {tag: "fence", source: "before\n```js\none\ntwo\n```\nafter", expected: "before js one two after"},
                {tag: "separate fences", source: "```\none\n```\n```\ntwo\n```", expected: "one two"},
                {tag: "formatting", source: "**bold** *italic* ~~gone~~ `code`", expected: "bold italic gone code"},
                // Deliberate: every line break becomes one space and whitespace
                // is kept as written, so blank lines remain visible as gaps.
                {tag: "blank line", source: "first\n\nsecond", expected: "first  second"},
                {tag: "leading line breaks", source: "\n\nlead", expected: "  lead"},
                {tag: "trailing line breaks", source: "trail\n\n", expected: "trail  "},
                {tag: "spaces around line breaks", source: "a  \n\n  b", expected: "a      b"},
                {tag: "blank line after inline fence", source: "x\n```code```\n\ny", expected: "x code  y"}
            ]
        }
        function test_flatten(data) {
            const item = create(data.source)
            compare(item.displayedText, data.expected)
            verify(!item.truncated)
            verify(item.contentHeight > 0)
        }
        function test_resizeAndRestore() {
            const item = create("A **bold** preview with `monospace` and a long suffix")
            const full = item.displayedText
            const naturalWidth = item.implicitWidth
            const height = item.contentHeight
            item.width = 140
            verify(item.truncated)
            verify(item.displayedText.endsWith("…"))
            compare(item.implicitWidth, naturalWidth)
            verify(item.contentHeight <= height + 1)
            item.width = 900
            compare(item.displayedText, full)
            verify(!item.truncated)
            item.width = 0
            compare(item.displayedText, "")
            verify(item.truncated)
            item.width = 1
            compare(item.displayedText, "")
            item.width = 900
            compare(item.displayedText, full)
        }
        function test_unicode_data() {
            return [
                {tag: "family", cluster: "👨‍👩‍👧‍👦"},
                {tag: "skin", cluster: "👍🏽"},
                {tag: "flag", cluster: "🇵🇱"},
                {tag: "keycap", cluster: "1️⃣"},
                {tag: "combining", cluster: "e\u0301"},
                {tag: "arabic", cluster: "مرحبا"}
            ]
        }
        function test_unicode(data) {
            const item = create(data.cluster.repeat(100))
            for (let width = 1; width < 240; width += 7) {
                item.width = width
                const display = item.displayedText
                verify(display === "" || display.endsWith("…"))
                const prefix = display.slice(0, -1)
                // The first five samples each consist of one grapheme cluster.
                if (data.tag !== "arabic")
                    compare(prefix.length % data.cluster.length, 0)
            }
        }
        function test_mixedFormatsFit() {
            const original = [
                {text: "Bold WWWWW ", bold: true},
                {text: "monospace code ", code: true},
                {text: "👨‍👩‍👧‍👦 combining e\u0301 and suffix"}
            ]
            const item = create("", {segments: original})
            item.segments = original
            for (let width = 15; width < 260; width += 9) {
                item.width = width
                verify(item.truncated)
                const text = item.displayedText
                if (!text.length)
                    continue
                let remaining = text.length - 1
                let visible = []
                for (const segment of original) {
                    const length = Math.min(remaining, segment.text.length)
                    if (length > 0)
                        visible.push(Object.assign({}, segment, {text: segment.text.slice(0, length)}))
                    remaining -= length
                }
                visible.push({text: "…"})
                const measurement = createStyledTemporary(itemComponent, root, {
                    segments: visible
                })
                verify(measurement.implicitWidth <= width + 0.01,
                       "Formatted display must fit width " + width)
                measurement.destroy()
            }
        }
        function test_nestedQuoteSegments() {
            const item = create("")
            item.segments = [
                {text: "outer", quoteLevel: 1},
                {text: "inner", quoteLevel: 2, newBlock: true},
                {text: "back", quoteLevel: 1, newBlock: true}
            ]
            compare(item.displayedText, "> outer > > inner > back")
        }
        function colorPixels(image, target) {
            let pixels = 0
            for (let x = 0; x < image.width; ++x) {
                for (let y = 0; y < image.height; ++y) {
                    const color = image.pixel(x, y)
                    if (color.a > 0.5 && Math.abs(color.r - target.r) < 0.15
                            && Math.abs(color.g - target.g) < 0.15
                            && Math.abs(color.b - target.b) < 0.15)
                        pixels++
                }
            }
            return pixels
        }
        function test_paintsFormattingAndAppearanceChanges() {
            const item = create("", {width: 300, quoteColor: "red", codeBackground: "blue", mentionBackground: "lime"})
            item.segments = [
                {text: "mention", href: "https://status.app", quoteLevel: 1, mention: true},
                {text: "code", codeBlock: true}
            ]
            let image = grabImage(item)
            verify(colorPixels(image, Qt.color("red")) > 2)
            verify(colorPixels(image, Qt.color("lime")) > 20)
            verify(colorPixels(image, Qt.color("blue")) > 20)
            item.appearance.quoteColor = "magenta"
            item.appearance.codeBackground = "yellow"
            image = grabImage(item)
            compare(colorPixels(image, Qt.color("red")), 0)
            compare(colorPixels(image, Qt.color("blue")), 0)
            verify(colorPixels(image, Qt.color("magenta")) > 2)
            verify(colorPixels(image, Qt.color("yellow")) > 20)
        }
        // The horizontal extent of the painted text, in item coordinates.
        function inkExtent(item) {
            const image = grabImage(item)
            const scale = image.width / item.width
            const ink = Qt.color("red")
            let left = image.width, right = -1
            for (let x = 0; x < image.width; ++x) {
                for (let y = 0; y < image.height; ++y) {
                    const c = image.pixel(x, y)
                    if (c.a > 0.5 && Math.abs(c.r - ink.r) < 0.3 && c.g < 0.5 && c.b < 0.5) {
                        left = Math.min(left, x)
                        right = Math.max(right, x)
                        break
                    }
                }
            }
            verify(right >= 0, "the text must be painted")
            return {left: left / scale, right: (right + 1) / scale}
        }

        // A right-to-left paragraph sits at the right edge, as Text aligns it,
        // and stays there when a resize reuses the cached layout.
        function test_alignmentFollowsDirection_data() {
            return [
                {tag: "ltr", source: "Hello world", rtl: false},
                {tag: "arabic", source: "مرحبا بالعالم", rtl: true},
                {tag: "hebrew", source: "שלום עולם", rtl: true},
                {tag: "rtl-quote", source: "> مرحبا بالعالم", rtl: true},
                {tag: "rtl-with-ltr-words", source: "تم إصلاح Status في الإصدار", rtl: true},
                {tag: "ltr-with-rtl-words", source: "The greeting is مرحبا", rtl: false}
            ]
        }

        function test_alignmentFollowsDirection(data) {
            const item = create(data.source, {width: 400, color: "red", quoteColor: "red"})
            verify(!item.truncated)
            for (const width of [400, 500]) {
                item.width = width
                const ink = inkExtent(item)
                if (data.rtl) {
                    verify(ink.right > width - 6, `right edge ${ink.right} at width ${width}`)
                    verify(ink.left > width / 3, `left edge ${ink.left} at width ${width}`)
                } else {
                    verify(ink.left < 6, `left edge ${ink.left} at width ${width}`)
                    verify(ink.right < width * 2 / 3, `right edge ${ink.right} at width ${width}`)
                }
            }
        }

        function test_truncatedRightToLeftFillsFromTheRight() {
            const item = create("هذا رد طويل بما يكفي بحيث يجب على المعاينة قطعه وإضافة علامة الحذف في نهايته",
                                {width: 240, color: "red"})
            verify(item.truncated)
            const ink = inkExtent(item)
            verify(ink.right > item.width - 6, `right edge ${ink.right}`)
        }

        // A cut inside a cursive word keeps the last letter's joining form: a
        // zero-width joiner precedes the ellipsis, as in Text's eliding.
        function test_elisionKeepsCursiveJoining_data() {
            return [
                {tag: "arabic", source: "ب".repeat(200), joiner: true},
                {tag: "arabic-bold", source: "**" + "ب".repeat(200) + "**", joiner: true},
                {tag: "latin", source: "b".repeat(200), joiner: false}
            ]
        }

        function test_elisionKeepsCursiveJoining(data) {
            const item = create(data.source, {width: 200})
            verify(item.truncated)
            const shown = item.displayedText
            verify(shown.endsWith("\u2026"))
            compare(shown.endsWith("\u200D\u2026"), data.joiner)
            compare(shown.split("\u200D").length - 1, data.joiner ? 1 : 0)
        }

        function test_mixedDirection() {
            const item = create("مرحبا بالعالم **bold** [رابط طويل](https://status.app) نهاية", {width: 180})
            verify(item.truncated)
            verify(item.displayedText.endsWith("…"))
            item.width = 900
            verify(!item.truncated)
            verify(item.displayedText.includes("رابط طويل"))
        }
        function test_emptyAndExplicitSeparators() {
            const item = create("")
            compare(item.contentHeight, 0)
            compare(item.displayedText, "")
            verify(!item.truncated)
            item.segments = [{text: "a\r\nb\u2028c\u2029d"}]
            compare(item.displayedText, "a b c d")
            item.segments = []
            compare(item.displayedText, "")
            compare(item.contentHeight, 0)
        }
        function test_editedParticipatesInElision() {
            const item = create("message", {edited: true})
            compare(item.displayedText, "message (edited)")
            item.width = 70
            verify(item.truncated)
            verify(item.displayedText.endsWith("…"))
            item.width = 900
            compare(item.displayedText, "message (edited)")
            item.edited = false
            compare(item.displayedText, "message")
        }
        function test_fontAndFormattingChange() {
            const item = create("**MMMMMMMMMM** `iiiiiiiiii`", {width: 200})
            item.appearance.font.pixelSize = 40
            verify(item.truncated)
            item.appearance.font.pixelSize = 8
            verify(!item.truncated)
            item.width = 60
            item.appearance.codeFontFamily = "serif"
            verify(item.displayedText.endsWith("…"))
            item.appearance.linkColor = "red"
            item.appearance.codeBackground = "yellow"
            verify(item.contentHeight > 0)
        }
        function test_inputPassesThrough() {
            const fixture = createStyledTemporary(inputFixture, root)
            verify(fixture)
            const spy = createStyledTemporary(clickSpy, root, {target: fixture.mouseArea})
            verify(spy.valid)
            mouseClick(fixture.textItem, 10, 10)
            compare(spy.count, 1)
            const touch = touchEvent(fixture.textItem)
            touch.press(0, fixture.textItem, 10, 10).commit()
            touch.release(0, fixture.textItem, 10, 10).commit()
            compare(spy.count, 2)
            verify(!fixture.textItem.activeFocus)
        }
        function test_automaticEmojiSizeFollowsFont() {
            const item = create("😎😎")
            for (const family of ["sans-serif", "serif"]) {
                for (const size of [12, 24, 16]) {
                    item.appearance.font.family = family
                    item.appearance.font.pixelSize = size
                    referenceMetrics.font = item.appearance.font
                    referenceEmoji.font = item.appearance.font
                    referenceEmoji.text = '<span style="font-size: '
                        + Math.round(referenceMetrics.height) + 'px">😎😎</span>'
                    verify(Math.abs(item.implicitWidth - referenceEmoji.implicitWidth) <= 1,
                           "Emoji width must follow rounded font line height")
                }
            }
        }
        function test_emojiOnlyDoesNotEnlarge() {
            const item = create("😎😎")
            verify(item.contentHeight < 40)
        }
        function test_continuousResize() {
            const item = create("**Bold text** with a 👨‍👩‍👧‍👦 family and `code`, plus a long ending")
            for (const direction of [1, -1]) {
                for (let i = 20; i < 500; ++i) {
                    const width = direction === 1 ? i : 515 - i
                    item.width = width
                    verify(item.displayedText.length > 0)
                    verify(item.implicitWidth > 0)
                }
            }
        }
    }
}
