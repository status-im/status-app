import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import Storybook

import utils
import shared.popups.keycard

SplitView {
    id: root
    orientation: Qt.Horizontal
    property int portraitTopSafeArea: 0
    property int portraitBottomSafeArea: 0
    property int landscapeTopSafeArea: 0
    property int landscapeBottomSafeArea: 0

    Logs {
        id: logs
    }

    property QtObject userProfile: QtObject {
        property bool usingBiometricLogin: false
        property bool isKeycardUser: false
        property string pubKey: "0x1234567890abcdef"
    }

    ListModel {
        id: accountsModel
        Component.onCompleted: {
            append([
                {
                    account: {
                        name: "Main account",
                        emoji: "😎",
                        colorId: "purple",
                        address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
                        path: "m/44'/60'/0'/0/0",
                        balance: "1.2345"
                    }
                },
                {
                    account: {
                        name: "Savings",
                        emoji: "🚀",
                        colorId: "army",
                        address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8888",
                        path: "m/44'/60'/0'/0/1",
                        balance: "12.001"
                    }
                }
            ])
        }
    }

    ListModel {
        id: keyPairListModel
        Component.onCompleted: {
            append([
                {
                    keyPair: {
                        keyUid: "profile-key-uid",
                        pubKey: userProfile.pubKey,
                        name: "Profile",
                        image: "",
                        icon: "",
                        pairType: Constants.keycard.keyPairType.profile,
                        migratedToKeycard: false,
                        derivedFrom: "",
                        locked: false,
                        accounts: accountsModel,
                        containsPathOutOfTheDefaultStatusDerivationTree: function() { return false }
                    }
                },
                {
                    keyPair: {
                        keyUid: "seed-key-uid",
                        pubKey: "",
                        name: "Seed phrase keypair",
                        image: "",
                        icon: "key_pair_seed_phrase",
                        pairType: Constants.keycard.keyPairType.seedImport,
                        migratedToKeycard: false,
                        derivedFrom: "",
                        locked: false,
                        accounts: accountsModel,
                        containsPathOutOfTheDefaultStatusDerivationTree: function() { return false }
                    }
                }
            ])
        }
    }

    QtObject {
        id: keyPairHelper
        property string keyUid: "seed-key-uid"
        property string name: "Seed phrase keypair"
        property string icon: "key_pair_seed_phrase"
        property string image: ""
        property string derivedFrom: ""
        property bool locked: false
        property var accounts: accountsModel
        property var observedAccount: ({
            name: "Main account",
            emoji: "😎",
            colorId: "purple",
            address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
            path: "m/44'/60'/0'/0/0",
            balance: "1.2345"
        })
        function setAccountAtIndexAsObservedAccount(index) {
            if (index >= 0 && index < accounts.count)
                observedAccount = accounts.get(index).account
        }
    }

    QtObject {
        id: keyPairForProcessing
        property int pairType: Constants.keycard.keyPairType.profile
        property string keyUid: "profile-key-uid"
        property string name: "Profile"
        property string icon: ""
        property string image: ""
        property string derivedFrom: ""
        property bool locked: false
        property var accounts: accountsModel
        property var observedAccount: ({
            name: "Main account",
            emoji: "😎",
            colorId: "purple",
            address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
            path: "m/44'/60'/0'/0/0",
            balance: "1.2345"
        })

        function removeAccountAtIndex(index) {
            if (index >= 0 && index < accounts.count)
                accounts.remove(index, 1)
        }

        function setAccountAtIndexAsObservedAccount(index) {
            if (index >= 0 && index < accounts.count)
                observedAccount = accounts.get(index).account
        }
    }

    QtObject {
        id: emojiPopupMock
        property var directParent: null
        property real relativeY: 0
        property int emojiSize: 0
        signal emojiSelected(string emojiText, bool atCursor)
        function open() {}
    }

    QtObject {
        id: sharedKeycardModule
        property bool disablePopup: false
        property bool forceFlow: false
        property bool keyPairStoredOnKeycardIsKnown: true
        // Nim API exposes keycardData as string; JS bitwise ops still work on numeric strings.
        property string keycardData: "0"
        property int remainingAttempts: -1

        property string _pin: ""
        property string _puk: ""
        property string _password: ""
        property string _newPassword: ""
        property string _pairingCode: ""
        property string _mnemonic: "abandon ability able about above absent absorb abstract absurd abuse access accident"

        property var keyPairModel: keyPairListModel
        property var keyPairHelper: keyPairHelper
        property var keyPairForProcessing: keyPairForProcessing

        property QtObject currentState: QtObject {
            property string flowType: Constants.keycardSharedFlow.setupNewKeycard
            property string stateType: Constants.keycardSharedState.keycardFlowStarted
            property bool displayBackButton: true
            function doBackAction() { logs.logEvent("currentState.doBackAction()") }
            function doPrimaryAction() { logs.logEvent("currentState.doPrimaryAction()") }
            function doSecondaryAction() { logs.logEvent("currentState.doSecondaryAction()") }
            function doCancelAction() { logs.logEvent("currentState.doCancelAction()") }
        }

        function migratingProfileKeyPair() {
            return keyPairForProcessing.keyUid === "profile-key-uid"
        }

        function remainingAccountCapacity() {
            return 5
        }

        function setSelectedKeyPair(keyUid) {
            logs.logEvent("setSelectedKeyPair(%1)".arg(keyUid))
        }

        function setPin(pin) { _pin = pin }
        function setPuk(puk) { _puk = puk }
        function setPairingCode(code) { _pairingCode = code }
        function setPassword(password) { _password = password }
        function setNewPassword(password) { _newPassword = password }
        function getNewPassword() { return _newPassword }
        function getSeedPhrase() { return _mnemonic }
        function getNameFromKeycard() { return "Original Keycard Name" }

        function checkRepeatedKeycardPinWhileTyping(pin) { return pin === _pin }
        function checkRepeatedKeycardPukWhileTyping(puk) { return puk === _puk }

        function getMnemonic() { return _mnemonic }
        function setSeedPhrase(seedPhrase) { _mnemonic = seedPhrase }
        function validSeedPhrase(seedPhrase) {
            const words = seedPhrase.trim().split(/\s+/)
            return words.length === 12 || words.length === 24
        }
    }

    readonly property var presets: [
        { label: "Init: Flow started", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.keycardFlowStarted },
        { label: "Init: Plug reader", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.pluginReader },
        { label: "Init: Metadata display", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.keycardMetadataDisplay },
        { label: "Confirmation: Factory reset", flow: Constants.keycardSharedFlow.factoryReset, state: Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata },
        { label: "Select key pair", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.selectExistingKeyPair },
        { label: "PIN: Enter PIN", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.enterPin },
        { label: "PIN: Wrong PIN", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.wrongPin },
        { label: "PUK: Enter PUK", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.enterPuk },
        { label: "Seed: Enter phrase", flow: Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase, state: Constants.keycardSharedState.enterSeedPhrase },
        { label: "Seed: Display phrase", flow: Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase, state: Constants.keycardSharedState.seedPhraseDisplay },
        { label: "Seed: Confirm words", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.seedPhraseEnterWords },
        { label: "Password: Enter", flow: Constants.keycardSharedFlow.authentication, state: Constants.keycardSharedState.enterPassword },
        { label: "Password: Create", flow: Constants.keycardSharedFlow.migrateFromKeycardToApp, state: Constants.keycardSharedState.createPassword },
        { label: "Password: Confirm", flow: Constants.keycardSharedFlow.migrateFromKeycardToApp, state: Constants.keycardSharedState.confirmPassword },
        { label: "Name keycard", flow: Constants.keycardSharedFlow.renameKeycard, state: Constants.keycardSharedState.enterKeycardName },
        { label: "Manage accounts", flow: Constants.keycardSharedFlow.importFromKeycard, state: Constants.keycardSharedState.manageKeycardAccounts },
        { label: "Pairing code", flow: Constants.keycardSharedFlow.changePairingCode, state: Constants.keycardSharedState.createPairingCode },
        { label: "Success: keypair migrate", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.keyPairMigrateSuccess },
        { label: "Failure: keypair migrate", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.keyPairMigrateFailure },
        { label: "Limit: max PIN retries", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.maxPinRetriesReached }
    ]

    readonly property var keycardInitStates: [
        { label: "Flow started", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.keycardFlowStarted },
        { label: "Plug reader", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.pluginReader },
        { label: "Tap or insert Keycard", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.insertKeycard },
        { label: "Keycard inserted", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.keycardInserted },
        { label: "Reading Keycard", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.readingKeycard },
        { label: "Recognized Keycard", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.recognizedKeycard },
        { label: "No PCSC service", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.noPCSCService },
        { label: "Not a Keycard", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.notKeycard },
        { label: "Wrong Keycard", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.wrongKeycard },
        { label: "Unlock options", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.unlockKeycardOptions },
        { label: "Keycard empty metadata", flow: Constants.keycardSharedFlow.migrateFromAppToKeycard, state: Constants.keycardSharedState.keycardEmptyMetadata },
        { label: "Keycard empty", flow: Constants.keycardSharedFlow.authentication, state: Constants.keycardSharedState.keycardEmpty },
        { label: "Keycard not empty", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.keycardNotEmpty },
        { label: "Max PIN retries", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.maxPinRetriesReached },
        { label: "Max PUK retries", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.maxPukRetriesReached },
        { label: "Max pairing slots", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.maxPairingSlotsReached },
        { label: "Keycard already unlocked", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.keycardAlreadyUnlocked },
        { label: "Metadata display", flow: Constants.keycardSharedFlow.setupNewKeycard, state: Constants.keycardSharedState.keycardMetadataDisplay },
        { label: "Migrate keypair to app", flow: Constants.keycardSharedFlow.migrateFromKeycardToApp, state: Constants.keycardSharedState.migrateKeypairToApp },
        { label: "Migrating keypair to app", flow: Constants.keycardSharedFlow.migrateFromKeycardToApp, state: Constants.keycardSharedState.migratingKeypairToApp },
        { label: "Migrate keypair to keycard", flow: Constants.keycardSharedFlow.migrateFromAppToKeycard, state: Constants.keycardSharedState.migrateKeypairToKeycard },
        { label: "Migrating keypair to keycard", flow: Constants.keycardSharedFlow.migrateFromAppToKeycard, state: Constants.keycardSharedState.migratingKeypairToKeycard },
        { label: "Keypair migrate success", flow: Constants.keycardSharedFlow.migrateFromKeycardToApp, state: Constants.keycardSharedState.keyPairMigrateSuccess },
        { label: "Keypair migrate failure", flow: Constants.keycardSharedFlow.migrateFromKeycardToApp, state: Constants.keycardSharedState.keyPairMigrateFailure },
        { label: "Creating account (new seed)", flow: Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase, state: Constants.keycardSharedState.creatingAccountNewSeedPhrase },
        { label: "Creating account (new seed) success", flow: Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase, state: Constants.keycardSharedState.creatingAccountNewSeedPhraseSuccess },
        { label: "Creating account (new seed) failure", flow: Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase, state: Constants.keycardSharedState.creatingAccountNewSeedPhraseFailure },
        { label: "Creating account (old seed)", flow: Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase, state: Constants.keycardSharedState.creatingAccountOldSeedPhrase },
        { label: "Creating account (old seed) success", flow: Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase, state: Constants.keycardSharedState.creatingAccountOldSeedPhraseSuccess },
        { label: "Creating account (old seed) failure", flow: Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase, state: Constants.keycardSharedState.creatingAccountOldSeedPhraseFailure },
        { label: "Seed phrase already in use", flow: Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase, state: Constants.keycardSharedState.seedPhraseAlreadyInUse },
        { label: "Importing from Keycard", flow: Constants.keycardSharedFlow.importFromKeycard, state: Constants.keycardSharedState.importingFromKeycard },
        { label: "Import from Keycard success", flow: Constants.keycardSharedFlow.importFromKeycard, state: Constants.keycardSharedState.importingFromKeycardSuccess },
        { label: "Import from Keycard failure", flow: Constants.keycardSharedFlow.importFromKeycard, state: Constants.keycardSharedState.importingFromKeycardFailure },
        { label: "Factory reset success", flow: Constants.keycardSharedFlow.factoryReset, state: Constants.keycardSharedState.factoryResetSuccess },
        { label: "Unlocking Keycard", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.unlockingKeycard },
        { label: "Unlock Keycard success", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.unlockKeycardSuccess },
        { label: "Unlock Keycard failure", flow: Constants.keycardSharedFlow.unlockKeycard, state: Constants.keycardSharedState.unlockKeycardFailure },
        { label: "Renaming Keycard", flow: Constants.keycardSharedFlow.renameKeycard, state: Constants.keycardSharedState.renamingKeycard },
        { label: "Keycard rename success", flow: Constants.keycardSharedFlow.renameKeycard, state: Constants.keycardSharedState.keycardRenameSuccess },
        { label: "Keycard rename failure", flow: Constants.keycardSharedFlow.renameKeycard, state: Constants.keycardSharedState.keycardRenameFailure },
        { label: "Changing Keycard PIN", flow: Constants.keycardSharedFlow.changeKeycardPin, state: Constants.keycardSharedState.changingKeycardPin },
        { label: "Changing Keycard PUK", flow: Constants.keycardSharedFlow.changeKeycardPuk, state: Constants.keycardSharedState.changingKeycardPuk },
        { label: "Change Keycard PUK success", flow: Constants.keycardSharedFlow.changeKeycardPuk, state: Constants.keycardSharedState.changingKeycardPukSuccess },
        { label: "Change Keycard PUK failure", flow: Constants.keycardSharedFlow.changeKeycardPuk, state: Constants.keycardSharedState.changingKeycardPukFailure },
        { label: "Changing pairing code", flow: Constants.keycardSharedFlow.changePairingCode, state: Constants.keycardSharedState.changingKeycardPairingCode },
        { label: "Change pairing code success", flow: Constants.keycardSharedFlow.changePairingCode, state: Constants.keycardSharedState.changingKeycardPairingCodeSuccess },
        { label: "Change pairing code failure", flow: Constants.keycardSharedFlow.changePairingCode, state: Constants.keycardSharedState.changingKeycardPairingCodeFailure },
        { label: "Remove Keycard", flow: Constants.keycardSharedFlow.createCopyOfAKeycard, state: Constants.keycardSharedState.removeKeycard },
        { label: "Same Keycard", flow: Constants.keycardSharedFlow.createCopyOfAKeycard, state: Constants.keycardSharedState.sameKeycard },
        { label: "Copy to Keycard", flow: Constants.keycardSharedFlow.createCopyOfAKeycard, state: Constants.keycardSharedState.copyToKeycard },
        { label: "Copying Keycard", flow: Constants.keycardSharedFlow.createCopyOfAKeycard, state: Constants.keycardSharedState.copyingKeycard },
        { label: "Copying Keycard success", flow: Constants.keycardSharedFlow.createCopyOfAKeycard, state: Constants.keycardSharedState.copyingKeycardSuccess },
        { label: "Copying Keycard failure", flow: Constants.keycardSharedFlow.createCopyOfAKeycard, state: Constants.keycardSharedState.copyingKeycardFailure },
        { label: "Biometrics", flow: Constants.keycardSharedFlow.authentication, state: Constants.keycardSharedState.biometrics },
        { label: "Biometrics ready to sign", flow: Constants.keycardSharedFlow.sign, state: Constants.keycardSharedState.biometricsReadyToSign },
        { label: "Biometrics password failed", flow: Constants.keycardSharedFlow.authentication, state: Constants.keycardSharedState.biometricsPasswordFailed },
        { label: "Biometrics PIN failed", flow: Constants.keycardSharedFlow.sign, state: Constants.keycardSharedState.biometricsPinFailed },
        { label: "Biometrics PIN invalid", flow: Constants.keycardSharedFlow.sign, state: Constants.keycardSharedState.biometricsPinInvalid }
    ]

    function applyPreset(index) {
        if (index < 0 || index >= root.presets.length)
            return

        const p = root.presets[index]
        sharedKeycardModule.currentState.flowType = p.flow
        sharedKeycardModule.currentState.stateType = p.state
        sharedKeycardModule.currentState.displayBackButton =
                p.state !== Constants.keycardSharedState.keycardFlowStarted &&
                p.state !== Constants.keycardSharedState.pluginReader
    }

    function applyKeycardInitState(index) {
        if (index < 0 || index >= root.keycardInitStates.length)
            return

        const stateDef = root.keycardInitStates[index]
        sharedKeycardModule.currentState.flowType = stateDef.flow
        sharedKeycardModule.currentState.stateType = stateDef.state
        sharedKeycardModule.currentState.displayBackButton =
                stateDef.state !== Constants.keycardSharedState.keycardFlowStarted &&
                stateDef.state !== Constants.keycardSharedState.pluginReader
    }

    function goToNextKeycardInitState() {
        if (root.keycardInitStates.length === 0)
            return

        const current = Math.max(0, keycardInitSelector.currentIndex)
        const nextIndex = (current + 1) % root.keycardInitStates.length
        keycardInitSelector.currentIndex = nextIndex
        root.applyKeycardInitState(nextIndex)
    }

    function goToPreviousKeycardInitState() {
        if (root.keycardInitStates.length === 0)
            return

        const current = Math.max(0, keycardInitSelector.currentIndex)
        const previousIndex = (current - 1 + root.keycardInitStates.length) % root.keycardInitStates.length
        keycardInitSelector.currentIndex = previousIndex
        root.applyKeycardInitState(previousIndex)
    }

    Item {
        id: stage
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Label {
                text: qsTr("Open portrait and landscape windows to compare behavior while changing controls.")
            }

            RowLayout {
                Button {
                    text: portraitPopupWindow.visible ? qsTr("Focus portrait window") : qsTr("Open portrait window")
                    onClicked: {
                        portraitPopupWindow.visible = true
                        portraitPopupWindow.raise()
                        portraitPopupWindow.requestActivate()
                    }
                }

                Button {
                    text: qsTr("Close portrait window")
                    enabled: portraitPopupWindow.visible
                    onClicked: portraitPopupWindow.visible = false
                }
            }

            RowLayout {
                Button {
                    text: landscapePopupWindow.visible ? qsTr("Focus landscape window") : qsTr("Open landscape window")
                    onClicked: {
                        landscapePopupWindow.visible = true
                        landscapePopupWindow.raise()
                        landscapePopupWindow.requestActivate()
                    }
                }

                Button {
                    text: qsTr("Close landscape window")
                    enabled: landscapePopupWindow.visible
                    onClicked: landscapePopupWindow.visible = false
                }
            }

            Button {
                Layout.alignment: Qt.AlignLeft
                text: qsTr("Open both windows")
                onClicked: {
                    portraitPopupWindow.visible = true
                    landscapePopupWindow.visible = true
                }
            }
        }
    }

    Window {
        id: portraitPopupWindow
        width: 460
        height: 760
        visible: false
        title: qsTr("Keycard Popup - Portrait")

        onVisibleChanged: {
            if (visible) {
                portraitPopup.open()
            } else {
                portraitPopup.close()
            }
        }

        PopupBackground {
            anchors.fill: parent
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.portraitTopSafeArea
            color: "#66ff9800"
            z: 100
            visible: height > 0
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.portraitBottomSafeArea
            color: "#660096ff"
            z: 100
            visible: height > 0
        }

        KeycardPopup {
            id: portraitPopup
            myKeyUid: "profile-key-uid"
            sharedKeycardModule: sharedKeycardModule
            emojiPopup: emojiPopupMock
            closePolicy: Popup.NoAutoClose
            SafeArea.additionalMargins.top: root.portraitTopSafeArea
            SafeArea.additionalMargins.bottom: root.portraitBottomSafeArea

            // Keep the detached preview persistent while tweaking controls.
            onClosed: if (portraitPopupWindow.visible) Qt.callLater(open)
        }
    }

    Window {
        id: landscapePopupWindow
        width: 920
        height: 520
        visible: false
        title: qsTr("Keycard Popup - Landscape")

        onVisibleChanged: {
            if (visible) {
                landscapePopup.open()
            } else {
                landscapePopup.close()
            }
        }

        PopupBackground {
            anchors.fill: parent
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.landscapeTopSafeArea
            color: "#66ff9800"
            z: 100
            visible: height > 0
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.landscapeBottomSafeArea
            color: "#660096ff"
            z: 100
            visible: height > 0
        }

        KeycardPopup {
            id: landscapePopup
            myKeyUid: "profile-key-uid"
            sharedKeycardModule: sharedKeycardModule
            emojiPopup: emojiPopupMock
            closePolicy: Popup.NoAutoClose
            SafeArea.additionalMargins.top: root.landscapeTopSafeArea
            SafeArea.additionalMargins.bottom: root.landscapeBottomSafeArea

            // Keep the detached preview persistent while tweaking controls.
            onClosed: if (landscapePopupWindow.visible) Qt.callLater(open)
        }
    }

    LogsAndControlsPanel {
        id: controls
        SplitView.preferredWidth: 360
        SplitView.fillHeight: true

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true

            Label { text: "View preset:" }
            ComboBox {
                id: presetSelector
                Layout.fillWidth: true
                model: root.presets
                textRole: "label"
                onActivated: root.applyPreset(currentIndex)
                Component.onCompleted: root.applyPreset(currentIndex)
            }

            Label { text: "KeycardInit state (all):" }
            ComboBox {
                id: keycardInitSelector
                Layout.fillWidth: true
                model: root.keycardInitStates
                textRole: "label"
                onCurrentIndexChanged: root.applyKeycardInitState(currentIndex)
                Component.onCompleted: {
                    if (currentIndex < 0)
                        currentIndex = 0
                    else
                        root.applyKeycardInitState(currentIndex)
                }
            }
            Button {
                Layout.alignment: Qt.AlignLeft
                text: "Back KeycardInit state"
                onClicked: root.goToPreviousKeycardInitState()
            }
            Button {
                Layout.alignment: Qt.AlignLeft
                text: "Next KeycardInit state"
                onClicked: root.goToNextKeycardInitState()
            }

            CheckBox {
                id: forceFlowCheck
                text: "forceFlow"
                checked: sharedKeycardModule.forceFlow
                onToggled: sharedKeycardModule.forceFlow = checked
            }

            CheckBox {
                id: disablePopupCheck
                text: "disablePopup"
                checked: sharedKeycardModule.disablePopup
                onToggled: sharedKeycardModule.disablePopup = checked
            }

            CheckBox {
                id: keyKnownCheck
                text: "keyPairStoredOnKeycardIsKnown"
                checked: sharedKeycardModule.keyPairStoredOnKeycardIsKnown
                onToggled: sharedKeycardModule.keyPairStoredOnKeycardIsKnown = checked
            }

            CheckBox {
                id: biometricCheck
                text: "userProfile.usingBiometricLogin"
                checked: userProfile.usingBiometricLogin
                onToggled: userProfile.usingBiometricLogin = checked
            }

            CheckBox {
                id: keycardUserCheck
                text: "userProfile.isKeycardUser"
                checked: userProfile.isKeycardUser
                onToggled: userProfile.isKeycardUser = checked
            }

            Label { text: "Portrait safe area" }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Top:" }
                SpinBox {
                    Layout.fillWidth: true
                    from: 0
                    to: 120
                    value: root.portraitTopSafeArea
                    onValueModified: root.portraitTopSafeArea = value
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Bottom:" }
                SpinBox {
                    Layout.fillWidth: true
                    from: 0
                    to: 120
                    value: root.portraitBottomSafeArea
                    onValueModified: root.portraitBottomSafeArea = value
                }
            }

            Label { text: "Landscape safe area" }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Top:" }
                SpinBox {
                    Layout.fillWidth: true
                    from: 0
                    to: 120
                    value: root.landscapeTopSafeArea
                    onValueModified: root.landscapeTopSafeArea = value
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Bottom:" }
                SpinBox {
                    Layout.fillWidth: true
                    from: 0
                    to: 120
                    value: root.landscapeBottomSafeArea
                    onValueModified: root.landscapeBottomSafeArea = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Flow type:" }
                Label {
                    Layout.fillWidth: true
                    text: String(sharedKeycardModule.currentState.flowType)
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "State type:" }
                Label {
                    Layout.fillWidth: true
                    text: String(sharedKeycardModule.currentState.stateType)
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    Settings {
        property alias generalViewPresetIndex: presetSelector.currentIndex
        property alias keycardInitStateIndex: keycardInitSelector.currentIndex
    }
}

// category: Popups
// status: good
