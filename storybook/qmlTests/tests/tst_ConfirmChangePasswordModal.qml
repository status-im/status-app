import QtQuick
import QtQuick.Controls
import QtTest

import AppLayouts.Profile.popups

Item {
    id: root

    width: 1024
    height: 768

    Rectangle {
        anchors.fill: parent
        color: "#808080"
    }

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

        // Regression: the in-progress blurred backdrop captured the window
        // content that contained the backdrop itself, so the blur sampled its
        // own render target and the backdrop came out magenta.
        function test_deep_change_backdrop_is_not_corrupted() {
            controlUnderTest.modal = true
            openDialog(true)

            mouseClick(rekeyCheckbox())
            mouseClick(submitButton())
            tryCompare(changePasswordSpy, "count", 1)

            // Wait for the one-shot capture and the blur to render.
            let failure = ""
            tryVerify(() => {
                failure = backdropFailure(grabImage(root))
                if (failure !== "")
                    console.warn(failure)
                return failure === ""
            }, 2000, "backdrop corrupted or not dimmed (see warnings)")
        }

        // Returns "" when every corner (well outside the centered dialog) is a
        // neutral, dimmed grey, otherwise a description of the first bad pixel.
        function backdropFailure(image) {
            // The grab is in device pixels.
            const w = image.width
            const h = image.height
            const points = [[10, 10], [w - 10, 10], [10, h - 10], [w - 10, h - 10]]
            for (const [x, y] of points) {
                const pixel = image.pixel(x, y)
                // Neutral grey background + greyscale backdrop must stay neutral;
                // a corrupted backdrop shows up as a strong hue (magenta).
                if (Math.abs(pixel.r - pixel.g) >= 0.12 || Math.abs(pixel.b - pixel.g) >= 0.12)
                    return `backdrop pixel at ${x},${y} is not neutral: ${pixel}`
                // ...and dimmed by the backdrop color.
                if (pixel.g >= 0.45)
                    return `backdrop pixel at ${x},${y} is not dimmed: ${pixel}`
            }
            return ""
        }
    }
}
