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

        property bool stayLoggedIn: true // default ON for new users (per acceptance criteria)
        property bool enableBiometrics: false // explicit opt-in

        function submit() : void {
            if (!passView.ready)
                return
            root.stayLoggedInRequested(root.stayLoggedInAvailable && d.stayLoggedIn)
            root.enableBiometricsRequested(root.biometricsAvailable && d.enableBiometrics)
            root.setPasswordRequested(passView.newPswText)
        }
    }

    Component.onCompleted: passView.forceNewPswInputFocus()

    contentItem: Item {
        ColumnLayout {
            spacing: Theme.padding
            anchors.centerIn: parent
            width: Math.min(400, root.availableWidth)

            PasswordView {
                id: passView
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                highSizeIntro: true
                title: root.title
                introText: qsTr("This password can’t be recovered")
                recoverText: ""
                passwordStrengthScoreFunction: root.passwordStrengthScoreFunction
                onReturnPressed: d.submit()
            }
            StayLoggedInSectionView {
                objectName: "stayLoggedInSection"
                Layout.fillWidth: true
                visible: root.stayLoggedInAvailable
                storageAvailable: root.stayLoggedInAvailable
                profileMigrated: true // new profiles use the DEK encryption scheme from birth
                stayLoggedInEnabled: d.stayLoggedIn
                onToggleStayLoggedIn: (checked) => d.stayLoggedIn = !checked
            }
            StatusModalDivider {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
            }
            BiometricsSectionView {
                objectName: "biometricsSection"
                Layout.fillWidth: true
                visible: root.biometricsAvailable
                biometricsAvailable: root.biometricsAvailable
                biometricsEnabled: d.enableBiometrics
                onToggleBiometrics: (checked) => d.enableBiometrics = !checked
            }
            StatusButton {
                objectName: "btnConfirmPassword"
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Confirm password")
                enabled: passView.ready
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
