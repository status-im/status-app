import QtCore
import QtQml
import QtQuick
import QtTest

import QtQml.Models
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as SQUtils

import Models
import Storybook as StoryBook

import AppLayouts.Wallet.controls
import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types

import SortFilterProxyModel

import AppLayouts.Wallet.controls
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.popups.dapps
import AppLayouts.Profile.stores
import AppLayouts.Wallet.stores as WalletStore
import AppLayouts.stores as AppLayoutStores

import mainui
import shared.stores as SharedStores
import utils

Item {
    id: root

    // Needed for DAppsWorkflow->PairWCModal to open its instructions popup
    Popups {
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
    }

    SplitView {
        anchors.fill: parent

        ColumnLayout {
            SplitView.fillWidth: true

            Rectangle {
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: dappsComboBox.implicitHeight + 20
                Layout.preferredHeight: dappsComboBox.implicitHeight + 20

                border.color: "blue"
                border.width: 1

                DappsComboBox {
                    id: dappsComboBox
                    anchors.centerIn: parent
                    spacing: 8
                    enabled: dappsService.isServiceOnline

                    onConnectDapp: dappsWorkflow.chooseConnector()
                    onDisconnectDapp: dappsWorkflow.disconnectDapp(dappUrl)
                    model: dappsService.dappsModel
                }

                DAppsWorkflow {
                    id: dappsWorkflow

                    visualParent: root
                    enabled: dappsService.isServiceOnline

                    readonly property var wcService: dappsService
                    loginType: Constants.LoginType.Biometrics
                    selectedAccountAddress: ""

                    dAppsModel: wcService.dappsModel
                    accountsModel: dappModule.accountsModel
                    networksModel: dappModule.networksModel
                    sessionRequestsModel: wcService.sessionRequestsModel
                    walletConnectEnabled: dappsService.walletConnectFeatureEnabled
                    connectorEnabled: dappsService.connectorFeatureEnabled

                    formatBigNumber: (number, symbol, noSymbolOption) => {
                        print ("formatBigNumber", number, symbol, noSymbolOption)
                        return parseFloat(number).toLocaleString(Qt.locale(), 'f', 2)
                                    + (noSymbolOption ? "" : " " + (symbol || Qt.locale().currencySymbol(Locale.CurrencyIsoCode)))
                    }
                    onDisconnectRequested: (connectionId) => wcService.disconnectDapp(connectionId)
                    onPairingRequested: (uri) => wcService.pair(uri)
                    onPairingValidationRequested: (uri) => wcService.validatePairingUri(uri)
                    onConnectionAccepted: (pairingId, chainIds, selectedAccount) => wcService.approvePairSession(pairingId, chainIds, selectedAccount)
                    onConnectionDeclined: (pairingId) => wcService.rejectPairSession(pairingId)
                    onSignRequestAccepted: (connectionId, requestId) => wcService.sign(connectionId, requestId)
                    onSignRequestRejected: (connectionId, requestId) => wcService.rejectSign(connectionId, requestId, false /*hasError*/)
                    onSignRequestIsLive: (connectionId, requestId) => wcService.signRequestIsLive(connectionId, requestId)
                    onPairWithConnectorRequested: (connectorId) => {
                        if (connectorId == Constants.DAppConnectors.WalletConnect) {
                            dappsWorkflow.openPairing()
                        } else if (connectorId == Constants.DAppConnectors.StatusConnect) {
                            Qt.openUrlExternally("https://chromewebstore.google.com/detail/a-wallet-connector-by-sta/kahehnbpamjplefhpkhafinaodkkenpg")
                        }
                    }

                    Connections {
                        target: dappsWorkflow.wcService
                        function onPairingValidated(validationState) {
                            dappsWorkflow.pairingValidated(validationState)
                        }
                        function onApproveSessionResult(pairingId, err, newConnectionId) {
                            if (err) {
                                dappsWorkflow.connectionFailed(pairingId)
                                return
                            }

                            dappsWorkflow.connectionSuccessful(pairingId, newConnectionId)
                        }
                        function onConnectDApp(dappChains, dappUrl, dappName, dappIcon, pairingId) {
                            dappsWorkflow.connectDApp(dappChains, dappUrl, dappName, dappIcon, pairingId)
                        }
                    }
                }
            }
            ColumnLayout {}
        }

        ColumnLayout {
            id: optionsSpace

            RowLayout {
                StatusBaseText { text: "projectId" }
                StatusBaseText {
                    id: projectIdText
                    readonly property string projectId: StoryBook.SystemUtils.getEnvVar("WALLET_CONNECT_PROJECT_ID")
                    text: SQUtils.Utils.elideText(projectId, 3)
                    font.bold: true
                }
            }
            RowLayout {
                StatusBaseText { text: "SDK status:" }
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: Layout.preferredWidth / 2
                    color: dappModule.wcSdk.sdkReady ? "green" : "red"
                }
            }

            CheckBox {
                text: "Testnet Mode"
                checked: settings.testNetworks
                onCheckedChanged: {
                    settings.testNetworks = checked
                }
            }

            StatusBaseText { text: "Custom Accounts" }
            StatusTextArea {
                text: settings.customAccounts
                onTextChanged: {
                    settings.customAccounts = text
                    customAccountsModel.clear()
                    let customData = JSON.parse(text)
                    customData.forEach(function(account) {
                        customAccountsModel.append(account)
                    })
                }
                Layout.fillWidth: true
                Layout.maximumHeight: 300
                clip: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "grey"
            }

            StatusBaseText { text: "Requests Queue" }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(50, contentHeight)
                model: dappsService.sessionRequestsModel
                delegate: RowLayout {
                    StatusBaseText {
                        text: SQUtils.Utils.elideAndFormatWalletAddress(model.requestItem.topic, 6, 4)
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "grey"
            }

            StatusBaseText { text: "Persisted Sessions" }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(100, contentHeight)
                model: sessionsModel
                delegate: RowLayout {
                    StatusBaseText {
                        text: SQUtils.Utils.elideAndFormatWalletAddress(model.topic, 6, 4)
                        Layout.fillWidth: true
                    }
                }
            }

            StatusButton {
                text: qsTr("Clear Persistance")
                visible: sessionsModel.count > 0
                onClicked: {
                    settings.persistedSessions = "[]"
                    d.updateSessionsModelAndAddNewIfNotNull(null)
                }
            }

            StatusBaseText { text: "Networks Down" }

            NetworkFilter {
                id: networkFilter
                flatNetworks: dappModule.networksModel
            }

            // spacer
            ColumnLayout {}

            RowLayout {
                CheckBox {

                    text: "Enable SDK"
                    checked: settings.enableSDK
                    onCheckedChanged: {
                        settings.enableSDK = checked
                    }
                }

                CheckBox {
                    text: "WC feature flag"
                    checked: true
                    onCheckedChanged: {
                        dappsService.walletConnectFeatureEnabled = checked
                    }
                }

                CheckBox {
                    text: "Connector feature flag"
                    checked: true
                    onCheckedChanged: {
                        dappsService.connectorFeatureEnabled = checked
                    }
                }
            }

            RowLayout {
                StatusBaseText { text: "URI" }
                StatusInput {
                    id: pairUriInput

                    //placeholderText: "Enter WC Pair URI"
                    text: settings.pairUri
                    onTextChanged: {
                        settings.pairUri = text
                    }

                    Layout.fillWidth: true
                }
            }

            ComboBox {
                model: [{testCase: d.noTestCase, name: "No Test Case"},
                        {testCase: d.openDappsTestCase, name: "Open dApps"},
                        {testCase: d.openPairTestCase, name: "Open Pair"}
                ]
                textRole: "name"
                valueRole: "testCase"
                currentIndex: settings.testCase
                onCurrentValueChanged: {
                    settings.testCase = currentValue
                    if (currentValue !== d.noTestCase) {
                        d.startTestCase()
                    }
                }

                Connections {
                    target: dappsWorkflow

                    function onPairWCReady() {
                        if (d.activeTestCase < d.openPairTestCase)
                            return

                        if (pairUriInput.text.length > 0) {
                            let items = StoryBook.InspectionUtils.findVisualsByTypeName(dappsWorkflow, "StatusBaseInput")
                            if (items.length === 1) {
                                items[0].text = pairUriInput.text

                                clickDoneIfSDKReady()
                            }
                        }
                    }

                    function clickDoneIfSDKReady() {
                        if (d.activeTestCase < d.openPairTestCase) {
                            return
                        }

                        let modals = StoryBook.InspectionUtils.findVisualsByTypeName(dappsWorkflow, "PairWCModal")
                        if (modals.length === 1) {
                            let buttons = StoryBook.InspectionUtils.findVisualsByTypeName(modals[0].footer, "StatusButton")
                            if (buttons.length === 1 && buttons[0].enabled &&  dappModule.wcSdk.sdkReady) {
                                d.activeTestCase = d.noTestCase
                                buttons[0].clicked()
                                return
                            }
                        }

                        Backpressure.debounce(dappsWorkflow, 250, clickDoneIfSDKReady)()
                    }
                }
            }
        }
    }

    StatusDialog {
        id: authMockDialog
        title: "Authenticate user"
        visible: false

        property string topic: ""
        property string id: ""

        ColumnLayout {
            RowLayout {
                StatusBaseText { text: "Topic" }
                StatusBaseText { text: authMockDialog.topic }
                StatusBaseText { text: "ID" }
                StatusBaseText { text: authMockDialog.id }
            }
        }
        footer: StatusDialogFooter {
            rightButtons: ObjectModel {
                StatusButton {
                    text: qsTr("Reject")
                    onClicked: {
                        dappModule.store.userAuthenticationFailed(authMockDialog.topic, authMockDialog.id)
                        authMockDialog.close()
                    }
                }
                StatusButton {
                    text: qsTr("Authenticate")
                    onClicked: {
                        dappModule.store.userAuthenticated(authMockDialog.topic, authMockDialog.id, "0x1234567890", "123")
                        authMockDialog.close()
                    }
                }
            }
        }
    }

    QtObject {
        id: mockConnectorController
        function pairWalletConnect(uri) { return true }
        function disconnectWCSession(topic) { return true }
        function getWCActiveSessions(validAt) {
            try {
                const sessions = JSON.parse(settings.persistedSessions || "[]")
                return JSON.stringify(sessions.map(s => ({ sessionJson: typeof s === "string" ? s : JSON.stringify(s) })))
            } catch (e) {
                return "[]"
            }
        }
    }

    DAppsModule {
        id: dappModule
        dappsMetrics: DAppsMetrics {
            metricsStore: SharedStores.MetricsStore {
                function addCentralizedMetricIfEnabled(eventName, eventValue = null) {
                    print ("Metrics Event", JSON.stringify(arguments))
                }
            }
        }
        wcSdk: ConnectorWCSDK {
            enabled: settings.enableSDK && dappsService.walletConnectFeatureEnabled
            connectorController: mockConnectorController
            networksModel: dappModule.networksModel
            accountsModel: dappModule.accountsModel
        }

        bcSdk: DappsConnectorSDK {
            enabled: dappsService.connectorFeatureEnabled

            projectId: projectIdText.projectId
            networksModel: dappModule.networksModel
            accountsModel: dappModule.accountsModel
            store: SharedStores.BrowserConnectStore {
                signal connectRequested(string requestId, string dappJson)
                signal sendTransaction(string requestId, string requestJson)
                signal sign(string requestId, string dappJson)

                signal connected(string dappJson)
                signal disconnected(string dappJson)

                // Responses to user actions
                signal approveConnectResponse(string id, bool error)
                signal rejectConnectResponse(string id, bool error)

                signal approveTransactionResponse(string topic, string requestId, bool error)
                signal rejectTransactionResponse(string topic, string requestId, bool error)
                signal approveSignResponse(string topic, string requestId, bool error)
                signal rejectSignResponse(string topic, string requestId, bool error)
            }
        }
        store: SharedStores.DAppsStore {
            controller: QtObject {}
            signal userAuthenticated(string topic, string id, string password, string pin)
            signal userAuthenticationFailed(string topic, string id)
            signal signingResult(string topic, string id, string data)
            // Fees and gas
            signal estimatedTimeResponse(string topic, int timeCategory, bool success)
            signal suggestedFeesResponse(string topic, var suggestedFeesJsonObj, bool success)
            signal estimatedGasResponse(string topic, string gasEstimate, bool success)

            function authenticateUser(topic, id, address) {
                authMockDialog.topic = topic
                authMockDialog.id = id
                authMockDialog.open()
                return true
            }

            // hardcoded for https://react-app.walletconnect.com/
            function signMessageUnsafe(topic, id, address, password, message) {
                console.info(`calling mocked DAppsStore.signMessageUnsafe(${topic}, ${id}, ${address}, ${password}, ${message})`)
                return "0xc8f39cb4cffa5c4659e0ccc7c417cc61d0cfc9e59de310368ac734065164f5515bfbaf4550d409896f7e2210b82a1cf65edcd77f696b4d3d24477fb81a90af8a1c"
            }

            // hardcoded for https://react-app.walletconnect.com/
            function signMessage(topic, id, address, password, message) {
                console.info(`calling mocked DAppsStore.signMessage(${topic}, ${id}, ${address}, ${password}, ${message})`)
                signingResult(topic, id, "0xca49ddfba1279d246f1c22b2002fbd1a51faf27956264b476f26505ad729cc3a17958d30e11aff33b2420e20a4647076d3a98fa6c12ed142aa75dee7063a5dc601")
            }

            // hardcoded for https://react-app.walletconnect.com/
            function safeSignTypedData(topic, id, address, password, typedDataJson, chainId, legacy) {
                console.info(`calling mocked DAppsStore.safeSignTypedData(${topic}, ${id}, ${address}, ${password}, ${typedDataJson}, ${chainId}, ${legacy})`)
                signingResult(topic, id, "0xf8ceb3468319cc215523b67c24c4504b3addd9bf8de31c278038d7478c9b6de554f7d8a516cd5d6a066b7d48b81f03d9d6bb7d5d754513c08325674ebcc7efbc1b")
            }

            // hardcoded for https://react-app.walletconnect.com/
            function signTransaction(topic, id, address, chainId, password, tx) {
                console.info(`calling mocked DAppsStore.signTransaction(${topic}, ${id}, ${address}, ${chainId}, ${password}, ${tx})`)
                signingResult(topic, id, "0xf8672a8402fb7acf82520894e2d622c817878da5143bbe06866ca8e35273ba8a80808401546d71a04fc89c2f007c3b27d0fcff07d3e69c29f940967fab4caf525f9af72dadb48befa00c5312a3cb6f50328889ad361a0c88bb9d1b1a4fc510f6783b287930b4e187b5")
            }

            function sendTransaction(topic, id, address, chainId, password, tx) {
                console.info(`calling mocked DAppsStore.sendTransaction(${topic}, ${id}, ${address}, ${chainId}, ${password}, ${tx})`)
                signingResult(topic, id, "0xf8672a8402fb7acf82520894e2d622c817878da5143bbe068")
            }

            function requestEstimatedTime(topic, chainId, maxFeePerGasHex) {
                estimatedTimeResponse(topic, Constants.TransactionEstimatedTime.LessThanThreeMins, true)
            }

            function requestSuggestedFees(topic, chainId) {
                const suggestedFees = getSuggestedFees()
                suggestedFeesResponse(topic, suggestedFees, true)
            }

            function requestGasEstimate(topic, chainId, txObj) {
                estimatedGasResponse(topic, "0x5208", true)
            }

            function getSuggestedFees() {
                return {
                    gasPrice: 2.0,
                    baseFee: 5.0,
                    maxPriorityFeePerGas: 2.0,
                    maxFeePerGasLow: 1.0,
                    maxFeePerGasMedium: 1.1,
                    maxFeePerGasHigh: 1.2,
                    l1GasFee: 4.0,
                    eip1559Enabled: true
                }
            }

            function hexToDec(hex) {
                if (hex.length > "0xfffffffffffff".length) {
                    console.warn(`Beware of possible loss of precision converting ${hex}`)
                }
                return parseInt(hex, 16).toString()
            }
        }

        currenciesStore: SharedStores.CurrenciesStore {}
        groupedAccountAssetsModel: GroupedAccountsAssetsModel {}
        accountsModel: customAccountsModel.count > 0 ? customAccountsModel : defaultAccountsModel

        networksModel: SortFilterProxyModel {
            sourceModel: NetworksModel.flatNetworks
            proxyRoles: [
                FastExpressionRole {
                    name: "isOnline"
                    expression: !networkFilter.selection.map(Number).includes(model.chainId)
                    expectedRoles: "chainId"
                }
            ]
            filters: ValueFilter { roleName: "isTest"; value: settings.testNetworks; }
        }
    }

    DAppsService {
        id: dappsService

        dappsModule: dappModule
        accountsModel: customAccountsModel.count > 0 ? customAccountsModel : defaultAccountsModel
        selectedAddress: ""
        onDisplayToastMessage: (message, isErr) => {
            if(isErr) {
                console.log(`Storybook.displayToastMessage(${message}, "", "warning", false, Constants.ephemeralNotificationType.danger, "")`)
                return
            }
            console.log(`Storybook.displayToastMessage(${message}, "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")`)
        }
    }


    SQUtils.QObject {
        id: d

        property int activeTestCase: noTestCase

        function startTestCase() {
            d.activeTestCase = settings.testCase
            if(root.visible) {
                dappsComboBox.popup.open()
            }
        }

        readonly property int noTestCase: 0
        readonly property int openDappsTestCase: 1
        readonly property int openPairTestCase: 2

        ListModel {
            id: sessionsModel
        }

        function updateSessionsModelAndAddNewIfNotNull(newSession) {
            var sessions = JSON.parse(settings.persistedSessions)
            if (!!newSession) {
                sessions.push(newSession)
                settings.persistedSessions = JSON.stringify(sessions)
            }

            sessionsModel.clear()
            d.persistedDapps = []
            sessions.forEach(function(session) {
                sessionsModel.append(session)

                let firstIconUrl = !!session.peer.metadata.icons && session.peer.metadata.icons.length > 0 ?
                                    session.peer.metadata.icons[0] : ""
                let persistedDapp = {
                    "name": session.peer.metadata.name,
                    "url": session.peer.metadata.url,
                    "iconUrl": firstIconUrl,
                    "topic": session.topic
                }
                var found = false
                for (var i = 0; i < d.persistedDapps.length; i++) {
                    if (d.persistedDapps[i].url == persistedDapp.url) {
                        found = true
                        break
                    }
                }
                if (!found) {
                    d.persistedDapps.push(persistedDapp)
                }
            })
        }

        property var persistedDapps: []
        ListModel {
            id: customAccountsModel
        }
        WalletAccountsModel{
            id: defaultAccountsModel
        }
    }

    onVisibleChanged: {
        if (visible && d.activeTestCase !== d.noTestCase) {
            d.startTestCase()
        }
    }

    Settings {
        id: settings

        property int testCase: d.noTestCase
        property string pairUri: ""
        property bool testNetworks: false
        property bool enableSDK: true
        property bool pending : false
        property string customAccounts: "[]"
        property string persistedSessions: "[]"
    }

    Component.onCompleted: {
        d.updateSessionsModelAndAddNewIfNotNull(null)
    }
}

// category: Wallet
// https://www.figma.com/design/HrmZp1y4S77QJezRFRl6ku/dApp-Interactions---Milestone-1?node-id=3649-30334&t=t5qqtR3RITR4yCOx-0
