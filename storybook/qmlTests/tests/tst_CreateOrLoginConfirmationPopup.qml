import QtQuick
import QtTest

import mainui

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: popupComponent
        CreateOrLoginConfirmationPopup {
            parent: root
        }
    }

    SignalSpy {
        id: continueSpy
        signalName: "continueRequested"
    }

    TestCase {
        name: "CreateOrLoginConfirmationPopup"
        when: windowShown

        function openPopup() {
            const popup = createTemporaryObject(popupComponent, root)
            verify(!!popup)
            continueSpy.target = popup
            continueSpy.clear()
            popup.open()
            tryCompare(popup, "opened", true)
            return popup
        }

        function test_texts() {
            const popup = openPopup()
            compare(popup.title, qsTr("Create or log in to another profile?"))
            compare(popup.confirmationText, qsTr("Your current profile and all its data will be deleted from this device once you successfully create a new profile or log in to an existing one."))
            compare(findChild(popup, "createOrLoginContinueButton").text, qsTr("Continue"))
            const cancel = findChild(popup, "confirmationDialogCancelButton")
            verify(cancel.visible)
            compare(cancel.text, qsTr("Cancel"))
        }

        function test_continue() {
            const popup = openPopup()
            mouseClick(findChild(popup, "createOrLoginContinueButton"))
            compare(continueSpy.count, 1)
            tryCompare(popup, "opened", false)
        }

        function test_cancel() {
            const popup = openPopup()
            mouseClick(findChild(popup, "confirmationDialogCancelButton"))
            tryCompare(popup, "opened", false)
            compare(continueSpy.count, 0)

            const another = openPopup()
            another.close()
            tryCompare(another, "opened", false)
            compare(continueSpy.count, 0)
        }
    }
}
