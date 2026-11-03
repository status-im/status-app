import QtQuick
import QtTest
import AppLayouts.Chat.panels

Item {
    id: root
    width: 500
    height: 700

    Component {
        id: panelComponent
        NewThreadPanel {
            width: root.width
            height: root.height
            parentMessageText: "An existing message with more than fifty characters for the thread title"
            parentMessageContent: Rectangle {
                objectName: "parentMessageContent"
                height: 80
            }
        }
    }
    Component { id: spyComponent; SignalSpy { signalName: "sendRequested" } }

    TestCase {
        name: "NewThreadPanel"
        when: windowShown

        function makePanel(properties = {}) {
            const panel = createTemporaryObject(panelComponent, root, properties)
            verify(!!panel)
            return panel
        }

        function test_draftAndFocus() {
            const panel = makePanel()
            verify(findChild(panel, "parentMessageContent"))
            tryCompare(panel.chatInput.textInput, "activeFocus", true)
            verify(panel.chatInput.startNewThread)
            compare(findChild(panel.chatInput, "threadNameInput").item.placeholderText,
                    panel.parentMessageText.slice(0, 50))
            verify(!panel.chatInput.imageFeaturesEnabled)
            verify(!panel.chatInput.stickersButtonVisible)
            verify(!panel.chatInput.gifButtonVisible)
        }

        function test_sendEmitsIntentAndPreservesDraft() {
            const panel = makePanel()
            const spy = createTemporaryObject(spyComponent, root, {target: panel})
            panel.chatInput.tryFinalizeMessage()
            compare(spy.count, 0)
            panel.chatInput.setText("First reply")
            findChild(panel.chatInput, "threadNameInput").item.text = "Custom title"
            panel.chatInput.tryFinalizeMessage()
            compare(spy.count, 1)
            compare(Array.from(spy.signalArguments[0]), ["First reply", "Custom title", true])
            compare(panel.chatInput.getTextWithPublicKeys(), "First reply")
        }

        function test_pendingPreventsDuplicateSendAndEditing() {
            const panel = makePanel({initialText: "First reply", initialThreadName: "Custom title"})
            const spy = createTemporaryObject(spyComponent, root, {target: panel})
            panel.pending = true
            verify(panel.chatInput.textInput.readOnly)
            verify(findChild(panel.chatInput, "threadNameInput").item.readOnly)
            panel.chatInput.tryFinalizeMessage()
            compare(spy.count, 0)
            panel.pending = false
            panel.chatInput.tryFinalizeMessage()
            compare(spy.count, 1)
            compare(Array.from(spy.signalArguments[0]), ["First reply", "Custom title", true])
        }

        function test_errorKeepsDraftAndAllowsRetry() {
            const panel = makePanel({initialText: "Retained reply", initialThreadName: "Retained title"})
            const spy = createTemporaryObject(spyComponent, root, {target: panel})
            panel.pending = true
            panel.error = "Couldn't create thread. Try again."
            panel.pending = false
            const error = findChild(panel, "newThreadError")
            verify(error.visible)
            compare(error.text, panel.error)
            compare(panel.chatInput.getTextWithPublicKeys(), "Retained reply")
            compare(findChild(panel.chatInput, "threadNameInput").item.text, "Retained title")
            panel.chatInput.tryFinalizeMessage()
            compare(spy.count, 1)
        }

        function test_noPermissionPreventsSend() {
            const panel = makePanel({canPost: false})
            const spy = createTemporaryObject(spyComponent, root, {target: panel})
            panel.chatInput.setText("First reply")
            panel.chatInput.tryFinalizeMessage()
            compare(spy.count, 0)
            panel.canPost = true
            panel.chatInput.tryFinalizeMessage()
            compare(spy.count, 1)
        }

        function test_parentTitlePreservesLiteralText_data() {
            return [
                {tag: "html-and-entity", text: "<b>literal</b> &amp; value"},
                {tag: "literal-code", text: "vector<string> & value"},
                {tag: "prefix-limit", text: "<b>012345678901234567890123456789012345678901234567890123456789</b>"}
            ]
        }

        function test_parentTitlePreservesLiteralText(data) {
            const panel = makePanel({parentMessageText: data.text})
            const expected = data.text.slice(0, 50)
            compare(findChild(panel.chatInput, "threadNameInput").item.placeholderText, expected)
            const spy = createTemporaryObject(spyComponent, root, {target: panel})
            panel.chatInput.setText("First reply")
            panel.chatInput.tryFinalizeMessage()
            compare(Array.from(spy.signalArguments[0]), ["First reply", expected, true])
        }

        function test_toggleOffEmitsNormalSendIntent() {
            const panel = makePanel({initialText: "Normal message"})
            const spy = createTemporaryObject(spyComponent, root, {target: panel})
            panel.chatInput.startNewThread = false
            panel.chatInput.tryFinalizeMessage()
            compare(Array.from(spy.signalArguments[0]), ["Normal message", "", false])
        }
    }
}
