import QtQuick
import QtQuick.Controls
import QtTest

import AppLayouts.Profile.popups

Item {
    id: root

    width: 1024
    height: 768

    Component {
        id: componentUnderTest

        ConfirmChangePasswordModal {
            anchors.centerIn: parent
            destroyOnClose: false
            modal: false
            closePolicy: Popup.NoAutoClose
        }
    }

    property ConfirmChangePasswordModal controlUnderTest: null

    SignalSpy {
        id: changePasswordSpy
        target: controlUnderTest
        signalName: "changePasswordRequested"
    }

    TestCase {
        name: "ConfirmChangePasswordModal"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            changePasswordSpy.target = controlUnderTest
            changePasswordSpy.clear()
        }

        function cleanup() {
            if (controlUnderTest) {
                controlUnderTest.close()
                controlUnderTest.destroy()
                controlUnderTest = null
            }
            changePasswordSpy.clear()
        }

        function openDialog(fastPasswordChangePossible) {
            controlUnderTest.fastPasswordChangePossible = fastPasswordChangePossible
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
        }

        function submitButton() {
            const button = findChild(controlUnderTest, "changePasswordModalSubmitButton")
            verify(!!button)
            return button
        }

        function rekeyCheckbox() {
            const checkbox = findChild(controlUnderTest, "changePasswordModalRekeyCheckBox")
            verify(!!checkbox)
            return checkbox
        }

        function description() {
            const textItem = findChild(controlUnderTest, "changePasswordModalDescription")
            verify(!!textItem)
            return textItem
        }

        function rekeySectionVisible(checkbox) {
            // ColumnLayout toggles visibility; child.visible stays true on its own.
            return checkbox.parent.visible
        }

        function test_legacy_path_hides_rekey_and_requests_restart() {
            openDialog(false)

            const checkbox = rekeyCheckbox()
            verify(!rekeySectionVisible(checkbox))
            verify(description().text.indexOf("Future password changes will be instant") !== -1)
            compare(submitButton().text, "Re-encrypt data using new password")

            mouseClick(submitButton())
            tryCompare(changePasswordSpy, "count", 1)
            compare(changePasswordSpy.signalArguments[0][0], false)
            compare(submitButton().text, "Restart Status")
            verify(!submitButton().enabled)

            controlUnderTest.passwordSuccessfulyChanged()
            compare(submitButton().text, "Restart Status")
            verify(submitButton().enabled)
            // Do not click Restart Status — SystemUtils.restartApplication exits the process.
        }

        function test_fast_path_shows_close_and_emits_rekey_false() {
            openDialog(true)

            const checkbox = rekeyCheckbox()
            verify(rekeySectionVisible(checkbox))
            verify(!checkbox.checked)
            verify(description().text.indexOf("no restart needed") !== -1)
            compare(submitButton().text, "Change password")

            mouseClick(submitButton())
            tryCompare(changePasswordSpy, "count", 1)
            compare(changePasswordSpy.signalArguments[0][0], false)

            controlUnderTest.passwordSuccessfulyChanged()
            compare(submitButton().text, "Close")
            verify(submitButton().enabled)

            mouseClick(submitButton())
            tryCompare(controlUnderTest, "opened", false)
        }

        function test_fast_path_with_rekey_requests_deep_change() {
            openDialog(true)

            const checkbox = rekeyCheckbox()
            verify(rekeySectionVisible(checkbox))
            mouseClick(checkbox)
            tryCompare(checkbox, "checked", true)

            verify(description().text.indexOf("fully re-encrypted with a new encryption key") !== -1)
            compare(submitButton().text, "Re-encrypt data using new password")

            mouseClick(submitButton())
            tryCompare(changePasswordSpy, "count", 1)
            compare(changePasswordSpy.signalArguments[0][0], true)

            controlUnderTest.passwordSuccessfulyChanged()
            compare(submitButton().text, "Restart Status")
            // Do not click Restart Status — SystemUtils.restartApplication exits the process.
        }

        function test_rekey_checkbox_hidden_while_in_progress_and_after_success() {
            openDialog(true)

            const checkbox = rekeyCheckbox()
            verify(rekeySectionVisible(checkbox))

            mouseClick(submitButton())
            tryCompare(changePasswordSpy, "count", 1)
            verify(!rekeySectionVisible(checkbox))

            controlUnderTest.passwordSuccessfulyChanged()
            verify(!rekeySectionVisible(checkbox))
        }
    }
}
