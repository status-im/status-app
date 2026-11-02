import QtQuick
import QtTest
import StatusQ
import StatusQ.Controls

Item {
    id: root
    width: 600
    height: 400

    Item { id: focusSink; x: 550; width: 10; height: 10 }
    Component { id: spyComponent; SignalSpy {} }
    Component {
        id: textComponent
        ChatTextItem {
            width: 480
            font.pixelSize: 16
            lineHeight: 22
            segments: [{text: "https://status.app", href: "https://status.app"}]
        }
    }
    Component {
        id: scrollComponent
        Flickable {
            width: 400; height: 160
            contentWidth: width
            contentHeight: textItem.implicitHeight
            property alias textItem: textItem
            ChatTextItem {
                id: textItem
                width: parent.width
                font.pixelSize: 16
                lineHeight: 22
                segments: [{text: Array(30).fill("https://status.app").join("\n"), href: "https://status.app"}]
            }
        }
    }
    Component {
        id: messageComponent
        Item {
            width: 480; height: 100
            property int longPressCount: 0
            property int lastSource: -1
            property alias textItem: textItem
            ChatTextItem {
                id: textItem
                width: parent.width
                font.pixelSize: 16
                lineHeight: 22
                segments: [{text: "https://status.app", href: "https://status.app"}]
            }
            StatusSecondaryActionHandler {
                onTriggered: (position, source) => {
                    parent.lastSource = source
                    parent.longPressCount++
                }
            }
        }
    }

    TestCase {
        name: "ChatTextItemTouch"
        when: windowShown

        function spy(item, signal) {
            const result = createTemporaryObject(spyComponent, root, {target: item, signalName: signal})
            verify(!!result && result.valid)
            return result
        }

        function test_touchTap_data() { return [{tag: "selectable", selectable: true}, {tag: "non-selectable", selectable: false}] }
        function test_touchTap(data) {
            const item = createTemporaryObject(textComponent, root, {selectable: data.selectable})
            const links = spy(item, "linkActivated")
            focusSink.forceActiveFocus()
            const touch = touchEvent(item)
            // Two quick taps must activate twice, without mouse double-click selection.
            for (let i = 0; i < 2; ++i) {
                touch.press(0, item, 10, 11).commit()
                touch.release(0, item, 10, 11).commit()
            }
            compare(links.count, 2)
            compare(links.signalArguments[0][0], "https://status.app")
            compare(item.selectedText, "")
            verify(focusSink.activeFocus)
        }

        function test_touchPlainTextPreservesFocusAndSelection() {
            const item = createTemporaryObject(textComponent, root, {segments: [{text: "first line\nsecond line"}]})
            const drags = spy(item, "selectionDragStarted")
            focusSink.forceActiveFocus()
            item.select(0, 5)
            const touch = touchEvent(item)
            touch.press(0, item, 2, 11).commit()
            touch.move(0, item, 200, 33).commit()
            touch.release(0, item, 200, 33).commit()
            compare(item.selectedText, "first")
            compare(drags.count, 0)
            verify(focusSink.activeFocus)
        }

        function test_touchDrag_data() { return [{tag: "selectable", selectable: true}, {tag: "non-selectable", selectable: false}] }
        function test_touchDrag(data) {
            const item = createTemporaryObject(textComponent, root, {selectable: data.selectable})
            const links = spy(item, "linkActivated")
            const touch = touchEvent(item)
            touch.press(0, item, 10, 11).commit()
            touch.move(0, item, 200, 70).commit()
            // Deliver the excursion in a frame before queuing the return move.
            // Request the frame: nothing else changes, so none would come.
            item.update()
            verify(waitForRendering(item))
            touch.move(0, item, 10, 11).commit()
            touch.release(0, item, 10, 11).commit()
            compare(links.count, 0, "dragging back onto the link must not activate it")
            compare(item.selectedText, "")
        }

        function test_touchScroll_data() { return [{tag: "selectable", selectable: true}, {tag: "non-selectable", selectable: false}] }
        function test_touchScroll(data) {
            const flickable = createTemporaryObject(scrollComponent, root)
            flickable.textItem.selectable = data.selectable
            const links = spy(flickable.textItem, "linkActivated")
            const touch = touchEvent(flickable)
            touch.press(0, flickable, 10, 100).commit()
            for (let y = 90; y >= 10; y -= 10) {
                touch.move(0, flickable, 10, y).commit()
                wait(16)
            }
            touch.release(0, flickable, 10, 10).commit()
            verify(flickable.contentY > 0, "touch over a link must scroll the parent")
            compare(flickable.textItem.selectedText, "")
            compare(links.count, 0)
            verify(flickable.interactive)
        }

        function test_parentTouchTap() {
            const message = createTemporaryObject(messageComponent, root)
            const links = spy(message.textItem, "linkActivated")
            const touch = touchEvent(message)
            touch.press(0, message, 10, 11).commit()
            touch.release(0, message, 10, 11).commit()
            compare(links.count, 1)
            compare(message.longPressCount, 0)
        }

        function test_bareLongPressDoesNotActivate() {
            const item = createTemporaryObject(textComponent, root)
            const links = spy(item, "linkActivated")
            const touch = touchEvent(item)
            touch.press(0, item, 10, 11).commit()
            wait(Qt.styleHints.mousePressAndHoldInterval + 100)
            touch.release(0, item, 10, 11).commit()
            compare(links.count, 0)
            compare(item.selectedText, "")
        }

        function test_parentLongPress_data() {
            return [
                {tag: "selectable-link", link: true, selectable: true},
                {tag: "selectable-text", link: false, selectable: true},
                {tag: "non-selectable-link", link: true, selectable: false},
                {tag: "non-selectable-text", link: false, selectable: false}
            ]
        }
        function test_parentLongPress(data) {
            const message = createTemporaryObject(messageComponent, root)
            message.textItem.selectable = data.selectable
            if (!data.link)
                message.textItem.segments = [{text: "Plain message"}]
            const links = spy(message.textItem, "linkActivated")
            const touch = touchEvent(message)
            touch.press(0, message, 10, 11).commit()
            tryCompare(message, "longPressCount", 1)
            compare(message.lastSource, StatusSecondaryActionHandler.LongPress)
            touch.release(0, message, 10, 11).commit()
            compare(links.count, 0)
            compare(message.textItem.selectedText, "")
        }
    }
}
