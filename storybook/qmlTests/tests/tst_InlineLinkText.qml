import QtQuick
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import utils

import Storybook.Testing

Item {
    id: root
    width: 1000
    height: 1000
    readonly property string url: "https://status.app/example/destination"

    Component {
        id: textComponent
        StatusInlineLinkText {
            id: textItem
            width: 800
            height: contentHeight
            appearance: MessageTextAppearance { theme: textItem.Theme }
            sourceSegments: MarkdownUtils.toChatTextSegments("Before " + root.url + " after")
        }
    }
    Component { id: metricsComponent; TextMetrics {} }
    Component { id: spyComponent; SignalSpy { signalName: "linkActivated" } }
    Component { id: pageComponent; InlineLinkTextPage {} }

    TestCase {
        name: "InlineLinkText"
        when: windowShown

        function createText(data) {
            const item = createTemporaryObject(textComponent, root, {links: {[root.url]: data}})
            verify(item)
            return item
        }

        function test_variations_data() {
            return [
                {tag: "profile", data: {title: "JohnDoe.ETH"}, label: "JohnDoe.ETH", icons: 1},
                {tag: "community", data: {title: "Status App"}, label: "Status App", icons: 1},
                {tag: "channel", data: {title: "Status App", path: [{text: "# feedback-desktop"}]}, label: "Status App › # feedback-desktop", icons: 1},
                {tag: "channel-message", data: {title: "Status App", path: [{text: "# feedback-desktop"}], trailingIcons: ["chat"]}, label: "Status App › # feedback-desktop › ", icons: 2},
                {tag: "group-message", data: {title: "TravelHUB", trailingIcons: ["chat"]}, label: "TravelHUB › ", icons: 2},
                {tag: "channel-thread", data: {title: "Status App", path: [{text: "# feedback-desktop"}, {text: "Release summary", icon: "thread"}], trailingIcons: ["chat"]}, label: "Status App › # feedback-desktop › Release summary › ", icons: 3},
                {tag: "group-thread", data: {title: "TravelHUB", path: [{text: "Sierra Park", icon: "thread"}], trailingIcons: ["chat"]}, label: "TravelHUB › Sierra Park › ", icons: 3},
                {tag: "three-paths-two-icons", data: {title: "Status App", path: [{text: "General"}, {text: "# feedback"}, {text: "Release", icon: "thread"}], trailingIcons: ["chat", "messageActive"]}, label: "Status App › General › # feedback › Release ›  ", icons: 4}
            ]
        }

        function test_variations(data) {
            const item = createText(data.data)
            compare(item.text, "Before " + data.label + " after")
            compare(item.inlineIconRects.length, data.icons)
            item.selectAll()
            compare(item.selectedText, "Before " + root.url + " after")
            const spy = createTemporaryObject(spyComponent, root, {target: item})
            for (const icon of item.inlineIconRects) {
                const rect = icon.rect
                const x = rect.x + rect.width / 2
                const y = rect.y + rect.height / 2
                compare(item.linkAt(x, y), root.url)
                item.clearSelection()
                mouseClick(item, x, y)
                compare(spy.signalArguments[spy.count - 1][0], root.url)
            }
            compare(spy.count, data.icons)
        }

        function test_navigationAtMessageStart_data() {
            return [
                {tag: "first", source: root.url + " contact"},
                {tag: "quoted-first", source: "> " + root.url + " contact"},
                {tag: "middle", source: "Contact " + root.url + " here"}
            ]
        }

        function test_navigationAtMessageStart(data) {
            const item = createText({title: "michalc"})
            item.sourceSegments = MarkdownUtils.toChatTextSegments(data.source)
            const spy = createTemporaryObject(spyComponent, root, {target: item})
            const icon = item.inlineIconRects[0].rect
            const background = item.inlineLinkRects[0].rect
            const points = [Qt.point(icon.x + icon.width / 2, icon.y + icon.height / 2),
                            Qt.point(icon.x + icon.width + 12, background.y + background.height / 2)]
            for (const point of points) {
                compare(item.linkAt(point.x, point.y), root.url)
                mouseClick(item, point.x, point.y)
                compare(spy.signalArguments[spy.count - 1][0], root.url)
            }
            compare(spy.count, points.length)
        }

        function test_wrapAndPartialSelection() {
            const item = createText({title: "Status App", path: [{text: "# feedback-desktop"}, {text: "A long release thread title", icon: "thread"}], trailingIcons: ["chat", "messageActive"]})
            const originalHeight = item.contentHeight
            item.width = 160
            verify(item.contentHeight > originalHeight)
            compare(item.inlineIconRects.length, 4)
            for (const icon of item.inlineIconRects) {
                verify(icon.rect.x >= 0 && icon.rect.x + icon.rect.width <= item.width + 1)
                verify(icon.rect.y >= 0 && icon.rect.y + icon.rect.height <= item.contentHeight + 1)
            }
            item.selectAll()
            compare(item.selectedText, "Before " + root.url + " after")
            item.select(0, item.selectionEnd - 8)
            verify(!item.selectedText.includes("\u2003"))
            verify(!item.selectedText.includes("\u202f"))
            verify(!item.selectedText.includes("\u2060"))
            verify(item.selectedText.includes("Status App"))
            item.links = ({})
            compare(item.inlineIconRects.length, 0)
            compare(item.text, "Before " + root.url + " after")
        }

        function test_storybookGallery() {
            const page = createTemporaryObject(pageComponent, root, {width: 1000, height: 1000})
            verify(page)
            for (let i = 0; i < 8; ++i) {
                const item = findChild(page, "inlineLinkExample" + i)
                verify(item)
                verify(item.inlineIconRects.length >= 1)
            }
        }

        function test_storybookDestinations() {
            const page = createTemporaryObject(pageComponent, root, {width: 1000, height: 1000})
            verify(page)
            const activatedUrl = findChild(page, "inlineLinkActivatedUrl")
            const activatedPath = findChild(page, "inlineLinkActivatedPath")
            const expectedUrls = [page.profileUrl, page.communityUrl, page.channelUrl,
                                  page.channelMessageUrl, page.groupMessageUrl,
                                  page.channelThreadUrl, page.groupThreadUrl]
            for (let i = 0; i < expectedUrls.length; ++i) {
                const item = findChild(page, "inlineLinkExample" + i)
                compare(item.url, expectedUrls[i])
                const metadata = item.links[item.url]
                verify(metadata)
                verify(!page.examples[i].visualOnly)
                const span = item.segments.find(segment => segment.copyText === expectedUrls[i])
                verify(span)
                compare(span.href, expectedUrls[i])
                const rect = item.inlineLinkRects[0].rect
                compare(item.linkAt(rect.x + rect.width / 2, rect.y + rect.height / 2), expectedUrls[i])
                if (i === 0)
                    mouseClick(item, rect.x + rect.width / 2, rect.y + rect.height / 2)
                else
                    item.linkActivated(item.url) // Remaining examples are below the viewport.
                compare(activatedUrl.text, expectedUrls[i])
                compare(activatedPath.text,
                        [metadata.title, ...(metadata.path || []).map(part => part.text)].join(" › "))
                item.selectAll()
                verify(item.selectedText.includes(expectedUrls[i]))
            }
            verify(page.channelThreadUrl.includes("?thread-id=release-thread#"))
            compare(page.groupThreadUrl, "https://status.app/g/?a2=travel-group&thread-id=sierra-park-thread")
            for (let i = expectedUrls.length; i < page.examples.length; ++i) {
                verify(page.examples[i].visualOnly)
                verify(page.examples[i].url.startsWith("https://example.invalid/"))
            }
        }

        function test_storybookUnknownDestination() {
            const page = createTemporaryObject(pageComponent, root, {width: 1000, height: 1000})
            verify(page)
            const item = findChild(page, "inlineLinkExample0")
            const destination = findChild(page, "inlineLinkDestination0")
            const mainLabel = findChild(page, "inlineLinkMainLabel0")
            const url = item.url
            mainLabel.text = "Renamed profile"
            compare(item.url, url) // Presentation edits never change the destination.
            verify(item.text.includes("Renamed profile"))
            destination.text = "https://status.app/u#unknown"
            compare(item.inlineIconRects.length, 0)
            verify(item.text.includes(destination.text))
            item.linkActivated(item.url)
            compare(findChild(page, "inlineLinkActivatedPath").text, "Unresolved URL")
            destination.text = url
            compare(item.inlineIconRects.length, 1)
            verify(item.text.includes("Renamed profile"))
        }

        function test_storybookEditableFields() {
            const page = createTemporaryObject(pageComponent, root, {width: 1000, height: 1000})
            verify(page)
            const item = findChild(page, "inlineLinkExample6")
            const mainLabel = findChild(page, "inlineLinkMainLabel6")
            const context1 = findChild(page, "inlineLinkContext1_6")
            const context2 = findChild(page, "inlineLinkContext2_6")
            const context3 = findChild(page, "inlineLinkContext3_6")
            const showBubble = findChild(page, "inlineLinkShowBubble6")
            verify(item && mainLabel && context1 && context2 && context3 && showBubble)
            mainLabel.text = "Renamed group"
            context1.text = "Renamed thread"
            context2.text = "Second context"
            context3.text = "Third context"
            verify(item.text.includes("Renamed group › Renamed thread › Second context › Third context"))
            compare(item.inlineIconRects.length, 3) // Avatar, thread and message icons stay intact.
            showBubble.checked = false
            compare(item.inlineIconRects.length, 2)
            showBubble.checked = true
            compare(item.inlineIconRects.length, 3)
            context2.text = ""
            verify(item.text.includes("Renamed thread › Third context"))
            verify(!item.text.includes("Second context"))
            item.selectAll()
            verify(item.selectedText.includes(item.url))
            verify(!item.selectedText.includes("Renamed group"))
        }

        function test_paddingRoundedBackgroundAndHover() {
            const item = createText({title: "Status App", path: [{text: "# feedback-desktop"}, {text: "Release summary", icon: "thread"}], trailingIcons: ["chat"]})
            const background = findChild(item, "inlineLinkBackground")
            verify(background)
            verify(background.radius > 0 && background.radius <= background.height / 2)
            const avatar = item.inlineIconRects[0].rect
            verify(avatar.x > background.x, "Keep padding before the first avatar")
            item.hoverAt(avatar.x + avatar.width / 2, avatar.y + avatar.height / 2)
            compare(background.color, item.appearance.hoverHighlightColor)
            item.clearHover()
            compare(background.color, item.appearance.mentionBackground)
            item.width = 160
            verify(item.inlineLinkRects.length > 1)
            for (const rect of item.inlineLinkRects)
                compare(rect.href, root.url)
            item.selectAll()
            compare(item.selectedText, "Before " + root.url + " after")
        }

        function test_symmetricEndPaddingAndCopy() {
            const label = "JohnDoe.ETH"
            const item = createText({title: label})
            const font = Qt.font({family: item.appearance.font.family,
                                  pixelSize: item.appearance.font.pixelSize, bold: true})
            const metrics = createTemporaryObject(metricsComponent, root, {font, text: label})
            verify(metrics)
            const background = item.inlineLinkRects[0].rect
            const avatar = item.inlineIconRects[0].rect
            const leadingPadding = avatar.x - background.x
            const labelEnd = avatar.x + avatar.width + leadingPadding + metrics.advanceWidth
            const trailingPadding = background.x + background.width - labelEnd
            verify(leadingPadding > 0)
            fuzzyCompare(trailingPadding, leadingPadding, 1)

            // Selecting only the label and its padding must not copy layout characters.
            const labelStart = "Before ".length + 4
            item.select(labelStart, labelStart + label.length + 1)
            compare(item.selectedText, label)
            item.selectAll()
            compare(item.selectedText, "Before " + root.url + " after")

            item.links = ({[root.url]: {title: label, trailingIcons: ["chat"]}})
            const rect = item.inlineLinkRects[0].rect
            const icons = item.inlineIconRects
            const first = icons[0].rect
            const last = icons[icons.length - 1].rect
            fuzzyCompare(rect.x + rect.width - last.x - last.width, first.x - rect.x, 1)
        }

        function test_fullColorMessageBubble() {
            const source = Assets.svg("message-bubble")
            const item = createText({title: "TravelHUB", trailingIcons: [{image: source}]})
            const bubble = findChild(item, "inlineLinkImage")
            verify(bubble)
            compare(bubble.source.toString(), source)
            compare(bubble.status, Image.Ready)
            compare(item.inlineIconRects.length, 2)
            item.selectAll()
            compare(item.selectedText, "Before " + root.url + " after")
        }
    }
}
