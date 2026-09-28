import QtQuick
import QtTest

import shared.status

Item {
    id: root
    width: 500
    height: 300

    Component {
        id: inputComponent
        StatusChatInput {
            anchors.fill: parent
            usersModel: ListModel {}
        }
    }

    SignalSpy {
        id: sendSpy
        signalName: "sendMessageRequested"
    }

    TestCase {
        name: "StatusChatInputSendEnabled"
        when: windowShown

        function init() { sendSpy.clear() }

        function test_sendEnabledFalseDisablesSendButton() {
            const input = createTemporaryObject(inputComponent, root, { sendEnabled: false })
            sendSpy.target = input
            waitForRendering(input)
            input.setText("hello")
            const sendButton = findChild(input, "statusChatInputSendButton")
            verify(sendButton)
            verify(!sendButton.enabled)
            input.tryFinalizeMessage()
            compare(sendSpy.count, 0)

            input.sendEnabled = true
            tryVerify(() => sendButton.enabled)
            input.tryFinalizeMessage()
            compare(sendSpy.count, 1)
        }
    }
}
