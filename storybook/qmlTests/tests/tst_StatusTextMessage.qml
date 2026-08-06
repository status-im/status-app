import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Controls

import "../../../ui/StatusQ/src/StatusQ/Components/private/statusMessage"

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest

        StatusTextMessage {
            width: 400
            messageDetails: StatusMessageDetails {
                unparsedText: "hello world"
            }
        }
    }

    SignalSpy {
        id: contextMenuSpy
        target: testCase.control
        signalName: "contextMenuRequested"
    }

    TestCase {
        id: testCase
        name: "StatusTextMessage"
        when: windowShown

        property var control: null

        function init() {
            control = createTemporaryObject(componentUnderTest, root)
            verify(control)
            tryVerify(() => control.implicitHeight > 0)
        }

        function test_rightClickOnRenderedTextRequestsContextMenu() {
            contextMenuSpy.clear()

            mouseClick(control.textField, 10, 5, Qt.RightButton)

            compare(contextMenuSpy.count, 1)
            compare(contextMenuSpy.signalArguments[0][0].x, 10)
            compare(contextMenuSpy.signalArguments[0][0].y, 5)
            compare(contextMenuSpy.signalArguments[0][1], StatusSecondaryActionHandler.RightClick)
        }
    }
}
