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

    signal setPasswordRequested(string password)

    title: qsTr("Create profile password")

    QtObject {
        id: d

        function submit() : void {
            if (!passView.ready)
                return
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
