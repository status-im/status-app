import QtQuick
import QtTest

import StatusQ.Components

/*
 Perf guard: the sender display name is rendered ~17 times per chat switch.
 A TextEdit (selection machinery, cursor, input handling) is much heavier to
 create than a plain Text and the name is not an input field — name
 selection is not part of the message-selection flow.
*/
Item {
    id: root

    width: 500
    height: 200

    Component {
        id: headerComp

        StatusMessageHeader {
            width: parent.width
            sender: StatusMessageSenderDetails {
                displayName: "Alice"
            }
            timestamp: Date.now()
        }
    }

    SignalSpy {
        id: clickSpy
        signalName: "clicked"
    }

    TestCase {
        name: "StatusMessageHeader"
        when: windowShown

        function init() {
            clickSpy.target = null
            clickSpy.clear()
        }

        function displayName(header) {
            const label = findChild(header, "StatusMessageHeader_DisplayName")
            verify(!!label)
            return label
        }

        function test_displayNameRenders() {
            const header = createTemporaryObject(headerComp, root)
            verify(!!header)
            waitForRendering(header)

            compare(displayName(header).text, "Alice")
        }

        function test_displayNameShowsYouForOwnMessages() {
            const header = createTemporaryObject(headerComp, root,
                                                 {amISender: true})
            verify(!!header)
            waitForRendering(header)

            compare(displayName(header).text, qsTr("You"))
        }

        function test_displayNameClickEmitsSignal() {
            const header = createTemporaryObject(headerComp, root)
            verify(!!header)
            waitForRendering(header)

            clickSpy.target = header
            const label = displayName(header)
            mouseClick(label, label.width / 2, label.height / 2)

            tryCompare(clickSpy, "count", 1)
        }

        function test_displayNameIsNotATextEdit() {
            const header = createTemporaryObject(headerComp, root)
            verify(!!header)
            waitForRendering(header)

            verify(!(displayName(header) instanceof TextEdit),
                   "display name must be a plain Text, not an input item")
        }
    }
}
