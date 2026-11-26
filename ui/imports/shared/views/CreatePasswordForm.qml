import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups

// New password with the "Stay logged in" and biometrics opt-ins, both on by default
ColumnLayout {
    id: root

    property var passwordStrengthScoreFunction: (password) => { console.error("passwordStrengthScoreFunction: IMPLEMENT ME") }
    property bool stayLoggedInAvailable: false
    property bool biometricsAvailable: false
    property string title
    property bool titleVisible: true
    property string introText: qsTr("This password can’t be recovered")
    // When set, the intro gets an info button with this tooltip
    property string introInfoText
    property bool busy: false

    readonly property bool ready: passView.ready
    readonly property string password: passView.newPswText
    readonly property bool stayLoggedIn: root.stayLoggedInAvailable && d.stayLoggedIn
    readonly property bool enableBiometrics: root.biometricsAvailable && d.enableBiometrics

    signal submitRequested()

    function forceInputFocus() : void {
        passView.forceNewPswInputFocus()
    }

    spacing: Theme.padding

    QtObject {
        id: d

        property bool stayLoggedIn: true
        property bool enableBiometrics: true
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        visible: !!root.introInfoText
        spacing: Theme.halfPadding

        StatusBaseText {
            objectName: "createPasswordIntroText"
            text: root.introText
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.baseColor1
        }
        StatusFlatRoundButton {
            objectName: "createPasswordInfoButton"
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 24
            implicitHeight: 24
            icon.width: 16
            icon.height: 16
            icon.name: "info"
            type: StatusFlatRoundButton.Type.Tertiary
            tooltip.text: root.introInfoText
        }
    }
    PasswordView {
        id: passView
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        highSizeIntro: true
        title: root.title
        titleVisible: root.titleVisible
        introText: root.introInfoText ? "" : root.introText
        recoverText: ""
        passwordStrengthScoreFunction: root.passwordStrengthScoreFunction
        onReturnPressed: root.submitRequested()
    }
    StayLoggedInSectionView {
        objectName: "stayLoggedInSection"
        Layout.fillWidth: true
        visible: root.stayLoggedInAvailable
        storageAvailable: root.stayLoggedInAvailable
        profileMigrated: true // new profiles use the DEK encryption scheme from birth
        stayLoggedInEnabled: d.stayLoggedIn
        busy: root.busy
        onToggleStayLoggedIn: (checked) => d.stayLoggedIn = !checked
    }
    StatusModalDivider {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        visible: root.stayLoggedInAvailable && root.biometricsAvailable
    }
    BiometricsSectionView {
        objectName: "biometricsSection"
        Layout.fillWidth: true
        visible: root.biometricsAvailable
        enabled: !root.busy
        biometricsAvailable: root.biometricsAvailable
        biometricsEnabled: d.enableBiometrics
        onToggleBiometrics: (checked) => d.enableBiometrics = !checked
    }
}
