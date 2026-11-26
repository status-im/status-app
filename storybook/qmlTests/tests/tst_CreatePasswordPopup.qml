import QtQuick
import QtTest
import QtQuick.Controls

import shared.popups

Item {
    id: root
    width: 800
    height: 900

    Component {
        id: popupComponent

        CreatePasswordPopup {
            parent: root
            passwordStrengthScoreFunction: (password) => 4
            stayLoggedInAvailable: true
            biometricsAvailable: true
        }
    }

    SignalSpy {
        id: submittedSpy
        signalName: "submitted"
    }

    TestCase {
        name: "CreatePasswordPopup"
        when: windowShown

        readonly property string validPassword: "ValidPass1!"

        function cleanup() {
            submittedSpy.target = null
            submittedSpy.clear()
        }

        function createPopup(props) {
            const popup = createTemporaryObject(popupComponent, root, props || {})
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
            submittedSpy.target = popup
            return popup
        }

        function enterPassword(popup, password, confirmation) {
            findChild(popup, "passwordViewNewPassword").text = password
            findChild(popup, "passwordViewNewPasswordConfirm").text = confirmation ?? password
        }

        function confirmButton(popup) {
            return findChild(popup, "createPasswordConfirmButton")
        }

        function test_defaultTitle() {
            const popup = createPopup()
            compare(popup.title, qsTr("Create profile password"))
        }

        function test_customTitle() {
            const popup = createPopup({ title: "Set password to copy address" })
            compare(popup.title, "Set password to copy address")
        }

        function test_noCurrentPasswordAsked() {
            const popup = createPopup()
            compare(findChild(popup, "passwordViewCurrentPassword").visible, false)
            verify(findChild(popup, "passwordViewNewPassword").visible)
            verify(findChild(popup, "passwordViewNewPasswordConfirm").visible)
            verify(findChild(popup, "passwordStrengthIndicator").visible)
        }

        function test_introWithInfo() {
            const popup = createPopup()
            compare(findChild(popup, "createPasswordIntroText").text, qsTr("Can’t be recovered"))
            const info = findChild(popup, "createPasswordInfoButton")
            verify(info.visible)
            compare(info.tooltip.text, qsTr("The password used for this profile can't be recovered,<br/>to adopt this profile you need to set a new password."))
        }

        function test_togglesOnByDefault() {
            const popup = createPopup()
            verify(findChild(popup, "stayLoggedInSwitch").checked)
            verify(findChild(popup, "biometricsSwitch").checked)
        }

        function test_togglesHiddenWhenUnavailable() {
            const popup = createPopup({ stayLoggedInAvailable: false, biometricsAvailable: false })
            compare(findChild(popup, "stayLoggedInSection").visible, false)
            compare(findChild(popup, "biometricsSection").visible, false)
        }

        function test_confirmNeedsMatchingPasswords() {
            const popup = createPopup()
            compare(confirmButton(popup).enabled, false)
            enterPassword(popup, validPassword, "Different1!")
            compare(confirmButton(popup).enabled, false)
            enterPassword(popup, validPassword)
            compare(confirmButton(popup).enabled, true)
        }

        function test_submitsPasswordAndToggles_data() {
            return [
                { tag: "both on", clickStay: false, clickBio: false, stay: true, bio: true },
                { tag: "stay off", clickStay: true, clickBio: false, stay: false, bio: true },
                { tag: "biometrics off", clickStay: false, clickBio: true, stay: true, bio: false },
            ]
        }
        function test_submitsPasswordAndToggles(data) {
            const popup = createPopup()
            if (data.clickStay)
                mouseClick(findChild(popup, "stayLoggedInSwitch"))
            if (data.clickBio)
                mouseClick(findChild(popup, "biometricsSwitch"))
            enterPassword(popup, validPassword)
            mouseClick(confirmButton(popup))

            compare(submittedSpy.count, 1)
            compare(submittedSpy.signalArguments[0][0], validPassword)
            compare(submittedSpy.signalArguments[0][1], data.stay)
            compare(submittedSpy.signalArguments[0][2], data.bio)
        }

        function test_unavailableTogglesSubmitOff() {
            const popup = createPopup({ stayLoggedInAvailable: false, biometricsAvailable: false })
            enterPassword(popup, validPassword)
            mouseClick(confirmButton(popup))

            compare(submittedSpy.count, 1)
            compare(submittedSpy.signalArguments[0][1], false)
            compare(submittedSpy.signalArguments[0][2], false)
        }

        function test_loadingBlocksSubmitAndClose() {
            const popup = createPopup()
            enterPassword(popup, validPassword)
            popup.loading = true
            compare(confirmButton(popup).interactive, false)
            compare(findChild(popup, "createPasswordCancelButton").enabled, false)
            compare(popup.closePolicy, Popup.NoAutoClose)
        }

        // The header close button goes through closeHandler
        function test_cannotBeClosedWhileLoading() {
            const popup = createPopup()
            popup.loading = true
            popup.closeHandler()
            verify(popup.opened)

            popup.loading = false
            popup.closeHandler()
            tryCompare(popup, "opened", false)
        }

        function test_errorShown() {
            const popup = createPopup()
            popup.errorText = "failed"
            const error = findChild(popup, "createPasswordErrorText")
            verify(error.visible)
            compare(error.text, "failed")
        }
    }
}
