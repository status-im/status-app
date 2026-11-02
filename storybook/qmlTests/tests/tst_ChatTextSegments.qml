import QtQuick
import QtTest
import StatusQ

Item {
    id: root
    width: 1200
    height: 1000

    Component { id: documentComponent; ChatTextItem { width: 400; font.pixelSize: 16; lineHeight: 22 } }

    TestCase {
        name: "ChatTextSegments"
        when: windowShown

        function test_segmentsPreserveFormattingAndLiteralText() {
            const segments = MarkdownUtils.toChatTextSegments("**bold** & <text> `code`")
            compare(segments.map(r => r.text).join(""), "bold & <text> code")
            verify(segments[0].bold)
            verify(segments[segments.length - 1].code)
        }

        function test_sourceEmojiClassification_data() {
            return [
                {tag: "single", source: "😎", only: true},
                {tag: "whitespace", source: " \n😎 🎉\n ", only: true},
                {tag: "zwj-skin-tone", source: "👨‍👩‍👧 👍🏽", only: true},
                {tag: "keycaps", source: "1️⃣ #️⃣ *️⃣", only: true},
                {tag: "flags", source: "🇵🇱 🇺🇦", only: true},
                {tag: "mixed", source: "Hello 😎", only: false},
                {tag: "bold", source: "**😎**", only: false},
                {tag: "italic", source: "*😎*", only: false},
                {tag: "strikeout", source: "~~😎~~", only: false},
                {tag: "quote", source: "> 😎", only: false},
                {tag: "link-label", source: "[😎](https://status.app)", only: false},
                {tag: "inline-code", source: "`😎`", only: false},
                {tag: "fenced-code", source: "```\n😎\n```", only: false},
                {tag: "empty", source: "", only: false},
                {tag: "whitespace-only", source: " \n ", only: false},
                {tag: "plain-digit", source: "1", only: false}
            ]
        }

        function test_sourceEmojiClassification(data) {
            const segments = MarkdownUtils.toChatTextSegments(data.source)
            if (segments.length)
                compare(segments[0].sourceIsOnlyEmoji, data.only)
            const item = createTemporaryObject(documentComponent, root, {
                segments: segments, emojiOnlyPixelSize: 20
            })
            verify(!!item)
            compare(item.emojiOnly, data.only)
            const height = item.contentHeight
            item.emojiOnlyPixelSize = 40
            if (data.only)
                verify(item.contentHeight > height, "emoji-only source must get extra enlargement")
            else
                compare(item.contentHeight, height, "markdown delimiters must disqualify extra enlargement")
            item.edited = true
            compare(item.emojiOnly, data.only, "the edited marker must not change source classification")
        }

        function test_sourceClassificationSurvivesStyleChanges() {
            const item = createTemporaryObject(documentComponent, root, {
                segments: MarkdownUtils.toChatTextSegments("😎"), emojiOnlyPixelSize: 40
            })
            verify(!!item)
            const height = item.contentHeight
            item.segments = item.segments.map(segment => Object.assign({}, segment, {bold: true, color: "red"}))
            verify(item.emojiOnly, "appearance changes must retain the original source classification")
            item.edited = true
            verify(item.emojiOnly)
            verify(item.contentHeight >= height)
            item.segments = MarkdownUtils.toChatTextSegments("**😎**")
            verify(!item.emojiOnly, "new markdown source must replace the previous classification")
        }

        function test_mentionsAndWalletLinks() {
            const key = "0x" + "a".repeat(130)
            const names = {}
            names[key] = "Alice"
            const segments = MarkdownUtils.toChatTextSegments("@" + key + " @0x00001 alice.eth", names)
            compare(segments[0].text, "@Alice")
            compare(segments[0].href, key)
            const everyone = segments.find(r => r.text === "@everyone")
            verify(!!everyone)
            verify(!everyone.href)
            verify(segments.some(r => r.href === "//send-via-personal-chat//alice.eth"))
        }

        function test_quoteAndCode() {
            const segments = MarkdownUtils.toChatTextSegments("> quoted\n> ```\n> a < b\n> ```\nafter")
            verify(segments.some(r => r.quoteLevel === 1 && r.text.indexOf("quoted") >= 0))
            const code = segments.find(r => r.codeBlock)
            verify(!!code)
            compare(code.text, "a < b")
            compare(code.quoteLevel, 1)
            verify(segments.some(r => r.quoteLevel === 0 && r.text.indexOf("after") >= 0))
        }

        function test_blockBoundaries_data() {
            return [
                {tag: "quote", source: "before\n> quoted\nafter", before: "before", body: "quoted"},
                {tag: "quote-blank-line", source: "before\n\n> quoted\nafter", before: "before\n", body: "quoted"},
                {tag: "code", source: "before\n```\ncode\n```\nafter", before: "before", body: "code"},
                {tag: "code-blank-line", source: "before\n\n```\ncode\n```\nafter", before: "before\n", body: "code"},
                {tag: "quoted-code", source: "> before\n> ```\n> code\n> ```\nafter", before: "before", body: "code"}
            ]
        }

        function test_blockBoundaries(data) {
            const segments = MarkdownUtils.toChatTextSegments(data.source)
            compare(segments.length, 3)
            compare(segments[0].text, data.before)
            compare(segments[1].text, data.body)
            compare(segments[2].text, "after")
        }

        function test_separateCodeFences_data() {
            return [
                {tag: "adjacent", source: "```\nfirst\n```\n```\nsecond\n```", code: ["first", "second"]},
                {tag: "blank-line", source: "```\nfirst\n```\n\n```\nsecond\n```", code: ["first", "second"]},
                {tag: "quoted", source: "> ```\n> first\n> ```\n> ```\n> second\n> ```", code: ["first", "second"]},
                {tag: "multiline", source: "```\nfirst\nline\n```\n```\nsecond\n```", code: ["first\nline", "second"]},
                {tag: "empty", source: "```\n```\n```\nsecond\n```", code: ["", "second"]}
            ]
        }

        function test_separateCodeFences(data) {
            const segments = MarkdownUtils.toChatTextSegments(data.source)
            compare(segments.filter(r => r.codeBlock).map(r => r.text), data.code)
            const item = createTemporaryObject(documentComponent, root, {segments: segments})
            verify(!!item)
            const frames = item.codeBlockRects()
            compare(frames.length, data.code.length)
            verify(frames[1].y - frames[0].y - frames[0].height >= item.codeBlockPadding - 1)
            item.selectAll()
            for (const code of data.code.filter(c => c.length > 0))
                verify(item.selectedText.indexOf(code) >= 0, "copy must preserve code content")
        }

    }
}
