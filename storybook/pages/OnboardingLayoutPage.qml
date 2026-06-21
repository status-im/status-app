import QtCore
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import StatusQ
import StatusQ.Core.Backpressure

import AppLayouts.Onboarding
import AppLayouts.Onboarding.enums
import AppLayouts.Onboarding.pages
import AppLayouts.Onboarding.stores

import shared.panels
import utils

import Storybook
import Models

SplitView {
    id: root

    orientation: Qt.Vertical
    readonly property bool landscapeMode: ctrlLandscapeMode.checked
    readonly property real commonLandscapeAspectRatio: 16 / 9
    readonly property real commonPortraitAspectRatio: 9 / 16

    Logs { id: logs }

    QtObject {
        id: mockDriver

        readonly property string mnemonic: "apple banana cat country catalog catch category cattle dog elephant fish cat"
        readonly property string pin: "111111"
        readonly property string password: "somepassword"
    }

    function restart() {
        store.keycardState = Onboarding.KeycardState.NoPCSCService
        store.convertKeycardAccountState = Onboarding.ProgressState.Idle
        store.syncState = Onboarding.ProgressState.Idle
        store.keycardRemainingPinAttempts = Constants.onboarding.defaultPinAttempts
        store.keycardRemainingPukAttempts = Constants.onboarding.defaultPukAttempts

        onboarding.restartFlow()
    }

    LoginAccountsModel {
        id: loginAccountsModel
    }

    ListModel {
        id: emptyModel
    }

    Item {
        id: onboardingViewport
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        OnboardingLayout {
            id: onboarding

            readonly property string focusedObjectName: Window?.activeFocusItem?.objectName ?? ""
            readonly property real landscapeWidthFromHeight: onboardingViewport.height * root.commonLandscapeAspectRatio
            readonly property real portraitWidthFromHeight: onboardingViewport.height * root.commonPortraitAspectRatio

            anchors.centerIn: parent
            height: onboardingViewport.height
            width: root.landscapeMode
                   ? Math.min(onboardingViewport.width, landscapeWidthFromHeight)
                   : Math.min(onboardingViewport.width, portraitWidthFromHeight)

        readonly property Item currentPage: {
            if (stack.topLevelItem instanceof Loader)
                return stack.topLevelItem.item

            return stack.topLevelItem
        }

        onboardingStore: OnboardingStore {
            id: store

            property int keycardState: Onboarding.KeycardState.NoPCSCService
            readonly property string keycardUID: "uid_4"
            readonly property string keycardKeyUID: "uid_4"
            property int convertKeycardAccountState: Onboarding.ProgressState.Idle
            property int syncState: Onboarding.ProgressState.Idle
            readonly property var loginAccountsModel: ctrlLoginScreen.checked ? loginAccountsModel : emptyModel

            property int keycardRemainingPinAttempts: Constants.onboarding.defaultPinAttempts
            property int keycardRemainingPukAttempts: Constants.onboarding.defaultPukAttempts

            // password
            function getPasswordStrengthScore(password: string): int {
                logs.logEvent("OnboardingStore.getPasswordStrengthScore", ["password"], arguments)
                return Math.min(password.length-1, 4)
            }

            // seedphrase/mnemonic
            function validMnemonic(mnemonic: string): bool {
                logs.logEvent("OnboardingStore.validMnemonic", ["mnemonic"], arguments)
                return mnemonic === mockDriver.mnemonic
            }

            function isMnemonicDuplicate(mnemonic: string): bool {
                logs.logEvent("OnboardingStore.isMnemonicDuplicate", ["mnemonic"], arguments)
                return false
            }

            function validateLocalPairingConnectionString(connectionString: string): bool {
                logs.logEvent("OnboardingStore.validateLocalPairingConnectionString", ["connectionString"], arguments)
                return !Number.isNaN(parseInt(connectionString))
            }

            function inputConnectionStringForBootstrapping(connectionString: string) {
                logs.logEvent("OnboardingStore.inputConnectionStringForBootstrapping", ["connectionString"], arguments)
            }

            // password signals
            signal accountLoginError(string error, bool wrongPassword)

            // (test) error handler
            onAccountLoginError: function (error, wrongPassword) {
                logs.logEvent("OnboardingStore.accountLoginError", ["error", "wrongPassword"], arguments)
                ctrlLoginResult.result = "<font color='red'>⛔</font>"
                onboarding.restartFlow()
            }
        }

        availableLanguages: ["de", "cs", "en", "en_CA", "ko", "ar", "fr", "fr_CA", "pt_BR", "pt", "uk", "ja", "el"]
        currentLanguage: "en"

        onChangeLanguageRequested: function(language) {
            logs.logEvent("onChangeLanguageRequested", ["language"], arguments)
            currentLanguage = language
        }

        keychain: keychain
        isKeycardEnabled: ctrlKeycard.checked

        privacyModeFeatureEnabled: ctryPrivacyModelEnabled.checked

        onFinished: function(flow, data) {
            console.warn("!!! ONBOARDING FINISHED; flow:", flow, "; data:", JSON.stringify(data))
            logs.logEvent("onFinished", ["flow", "data"], arguments)

            if (flow === Onboarding.OnboardingFlow.LoginWithLostKeycardSeedphrase) {
                store.convertKeycardAccountState = Onboarding.ProgressState.InProgress // SIMULATION
                stack.push(convertingKeycardAccountPage)
                Backpressure.debounce(root, 3000, () => {
                    console.warn("!!! SIMULATION: CONVERTING KEYCARD")
                    store.convertKeycardAccountState = Onboarding.ProgressState.Success // SIMULATION
                })()
                return
            }

            console.warn("!!! SIMULATION: SHOWING SPLASH")
            stack.push(splashScreen, { runningProgressAnimation: true })
        }

        onLoginRequested: function(keyUid, method, data) {
            logs.logEvent("onLoginRequested", ["keyUid", "method", "data"], arguments)

            // SIMULATION: emit an error in case of wrong password or PIN
            if (method === Onboarding.LoginMethod.Password && data.password !== mockDriver.password) {
                onboardingStore.accountLoginError("", true)
            } else if (method === Onboarding.LoginMethod.Keycard && data.pin !== mockDriver.pin) {
                onboardingStore.keycardRemainingPinAttempts-- // SIMULATION: decrease the remaining PIN attempts
                if (onboardingStore.keycardRemainingPinAttempts <= 0) { // SIMULATION: "block" the keycard
                    onboardingStore.keycardState = Onboarding.KeycardState.BlockedPIN
                    onboardingStore.keycardRemainingPinAttempts = 0
                }
                onboardingStore.accountLoginError("", true)
            } else {
                ctrlLoginResult.result = "<font color='green'>✔</font>"
                stack.push(splashScreen, { runningProgressAnimation: true })
            }
        }

        Button {
            text: "Paste password"
            focusPolicy: Qt.NoFocus

            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 10

            visible: onboarding.focusedObjectName === "loginPasswordInput" ||
                     onboarding.focusedObjectName === "passwordViewNewPassword" ||
                     onboarding.focusedObjectName === "passwordViewNewPasswordConfirm"

            onClicked: {
                const currentItem = onboarding.stack.currentItem

                const loginPassInput = StorybookUtils.findChild(
                                         currentItem,
                                         "loginPasswordInput")
                if (!!loginPassInput)
                    loginPassInput.text = mockDriver.password

                const input1 = StorybookUtils.findChild(
                                 currentItem,
                                 "passwordViewNewPassword")
                const input2 = StorybookUtils.findChild(
                                 currentItem,
                                 "passwordViewNewPasswordConfirm")

                if (!input1 || !input2)
                    return

                input1.text = mockDriver.password
                input2.text = mockDriver.password
            }
        }

        Button {
            text: "Copy seed phrase to keyboard"
            focusPolicy: Qt.NoFocus

            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 10

            visible: onboarding.focusedObjectName.startsWith("enterSeedPhraseInputField")

            onClicked: ClipboardUtils.setText(mockDriver.mnemonic)
        }

        Button {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 10

            visible: ctrlLoginScreen.checked ? onboarding.currentPage.selectedProfileIsKeycard && store.keycardState === Onboarding.KeycardState.NotEmpty && onboarding.focusedObjectName === "pinInputTextInput"
                                             : onboarding.focusedObjectName === "pinInputTextInput"

            text: "Copy valid PIN (\"%1\")".arg(mockDriver.pin)
            focusPolicy: Qt.NoFocus
            onClicked: ClipboardUtils.setText(mockDriver.pin)
        }

        Button {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 10

            visible: onboarding.focusedObjectName.startsWith("seedInput_")

            text: "Paste seed phrase verification"
            focusPolicy: Qt.NoFocus
            onClicked: {
                const words = Utils.splitWords(mockDriver.mnemonic)

                for (let i = 0;; i++) {
                    const input = StorybookUtils.findChild(
                                    onboarding.currentPage,
                                    `seedInput_${i}`)

                    if (input === null)
                        break

                    const index = input.seedWordIndex
                    input.text = words[index]
                }
            }
        }
        }
    }

    KeychainMock {
        id: keychain

        parent: root
        available: ctrlBiometrics.checked

        readonly property alias touchIdChecked: ctrlTouchIdUser.checked
        onTouchIdCheckedChanged: onboarding.keychainChanged()

        function hasCredential(account) {
            const isKeycard = onboarding.currentPage.toString().startsWith("LoginScreen")
                            && onboarding.currentPage.selectedProfileIsKeycard

            keychain.saveCredential(account, isKeycard ? mockDriver.pin : mockDriver.password)

            return touchIdChecked ? Keychain.StatusSuccess
                                  : Keychain.StatusNotFound
        }
    }

    Component {
        id: splashScreen

        DidYouKnowSplashScreen {
            readonly property bool backAvailableHint: false
            property bool runningProgressAnimation

            NumberAnimation on progress {
                from: 0.0
                to: 1
                duration: 3000
                running: runningProgressAnimation
                onStopped: {
                    console.warn("!!! SPLASH SCREEN DONE")
                    console.warn("!!! RESTARTING FLOW")
                    root.restart()
                }
            }
        }
    }

    Component {
        id: convertingKeycardAccountPage

        ConvertKeycardAccountPage {
            convertKeycardAccountState: store.convertKeycardAccountState
            onRestartRequested: {
                logs.logEvent("restartRequested")
                root.restart()
            }
            onBackToLoginRequested: {
                logs.logEvent("backToLoginRequested")
                root.restart()
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 300
        SplitView.preferredHeight: 300

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            spacing: 10

            TextField {
                Layout.fillWidth: true

                function stackToText(stack) {
                    let content = ""

                    for (let i = 0; i < stack.depth; i++) {
                        const stackEntry = stack.get(i, StackView.ForceLoad)

                        if (stackEntry instanceof StackView)
                            content += " [" + InspectionUtils.baseName(stackEntry) + ": " + stackToText(stackEntry) + "]"
                        else
                            content += " " + InspectionUtils.baseName(stackEntry instanceof Loader
                                                                    ? stackEntry.item : stackEntry)
                    }

                    return content
                }

                text: {
                    const stack = onboarding.stack

                    // trigger change when only current item changes on replace
                    stack.topLevelItem

                    return `Stack (${stack.totalDepth}): ${stackToText(stack)}`
                }

                background: null
                readOnly: true
                selectByMouse: true
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true

                Button {
                    text: "Restart"
                    focusPolicy: Qt.NoFocus
                    onClicked: root.restart()
                }

                Switch {
                    id: ctrlBiometrics
                    text: "Biometrics available"
                    checked: true
                }

                Switch {
                    id: ctrlLandscapeMode
                    text: "Landscape mode"
                    checked: true
                }

                Switch {
                    id: ctrlKeycard
                    text: "Keycard enabled"
                    checked: true
                }

                Switch {
                    id: ctryPrivacyModelEnabled
                    text: "Privacy Mode Feature Enabled"
                    checked: true
                }

                ToolSeparator {}

                Switch {
                    id: ctrlLoginScreen
                    text: "Show login screen"
                    checkable: true
                    onToggled: root.restart()
                }

                Switch {
                    id: ctrlTouchIdUser
                    text: "Touch ID login"
                    visible: ctrlLoginScreen.checked
                    enabled: ctrlBiometrics.checked
                    checked: ctrlBiometrics.checked
                }

                Text {
                    id: ctrlLoginResult
                    property string result: "🯄"
                    visible: ctrlLoginScreen.checked
                    text: "Login result: %1".arg(result)
                }

                Button {
                    text: "Unwind"
                    visible: ctrlLoginScreen.checked && onboarding.stack.depth > 1 && !onboarding.currentPage.toString().startsWith("DidYouKnowSplashScreen")
                    onClicked: onboarding.unwindToLoginScreen()
                }

                Button {
                    text: "Simulate login error"
                    visible: ctrlLoginScreen.checked && onboarding.currentPage.toString().startsWith("DidYouKnowSplashScreen")
                    onClicked: onboarding.onboardingStore.accountLoginError("SIMULATION: Something bad happened", false)
                }
            }

            RowLayout {
                Label {
                    text: "Keycard state:"
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 2

                    ButtonGroup {
                        id: keycardStateButtonGroup
                    }

                    Repeater {
                        model: Onboarding.getModelFromEnum("KeycardState")

                        RoundButton {
                            text: modelData.name
                            checkable: true
                            checked: store.keycardState === modelData.value

                            ButtonGroup.group: keycardStateButtonGroup

                            onClicked: {
                                store.keycardState = modelData.value
                                ctrlLoginResult.result = "🯄"
                            }
                        }
                    }
                }
            }

            RowLayout {
                Label {
                    text: "Sync state:"
                }

                Flow {
                    spacing: 2

                    ButtonGroup {
                        id: syncStateButtonGroup
                    }

                    Repeater {
                        model: Onboarding.getModelFromEnum("LocalPairingState")

                        RoundButton {
                            text: modelData.name
                            checkable: true
                            checked: store.syncState === modelData.value

                            ButtonGroup.group: syncStateButtonGroup

                            onClicked: store.syncState = modelData.value
                        }
                    }
                }

                ToolSeparator {}

                Label {
                    text: "Convert Keycard Account state:"
                }

                Flow {
                    spacing: 2

                    ButtonGroup {
                        id: convertKeycardAccountButtonGroup
                    }

                    Repeater {
                        model: Onboarding.getModelFromEnum("ProgressState")

                        RoundButton {
                            text: modelData.name
                            checkable: true
                            checked: store.convertKeycardAccountState === modelData.value

                            ButtonGroup.group: convertKeycardAccountButtonGroup

                            onClicked: store.convertKeycardAccountState = modelData.value
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    Settings {
        property alias useBiometrics: ctrlBiometrics.checked
        property alias showLoginScreen: ctrlLoginScreen.checked
        property alias useTouchId: ctrlTouchIdUser.checked
        property alias keycardEnabled: ctrlKeycard.checked
        property alias landscapeMode: ctrlLandscapeMode.checked
    }
}

// category: Onboarding
// status: good
// https://www.figma.com/design/Lw4nPYQcZOPOwTgETiiIYo/Desktop-Onboarding-Redesign?node-id=1-25&node-type=canvas&m=dev
