import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import Storybook

import utils
import shared.popups.keycard_new

SplitView {
    id: root
    orientation: Qt.Horizontal

    Logs { id: logs }

    property QtObject userProfile: QtObject {
        property string keyUid: "profile-key-uid"
        property string pubKey: "0x1234567890abcdef"
        property bool usingBiometricLogin: false
        property bool migratedToColdWallet: false
    }

    ListModel {
        id: accountsModel
        Component.onCompleted: {
            append([
                { account: { name: "Main account", emoji: "😎", colorId: "purple",
                             address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", path: "m/44'/60'/0'/0/0", balance: "1.2345" } },
                { account: { name: "Savings", emoji: "🚀", colorId: "army",
                             address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8888", path: "m/44'/60'/0'/0/1", balance: "12.001" } }
            ])
        }
    }

    QtObject {
        id: keyPairItemMock
        property string keyUid: "profile-key-uid"
        property string name: "Profile"
        property string image: ""
        property string icon: ""
        property int pairType: Constants.keycard.keyPairType.profile
        property bool migratedToColdWallet: false
        property string derivedFrom: ""
        property bool locked: false
        property var accounts: accountsModel
    }

    ListModel {
        id: keyPairsModel
        Component.onCompleted: {
            append([
                { keyPair: { keyUid: "profile-key-uid", pubKey: root.userProfile.pubKey, name: "Profile", image: "", icon: "",
                             pairType: Constants.keycard.keyPairType.profile, migratedToColdWallet: false, derivedFrom: "", locked: false } },
                { keyPair: { keyUid: "seed-key-uid", pubKey: "", name: "Seed phrase keypair", image: "", icon: "key_pair_seed_phrase",
                             pairType: Constants.keycard.keyPairType.seedImport, migratedToColdWallet: false, derivedFrom: "", locked: false } }
            ])
        }
    }

    QtObject {
        id: emojiPopupMock
        property var directParent: null
        property real relativeY: 0
        property int emojiSize: 0
        signal emojiSelected(string emojiText, bool atCursor)
        function open() {}
        function close() {}
    }

    // Mock implementing the KeycardManagementPopup store contract (see BaseKeycardManagementStore.qml).
    QtObject {
        id: mockStore

        // --- read by the popup ---
        property string keycardState: ""
        property bool keycardStatusAvailable: true
        property int remainingPinAttempts: 3
        property int remainingPukAttempts: 5
        property int availableSlots: 5
        property string keycardUid: "keycard-uid-1"
        property string keyUid: "profile-key-uid"
        property string cardMetadataName: "My Keycard"
        property string cardMetadataWalletAccountsJson: "[]"
        property var keypairsModel: keyPairsModel
        property var keyPairItem: keyPairItemMock
        property string userProfileKeyUid: root.userProfile.keyUid
        property string userProfilePubKey: root.userProfile.pubKey
        property bool isProfileMigratedToColdWallet: root.userProfile.migratedToColdWallet

        readonly property string _mnemonic: "abandon ability able about above absent absorb abstract absurd abuse access accident"

        // --- lifecycle ---
        function prepare() { logs.logEvent("store.prepare()") }
        function teardown() { logs.logEvent("store.teardown()") }

        // --- flow operations (logging no-ops) ---
        function startGetMetadata(pin) { logs.logEvent("startGetMetadata(%1)".arg(pin)) }
        function startFactoryReset(keycardUid) { logs.logEvent("startFactoryReset(%1)".arg(keycardUid)) }
        function startUnblockKeycardUsingPuk(newPin, puk) { logs.logEvent("startUnblockKeycardUsingPuk()") }
        function startUnblockKeycardUsingRecoveryPhrase(newPin, seedPhrase, metadataName, metadataAccountsJson) { logs.logEvent("startUnblockKeycardUsingRecoveryPhrase()") }
        function startImportingKeyPair(pin, seedPhrase, metadataName, metadataAccounts) { logs.logEvent("startImportingKeyPair()") }
        function startMigratingNonProfileKeypairToKeycard(password, pin, keyUid, keycardUid) { logs.logEvent("startMigratingNonProfileKeypairToKeycard()") }
        function startMigratingProfileKeypairToKeycard(password, pin, keycardUid) { logs.logEvent("startMigratingProfileKeypairToKeycard()") }
        function startAddingKeyPairToStatusFromKeycard(pin, keyUid, keycardUid) { logs.logEvent("startAddingKeyPairToStatusFromKeycard()") }
        function startStopUsingKeycardForKeyPair(keyUid, pin) { logs.logEvent("startStopUsingKeycardForKeyPair()") }
        function startStopUsingKeycardForProfileKeyPair(seedPhrase, newPassword) { logs.logEvent("startStopUsingKeycardForProfileKeyPair()") }
        function startChangeKeycardPIN(currentPin, newPin) { logs.logEvent("startChangeKeycardPIN()") }
        function startChangeKeycardPUK(pin, newPuk) { logs.logEvent("startChangeKeycardPUK()") }
        function startRenameKeycard(pin, newName) { logs.logEvent("startRenameKeycard(%1)".arg(newName)) }
        function startAsyncLogin(keyUid, pin, withBiometrics) { logs.logEvent("startAsyncLogin()") }

        // --- queries ---
        function getKeyUidForSeedPhrase(seedPhrase) { return "seed-key-uid" }
        function generateMnemonic() { return _mnemonic }
        function getMnemonic() { return _mnemonic }
        function isMnemonicBackedUp() { return true }
        function isKnownKeyUid(keyUid) { return true }
        function isKeypairMigratedToColdWallet(keyUid) { return false }
        function getKeyPairNameForKeyUid(keyUid) { return "Profile" }
        function getKeyPairAccountPathsJsonForKeyUid(keyUid) { return "[\"m/44'/60'/0'/0/0\"]" }
        function resolveKeyPairItemForKeyUid(keyUid) { return keyPairItemMock }
        function remainingKeypairCapacity() { return 5 }
        function remainingAccountCapacity() { return 5 }
        function prepareKeyPairModel() { logs.logEvent("prepareKeyPairModel()") }
        function signOutAndQuit() { logs.logEvent("signOutAndQuit()") }

        // --- signals consumed by the popup's Connections ---
        signal keycardInteractionSuccessfullyCompleted()
        signal keycardGetMetadataSuccess()
        signal keycardGetMetadataError(string error)
        signal keycardFactoryResetSuccess()
        signal keycardFactoryResetError(string error)
        signal keycardImportKeyPairSuccess()
        signal keycardImportKeyPairError(string error)
        signal keycardAsyncLoginSuccess(string dataJson)
        signal keycardAsyncLoginError(string error)
        signal keycardMoveKeyPairSuccess()
        signal keycardMoveKeyPairError(string error)
        signal keycardMoveProfileKeyPairSuccess()
        signal keycardMoveProfileKeyPairError(string error)
        signal keycardAddKeyPairSuccess()
        signal keycardAddKeyPairError(string error)
        signal stopUsingKeycardForKeyPairSuccess()
        signal stopUsingKeycardForKeyPairError(string error)
        signal stopUsingKeycardForProfileKeyPairSuccess()
        signal stopUsingKeycardForProfileKeyPairError(string error)
        signal keycardChangePinSuccess()
        signal keycardChangePinError(string error)
        signal keycardChangePukSuccess()
        signal keycardChangePukError(string error)
        signal keycardRenameSuccess()
        signal keycardRenameError(string error)
        signal keycardUnblockSuccess()
        signal keycardUnblockError(string error)
    }

    readonly property var flows: [
        Constants.keycard.flow.readKeycard,
        Constants.keycard.flow.factoryReset,
        Constants.keycard.flow.importSeedPhrase,
        Constants.keycard.flow.importNewKeyPair,
        Constants.keycard.flow.moveKeyPair,
        Constants.keycard.flow.moveProfileKeyPair,
        Constants.keycard.flow.addKeyPairToStatus,
        Constants.keycard.flow.stopUsingKeycard,
        Constants.keycard.flow.stopUsingKeycardForProfile,
        Constants.keycard.flow.startUsingProfileWithoutKeycard,
        Constants.keycard.flow.changePin,
        Constants.keycard.flow.setOrChangePuk,
        Constants.keycard.flow.rename,
        Constants.keycard.flow.unblockWithPuk,
        Constants.keycard.flow.unblockWithRecoveryPhrase
    ]

    property string currentFlow: Constants.keycard.flow.readKeycard

    Item {
        id: stage
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground { anchors.fill: parent }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Label { text: qsTr("Pick a flow on the right, then open the popup.") }

            Button {
                Layout.alignment: Qt.AlignHCenter
                text: popupWindow.visible ? qsTr("Focus popup window") : qsTr("Open popup window")
                onClicked: {
                    popupWindow.visible = true
                    popupWindow.raise()
                    popupWindow.requestActivate()
                }
            }
            Button {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Close popup window")
                enabled: popupWindow.visible
                onClicked: popupWindow.visible = false
            }
        }
    }

    Window {
        id: popupWindow
        width: 600
        height: 760
        visible: false
        title: qsTr("Keycard Management Popup")

        onVisibleChanged: {
            if (visible)
                popup.open()
            else
                popup.close()
        }

        PopupBackground { anchors.fill: parent }

        KeycardManagementPopup {
            id: popup

            flow: root.currentFlow
            keycardUid: mockStore.keycardUid
            keyUid: mockStore.keyUid
            cardMetadataName: mockStore.cardMetadataName
            cardMetadataWalletAccountsJson: mockStore.cardMetadataWalletAccountsJson

            store: mockStore
            emojiPopup: emojiPopupMock
            passwordStrengthScoreFunction: (password) => Math.min(4, (password ? password.length : 0))

            closePolicy: Popup.NoAutoClose

            onMetadataResult: function(keycardState, keycardUid, keyUid, keycardStatusAvailable, remainingPinAttempts, remainingPukAttempts,
                                       availableSlots, cardMetadataName, cardMetadataWalletAccountsJson) {
                logs.logEvent("onMetadataResult(state=%1, keycardUid=%2, keyUid=%3)".arg(keycardState).arg(keycardUid).arg(keyUid))
            }
            onKeycardFlowCompleted: function(flow, keyUid, keycardUid, success) {
                logs.logEvent("onKeycardFlowCompleted(flow=%1, success=%2)".arg(flow).arg(success))
            }
            onKeycardFlowCompletedWithData: function(flow, dataJson) {
                logs.logEvent("onKeycardFlowCompletedWithData(flow=%1)".arg(flow))
            }

            // keep the detached preview persistent while tweaking controls
            onClosed: if (popupWindow.visible) Qt.callLater(open)
        }
    }

    LogsAndControlsPanel {
        id: controls
        SplitView.preferredWidth: 360
        SplitView.fillHeight: true

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true

            Label { text: "Flow:" }
            ComboBox {
                id: flowSelector
                Layout.fillWidth: true
                model: root.flows
                onActivated: root.currentFlow = root.flows[currentIndex]
                Component.onCompleted: root.currentFlow = root.flows[currentIndex]
            }

            Label { text: "keycardState:" }
            ComboBox {
                id: keycardStateSelector
                Layout.fillWidth: true
                editable: true
                model: ["", "ready", "not-keycard", "empty-keycard", "blocked-pin", "blocked-puk"]
                onActivated: mockStore.keycardState = editText
                onAccepted: mockStore.keycardState = editText
            }

            CheckBox {
                text: "keycardStatusAvailable"
                checked: mockStore.keycardStatusAvailable
                onToggled: mockStore.keycardStatusAvailable = checked
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "remainingPinAttempts:" }
                SpinBox {
                    Layout.fillWidth: true
                    from: -1; to: 5
                    value: mockStore.remainingPinAttempts
                    onValueModified: mockStore.remainingPinAttempts = value
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "remainingPukAttempts:" }
                SpinBox {
                    Layout.fillWidth: true
                    from: -1; to: 5
                    value: mockStore.remainingPukAttempts
                    onValueModified: mockStore.remainingPukAttempts = value
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "availableSlots:" }
                SpinBox {
                    Layout.fillWidth: true
                    from: -1; to: 10
                    value: mockStore.availableSlots
                    onValueModified: mockStore.availableSlots = value
                }
            }

            Label { text: "Simulate flow result:" }
            RowLayout {
                Layout.fillWidth: true
                Button {
                    Layout.fillWidth: true
                    text: "Success"
                    onClicked: mockStore.keycardInteractionSuccessfullyCompleted()
                }
                Button {
                    Layout.fillWidth: true
                    text: "Metadata OK"
                    onClicked: mockStore.keycardGetMetadataSuccess()
                }
            }
        }
    }

    Settings {
        property alias flowIndex: flowSelector.currentIndex
    }
}

// category: Popups
// status: good
