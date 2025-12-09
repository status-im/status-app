import QtCore
import QtQuick

import QtQml.Models
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Backpressure

import AppLayouts.Onboarding.enums
import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.controls
import AppLayouts.Onboarding.components

import utils

import QtModelsToolkit

OnboardingPage {
    id: root

    required property int keycardState
    required property string keycardUID
    required property int keycardRemainingPinAttempts
    required property int keycardRemainingPukAttempts

    // [{keyUid:string, username:string, thumbnailImage:string, colorId:int, order:int, keycardCreatedAccount:bool}]
    required property var loginAccountsModel

    // list of language/locale codes, e.g. ["cs_CZ","ko","fr"]
    required property var availableLanguages
    // language currently selected for translations, e.g. "cs"
    required property string currentLanguage

    // allows to set if currently selected account can be logged in using biometrics
    property bool isBiometricsLogin
    property bool isKeycardEnabled: true

    readonly property string selectedProfileKeyId: loginUserSelector.selectedProfileKeyId
    readonly property bool selectedProfileIsKeycard: d.currentProfileIsKeycard

    signal biometricsRequested(string profileId)
    signal dismissBiometricsRequested
    signal changeLanguageRequested(string newLanguageCode)

    function setBiometricResponse(secret: string, error = "") {
        if (!root.isBiometricsLogin)
            return

        const hasError = !!error

        d.biometricsSuccessful = secret !== ""
        d.biometricsFailed = hasError

        if (hasError) {
            if (d.currentProfileIsKeycard) {
                keycardBox.clear()
            } else {
                passwordBox.validationError = error
                passwordBox.detailedError = ""
                passwordBox.clear()
                passwordBox.forceActiveFocus()
            }

            return
        }

        if (d.currentProfileIsKeycard) {
            keycardBox.setPin(secret) // automatic login, emits loginRequested() already
        } else {
            passwordBox.validationError = ""
            passwordBox.password = secret
            d.doPasswordLogin(secret)
        }
    }

    // -> "keyUid:string": User ID to login; "method:int": password or keycard (cf Onboarding.LoginMethod.*) enum;
    //    "data:var": contains "password" or "pin"
    signal loginRequested(string keyUid, int method, var data)

    // "internal" onboarding signals, starting other flows
    signal onboardingCreateProfileFlowRequested()
    signal onboardingLoginFlowRequested()
    signal unblockWithSeedphraseRequested()
    signal unblockWithPukRequested()
    signal lostKeycardFlowRequested()
    signal keycardRequested()

    QtObject {
        id: d

        property bool biometricsSuccessful
        property bool biometricsFailed

        readonly property bool currentProfileIsKeycard: loginUserSelector.keycardCreatedAccount
        readonly property bool isWrongKeycard: !!root.keycardUID && loginUserSelector.selectedProfileKeyId !== root.keycardUID

        readonly property int loginModelCount: root.loginAccountsModel.ModelCount.count
        onLoginModelCountChanged: setSelectedLoginUser()

        onCurrentProfileIsKeycardChanged: {
            if (d.currentProfileIsKeycard) {
                root.keycardRequested()
            }
        }

        function setSelectedLoginUser() {
            if (loginModelCount > 0) {
                loginUserSelector.setSelection(d.settings.lastKeyUid)
                if (!d.currentProfileIsKeycard)
                    passwordBox.forceActiveFocus()
            }
        }

        readonly property var settings: Settings { /* https://bugreports.qt.io/browse/QTBUG-135039 */
            category: "Login"
            property string lastKeyUid
        }

        function resetBiometricsResult() {
            d.biometricsSuccessful = false
            d.biometricsFailed = false
        }

        function doPasswordLogin(password: string) {
            if (password.length === 0)
                return

            root.loginRequested(root.selectedProfileKeyId, Onboarding.LoginMethod.Password, { password })
        }

        function doKeycardLogin(pin: string) {
            if (pin.length === 0)
                return

            root.loginRequested(root.selectedProfileKeyId, Onboarding.LoginMethod.Keycard, { pin })
        }
    }

    onKeycardStateChanged: {
        Qt.callLater(() => {
            if (!isBiometricsLogin || !d.currentProfileIsKeycard
                || root.keycardState !== Onboarding.KeycardState.NotEmpty)
                return

            root.biometricsRequested(loginUserSelector.selectedProfileKeyId)
        })
    }

    Component.onCompleted: {
        d.setSelectedLoginUser()
    }

    // login errors reporting
    function setAccountLoginError(error: string, wrongPassword: bool) {
        if (!error && !wrongPassword) {
            return
        }

        // reset the biometrics status in case of error
        d.biometricsFailed = false
        d.biometricsSuccessful = false

        if (d.currentProfileIsKeycard) { // Login with keycard
            if (wrongPassword) {
                keycardBox.loginError = ""
                keycardBox.markAsWrongPin()
            } else {
                keycardBox.loginError = error
            }
        } else { // Login with password
            if (wrongPassword) {
                passwordBox.validationError = qsTr("Password incorrect. %1").arg("<a href='#password'>" + qsTr("Forgot password?") + "</a>")
                passwordBox.detailedError = ""
            } else {
                passwordBox.validationError = qsTr("Login failed. %1").arg("<a href='#details'>" + qsTr("Show details.") + "</a>")
                passwordBox.detailedError = error
            }

            passwordBox.clear()
            passwordBox.forceActiveFocus()
        }
    }

    padding: 40

    contentItem: Item {
        ColumnLayout {
            width: Math.min(340, parent.width)
            anchors.centerIn: parent
            spacing: Theme.padding

            StatusImage {
                Layout.preferredWidth: 90
                Layout.preferredHeight: 90
                Layout.alignment: Qt.AlignHCenter
                source: Assets.png("status")
                mipmap: true
            }

            StatusBaseText {
                id: headerText
                Layout.fillWidth: true
                text: qsTr("Welcome back")
                font.pixelSize: Theme.fontSize(22)
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            LoginUserSelector {
                id: loginUserSelector
                objectName: "loginUserSelector"

                Layout.topMargin: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                model: root.loginAccountsModel
                currentKeycardLocked: root.keycardState === Onboarding.KeycardState.BlockedPIN ||
                                      root.keycardState === Onboarding.KeycardState.BlockedPUK
                isKeycardEnabled: root.isKeycardEnabled

                onSelectedProfileKeyIdChanged: {
                    root.dismissBiometricsRequested()

                    d.resetBiometricsResult()
                    d.settings.lastKeyUid = selectedProfileKeyId

                    if (d.currentProfileIsKeycard) {
                        keycardBox.loginError = ""
                        keycardBox.clear()
                    } else {
                       passwordBox.validationError = ""
                       passwordBox.clear()
                       passwordBox.forceActiveFocus()
                    }

                    Qt.callLater(() => {
                        if (!root || !root.isBiometricsLogin)
                            return

                        if (d.currentProfileIsKeycard && root.keycardState !== Onboarding.KeycardState.NotEmpty)
                            return

                        root.biometricsRequested(loginUserSelector.selectedProfileKeyId)
                    })
                }
                onOnboardingCreateProfileFlowRequested: root.onboardingCreateProfileFlowRequested()
                onOnboardingLoginFlowRequested: root.onboardingLoginFlowRequested()
            }

            LoginPasswordBox {
                Layout.fillWidth: true
                id: passwordBox
                objectName: "passwordBox"
                visible: !d.currentProfileIsKeycard
                enabled: !!loginUserSelector.selectedProfileKeyId
                isBiometricsLogin: root.isBiometricsLogin
                biometricsSuccessful: d.biometricsSuccessful
                biometricsFailed: d.biometricsFailed
                onPasswordEditedManually: {
                    // reset state when typing the pass manually; not to break the bindings inside the component
                    validationError = ""
                    d.resetBiometricsResult()
                }
                onDetailedErrorPopupRequested: detailedErrorPopupComp.createObject(root, {detailedError}).open()
                onBiometricsRequested: root.biometricsRequested(loginUserSelector.selectedProfileKeyId)
                onLoginRequested: (password) => d.doPasswordLogin(password)
            }

            LoginKeycardBox {
                Layout.fillWidth: true
                id: keycardBox
                objectName: "keycardBox"
                visible: d.currentProfileIsKeycard
                isBiometricsLogin: root.isBiometricsLogin
                biometricsSuccessful: d.biometricsSuccessful
                biometricsFailed: d.biometricsFailed
                keycardState: root.keycardState
                isWrongKeycard: d.isWrongKeycard
                keycardRemainingPinAttempts: root.keycardRemainingPinAttempts
                keycardRemainingPukAttempts: root.keycardRemainingPukAttempts
                onUnblockWithSeedphraseRequested: root.unblockWithSeedphraseRequested()
                onUnblockWithPukRequested: root.unblockWithPukRequested()
                onPinEditedManually: {
                    // reset state when typing the PIN manually; not to break the bindings inside the component
                    loginError = ""
                    d.resetBiometricsResult()
                }
                onDetailedErrorPopupRequested: detailedErrorPopupComp.createObject(root, {detailedError: loginError}).open()
                onBiometricsRequested: root.biometricsRequested(loginUserSelector.selectedProfileKeyId)
                onLoginRequested: (pin) => d.doKeycardLogin(pin)
            }

            Item { Layout.fillHeight: true }

            StatusButton {
                objectName: "lostKeycardButon"

                Layout.alignment: Qt.AlignHCenter

                isOutline: true
                size: StatusBaseButton.Size.Small
                visible: d.currentProfileIsKeycard
                text: qsTr("Lost this Keycard?")

                onClicked: root.lostKeycardFlowRequested()
            }
        }
    }

    StatusLanguageSelector {
        anchors.right: parent.right
        anchors.top: parent.top
        currentLanguage: root.currentLanguage
        languageCodes: root.availableLanguages
        onLanguageSelected: (languageCode) => root.changeLanguageRequested(languageCode)
    }

    Component {
        id: detailedErrorPopupComp
        StatusSimpleTextPopup {
            property string detailedError

            title: qsTr("Login failed")
            width: 480
            destroyOnClose: true
            content.color: Theme.palette.dangerColor1
            content.text: detailedError
            footer: StatusDialogFooter {
                spacing: Theme.padding
                rightButtons: ObjectModel {
                    StatusFlatButton {
                        icon.name: "copy"
                        text: qsTr("Copy error message")
                        onClicked: {
                            icon.name = "tiny/checkmark"
                            ClipboardUtils.setText(detailedError)
                            Backpressure.debounce(this, 1500, () => icon.name = "copy")()
                        }
                    }
                    StatusButton {
                        text: qsTr("Close")
                        onClicked: close()
                    }
                }
            }
        }
    }
}
