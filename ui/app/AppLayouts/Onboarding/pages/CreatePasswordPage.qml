import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups

import utils
import shared.views

import AppLayouts.Onboarding.controls

OnboardingPage {
    id: root

    property var passwordStrengthScoreFunction: (password) => { console.error("passwordStrengthScoreFunction: IMPLEMENT ME") }

    // Whether the "Stay logged in" opt-in is offered (requires platform secure storage)
    property bool stayLoggedInAvailable: false
    // Whether the biometrics opt-in is offered
    property bool biometricsAvailable: false

    signal setPasswordRequested(string password)
    signal stayLoggedInRequested(bool enabled)
    signal enableBiometricsRequested(bool enable)

    title: qsTr("Create profile password")

    QtObject {
        id: d

        function submit() : void {
            if (!form.ready)
                return
            root.stayLoggedInRequested(form.stayLoggedIn)
            root.enableBiometricsRequested(form.enableBiometrics)
            root.setPasswordRequested(form.password)
        }
    }

    Component.onCompleted: form.forceInputFocus()

    contentItem: Item {
        ColumnLayout {
            spacing: Theme.padding
            anchors.centerIn: parent
            width: Math.min(400, root.availableWidth)

            CreatePasswordForm {
                id: form
                Layout.fillWidth: true
                title: root.title
                passwordStrengthScoreFunction: root.passwordStrengthScoreFunction
                stayLoggedInAvailable: root.stayLoggedInAvailable
                biometricsAvailable: root.biometricsAvailable
                onSubmitRequested: d.submit()
            }
            StatusButton {
                objectName: "btnConfirmPassword"
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Confirm password")
                enabled: form.ready
                onClicked: d.submit()
            }
        }
    }

    OnboardingInfoButton {
        anchors.right: parent.right
        anchors.top: parent.top
        objectName: "infoButton"
        onClicked: passwordDetailsPopup.createObject(root).open()
    }

    Component {
        id: passwordDetailsPopup
        StatusSimpleTextPopup {
            objectName: "passwordDetailsPopup"
            title: qsTr("Create profile password")
            okButtonText: qsTr("Got it")
            width: 480
            destroyOnClose: true
            content.text: qsTr("Your Status keys are the foundation of your self-sovereign identity in Web3. You have complete control over these keys, which you can use to sign transactions, access your data, and interact with Web3 services.

Your keys are always securely stored on your device and protected by your Status profile password. Status doesn't know your password and can't reset it for you. If you forget your password, you may lose access to your Status profile and wallet funds.

Remember your password and don't share it with anyone.")
        }
    }
}
