import QtQuick
import QtTest
import "ChatTextTestUtils.js" as ChatTextTestUtils
import StatusQ

Item {
    id: root
    width: 600
    height: 500

    TextEdit {
        id: otherEditor
        y: 450
        width: 200
        height: 30
        text: "editable field"
    }

    Component {
        id: itemComponent
        ChatTextItem {
            appearance: ChatTextAppearance {
                font.pixelSize: 15
                lineHeight: 22
            }

            width: 400
            segments: [{text: "first line"}, {text: "second line", newBlock: true}]
        }
    }
    Component { id: spyComponent; SignalSpy {} }

    TestCase {
        id: testCase

        readonly property var appearanceProperties: ChatTextTestUtils.appearanceProperties
        property list<chatTextSegment> initialSegments
        function createStyledTemporary(component, parent, properties) {
            return ChatTextTestUtils.create(testCase, component, parent, properties)
        }
        name: "ChatTextItemInteraction"
        when: windowShown

        function createItem(properties) {
            const item = createStyledTemporary(itemComponent, root, properties || {})
            verify(!!item)
            return item
        }

        function linkSpy(item) {
            const spy = createStyledTemporary(spyComponent, root,
                {target: item, signalName: "linkActivated"})
            verify(!!spy && spy.valid)
            return spy
        }

        function dragAll(item) {
            mousePress(item, 0, item.appearance.lineHeight / 2)
            mouseMove(item, item.width - 4, item.contentHeight - item.appearance.lineHeight / 2)
            mouseRelease(item, item.width - 4, item.contentHeight - item.appearance.lineHeight / 2)
        }

        function test_emptySegmentsCollapseContent() {
            const item = createItem({segments: []})
            compare(item.contentHeight, 0)
            compare(item.implicitHeight, 0)
            item.segments = [{text: "hello"}, {text: "code", codeBlock: true},
                         {text: "quoted", newBlock: true, quoteLevel: 1}]
            verify(item.contentHeight > 0)
            item.selectAll()
            item.segments = []
            compare(item.contentHeight, 0)
            compare(item.implicitHeight, 0)
            compare(item.selectedText, "")
            compare(item.quoteBarRects().length, 0)
            compare(item.codeBlockRects().length, 0)
        }

        function test_lineHeightOverrideChangesGeometry() {
            const item = createItem({segments: [{text: "a\nb"}]})
            compare(item.contentHeight, 44)
            item.appearance.lineHeight = 30
            compare(item.contentHeight, 60)
            item.appearance.lineHeight = 0
            verify(item.contentHeight > 0 && item.contentHeight < 60)
            compare(item.implicitHeight, item.contentHeight)
        }

        function test_clickingAnotherItemDeselectsPrevious() {
            const first = createItem()
            const second = createItem({y: 200})
            dragAll(first)
            compare(first.selectedText, "first line\nsecond line")
            verify(first.activeFocus)
            mouseClick(second, 5, 11)
            verify(second.activeFocus)
            compare(second.selectedText, "")
            compare(first.selectedText, "")
        }

        function test_focusLossReason_data() {
            return [{tag: "another-control", reason: Qt.OtherFocusReason, kept: false},
                    {tag: "popup", reason: Qt.PopupFocusReason, kept: true},
                    {tag: "window", reason: Qt.ActiveWindowFocusReason, kept: true}]
        }

        function test_focusLossReason(data) {
            const item = createItem()
            item.forceActiveFocus()
            item.selectAll()
            otherEditor.forceActiveFocus(data.reason)
            verify(!item.activeFocus)
            compare(item.selectedText, data.kept ? "first line\nsecond line" : "")
        }

        function test_disablePersistentSelectionWhileUnfocused() {
            const item = createItem({persistentSelection: true})
            item.forceActiveFocus()
            item.selectAll()
            otherEditor.forceActiveFocus()
            compare(item.selectedText, "first line\nsecond line")
            // Changing the policy takes effect on the next focus loss.
            item.persistentSelection = false
            compare(item.selectedText, "first line\nsecond line")
            item.forceActiveFocus()
            otherEditor.forceActiveFocus()
            compare(item.selectedText, "")
        }

        function test_selectableToggledAfterSegments() {
            const item = createItem({selectable: false})
            dragAll(item)
            compare(item.selectedText, "")
            item.selectable = true
            dragAll(item)
            compare(item.selectedText, "first line\nsecond line")
            item.selectable = false
            compare(item.selectedText, "")
        }

        function test_copySelection() {
            const item = createItem()
            item.selectAll()
            ClipboardUtils.setText("sentinel")
            verify(item.copySelection())
            compare(ClipboardUtils.text, "first line\nsecond line")
            item.clearSelection()
            ClipboardUtils.setText("sentinel")
            compare(item.copySelection(), false)
            compare(ClipboardUtils.text, "sentinel")
        }

        function test_copyShortcutAfterEditorFocus() {
            const item = createItem()
            ClipboardUtils.setText("sentinel")
            otherEditor.forceActiveFocus()
            otherEditor.selectAll()
            verify(otherEditor.activeFocus)
            dragAll(item)
            verify(item.activeFocus)
            verify(!otherEditor.activeFocus)
            compare(item.selectedText, "first line\nsecond line")
            keySequence(StandardKey.Copy)
            compare(ClipboardUtils.text, item.selectedText)
        }

        function linkCases() {
            const cases = []
            for (const selectable of [false, true]) {
                for (const kind of ["url", "mention"]) {
                    cases.push({tag: kind + "-" + selectable, selectable: selectable,
                                href: kind === "url" ? "https://status.app" : "0xabc"})
                }
            }
            return cases
        }

        function test_mouseLinkActivation_data() { return linkCases() }
        function test_mouseLinkActivation(data) {
            const item = createItem({selectable: data.selectable,
                                     segments: [{text: "WWWWWW", href: data.href}]})
            const spy = linkSpy(item)
            otherEditor.forceActiveFocus()
            compare(item.linkAt(10, 11), data.href)
            mouseClick(item, 10, 11)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], data.href)
            compare(item.selectedText, "")
            compare(item.activeFocus, data.selectable)
            compare(otherEditor.activeFocus, !data.selectable)
        }

        function test_linkClickClearsSelection() {
            const item = createItem({segments: [{text: "WWWWWW", href: "https://status.app"},
                                                {text: "plain text", newBlock: true}]})
            const spy = linkSpy(item)
            item.select(7, 12)
            compare(item.selectedText, "plain")
            mouseClick(item, 10, 11)
            compare(spy.count, 1)
            compare(item.selectedText, "")
        }

        function test_mouseDragBackOntoLinkDoesNotActivate_data() { return linkCases() }
        function test_mouseDragBackOntoLinkDoesNotActivate(data) {
            const item = createItem({selectable: data.selectable,
                                     segments: [{text: "WWWWWW", href: data.href}]})
            const spy = linkSpy(item)
            mousePress(item, 10, 11)
            mouseMove(item, 200, 70)
            mouseMove(item, 10, 11)
            mouseRelease(item, 10, 11)
            compare(spy.count, 0, "dragging back onto the link must not activate it")
        }

        function test_nativeHover_data() { return linkCases() }
        function test_nativeHover(data) {
            const item = createItem({selectable: data.selectable,
                                     segments: [{text: "WWWWWW", href: data.href}]})
            mouseMove(root, 590, 390)
            mouseMove(item, 10, 11)
            compare(item.hoveredLink, data.href)
            mouseMove(item, item.width - 4, 11)
            compare(item.hoveredLink, "")
            mouseMove(item, 10, 11)
            compare(item.hoveredLink, data.href)
            mouseMove(root, 590, 390)
            compare(item.hoveredLink, "")
        }

        function test_everyoneIsNotActionable_data() {
            return [{tag: "selectable", selectable: true},
                    {tag: "non-selectable", selectable: false}]
        }
        function test_everyoneIsNotActionable(data) {
            const item = createItem({selectable: data.selectable,
                                     segments: [{text: "@alice", href: "0xabc"}]})
            const spy = linkSpy(item)
            mouseMove(root, 590, 390)
            mouseMove(item, 10, 11)
            compare(item.hoveredLink, "0xabc")
            item.segments = MarkdownUtils.toChatTextSegments("@0x00001")
            compare(item.segments[0].text, "@everyone")
            compare(item.linkAt(10, 11), "")
            compare(item.hoveredLink, "")
            mouseMove(item, 12, 11)
            compare(item.hoveredLink, "")
            mouseClick(item, 10, 11)
            const touch = touchEvent(item)
            touch.press(0, item, 10, 11).commit()
            touch.release(0, item, 10, 11).commit()
            compare(spy.count, 0)
        }

        function test_everyoneRemainsSelectableAndCopyable() {
            const item = createItem({segments: MarkdownUtils.toChatTextSegments("@0x00001")})
            dragAll(item)
            compare(item.selectedText, "@everyone")
            ClipboardUtils.setText("sentinel")
            keySequence(StandardKey.Copy)
            compare(ClipboardUtils.text, "@everyone")
        }

        function test_emojiCopyYieldsCharacters() {
            const text = "A😎B"
            const item = createItem({segments: MarkdownUtils.toChatTextSegments(text), font: Qt.font({pixelSize: 32})})
            const y = item.contentHeight / 2
            mousePress(item, 0, y)
            mouseMove(item, item.width - 4, y)
            mouseRelease(item, item.width - 4, y)
            compare(item.selectedText, text)
            verify(item.copySelection())
            compare(ClipboardUtils.text, text)
        }

        function test_selectionSurvivesAppearanceUpdateVisually() {
            const item = createItem()
            dragAll(item)
            const before = grabImage(item)
            item.appearance.linkColor = "#123456"
            compare(item.selectedText, "first line\nsecond line")
            verify(before.equals(grabImage(item)))
        }

        function redPixels(image) {
            let count = 0
            for (let y = 0; y < image.height; ++y) {
                for (let x = 0; x < image.width; ++x) {
                    const color = image.pixel(x, y)
                    if (color.r > 0.8 && color.g < 0.2 && color.b < 0.2 && color.a > 0.8)
                        count++
                }
            }
            return count
        }

        function test_contentResetClearsPaintedSelection() {
            const item = createItem({selectionColor: "red", selectionTextColor: "white"})
            dragAll(item)
            verify(redPixels(grabImage(item)) > 10)
            item.segments = [{text: "changed"}]
            item.segments = [{text: "first line"}, {text: "second line", newBlock: true}]
            compare(item.selectedText, "")
            compare(redPixels(grabImage(item)), 0)
        }
    }
}
