import QtQuick
import QtTest

Item {
    id: root

    width: 400
    height: 200

    readonly property url statusBubbleUrl: Qt.resolvedUrl(
        "../../../ui/app/AppLayouts/Browser/controls/StatusBubble.qml")

    TestCase {
        name: "BrowserStatusBubble"
        when: windowShown

        function createBubble() {
            const component = Qt.createComponent(root.statusBubbleUrl)
            verify(component.status === Component.Ready, component.errorString())
            return createTemporaryObject(component, root)
        }

        function test_show_displaysHoveredUrl() {
            const bubble = createBubble()
            bubble.show("https://status.app/api/download/windows")

            compare(bubble.text, "https://status.app/api/download/windows")
            verify(bubble.visible)
        }

        function test_hide_clearsAtOnce() {
            const bubble = createBubble()
            bubble.show("https://status.app/")
            bubble.hide()

            compare(bubble.text, "")
            verify(!bubble.visible)
        }
    }
}
