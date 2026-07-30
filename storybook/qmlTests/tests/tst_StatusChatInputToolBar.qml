import QtQuick
import QtTest

import shared.status

Item {
    id: root
    width: 800
    height: 200

    Component {
        id: componentUnderTest
        StatusChatInputToolBar {
            width: 500
            sendButtonVisible: true
            editActionsVisible: false
            editAcceptButtonEnabled: true
        }
    }

    SignalSpy {
        id: signalSpy

        function setup(target, signalName) {
            clear()
            signalSpy.target = target
            signalSpy.signalName = signalName
        }
    }

    TestCase {
        name: "StatusChatInputToolBar"
        when: windowShown

        property StatusChatInputToolBar controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            signalSpy.target = null
            signalSpy.clear()
            if (controlUnderTest)
                controlUnderTest.destroy()
            controlUnderTest = null
        }

        function test_editActions_visible() {
            controlUnderTest.editActionsVisible = true
            waitForRendering(controlUnderTest)

            const sendButton = findChild(controlUnderTest, "statusChatInputSendButton")
            const acceptButton = findChild(controlUnderTest, "statusChatInputEditAcceptButton")
            const cancelButton = findChild(controlUnderTest, "statusChatInputEditCancelButton")

            verify(!!sendButton)
            verify(!!acceptButton)
            verify(!!cancelButton)
            verify(!sendButton.visible)
            verify(acceptButton.visible)
            verify(cancelButton.visible)
        }

        function test_editActions_hidden() {
            controlUnderTest.editActionsVisible = false
            controlUnderTest.sendButtonVisible = true
            waitForRendering(controlUnderTest)

            const sendButton = findChild(controlUnderTest, "statusChatInputSendButton")
            const acceptButton = findChild(controlUnderTest, "statusChatInputEditAcceptButton")

            verify(!!sendButton)
            verify(!!acceptButton)
            verify(sendButton.visible)
            verify(!acceptButton.visible)
        }

        function test_editAccept_respectsEnabled() {
            controlUnderTest.editActionsVisible = true
            controlUnderTest.editAcceptButtonEnabled = false
            waitForRendering(controlUnderTest)

            const acceptButton = findChild(controlUnderTest, "statusChatInputEditAcceptButton")
            verify(!!acceptButton)
            verify(!acceptButton.enabled)

            controlUnderTest.editAcceptButtonEnabled = true
            waitForRendering(controlUnderTest)
            verify(acceptButton.enabled)
        }

        function test_editCancel_clicked() {
            controlUnderTest.editActionsVisible = true
            waitForRendering(controlUnderTest)

            const cancelButton = findChild(controlUnderTest, "statusChatInputEditCancelButton")
            verify(!!cancelButton)

            signalSpy.setup(controlUnderTest, "editCancelClicked")
            mouseClick(cancelButton)

            compare(signalSpy.count, 1)
        }

        function test_editAccept_clicked() {
            controlUnderTest.editActionsVisible = true
            controlUnderTest.editAcceptButtonEnabled = true
            waitForRendering(controlUnderTest)

            const acceptButton = findChild(controlUnderTest, "statusChatInputEditAcceptButton")
            verify(!!acceptButton)

            signalSpy.setup(controlUnderTest, "editAcceptClicked")
            mouseClick(acceptButton)

            compare(signalSpy.count, 1)
        }
    }
}
