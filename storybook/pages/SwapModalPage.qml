import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortFilterProxyModel
import QtTest

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Utils

import utils

import mainui
import AppLayouts.Wallet.popups.swap
import AppLayouts.Wallet.stores
import AppLayouts.stores as AppLayoutStores
import shared.stores as SharedStores

import Storybook
import Models
import Mocks

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Horizontal

    QtObject {
        id: d
        readonly property var tokenBySymbolModel: TokenGroupsModel {}

        function launchPopup() {
            swapModal.createObject(root)
        }

        readonly property SwapTransactionRoutes dummySwapTransactionRoutes: SwapTransactionRoutes {}

        property string uuid

        function resetValues() {
            accountComboBox.currentIndex = 0
            swapInput.text = ""
            fetchSuggestedRoutesSpy.clear()
            authenticateAndTransferSpy.clear()
        }
    }

    Keychain {
        id: popupsKeychain
    }

    Popups {
        keychain: popupsKeychain
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
    }

    PopupBackground {
        id: popupBg

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            id: reopenButton
            anchors.centerIn: parent
            text: "Reopen"
            enabled: !swapModal.visible

            onClicked: d.launchPopup()
        }

        Component.onCompleted: d.launchPopup()

        SwapStore {
            id: dSwapStore
            signal suggestedRoutesReady(var txRoutes, string errCode, string errDescription)
            signal transactionSent(var chainId, var txHash, var uuid, var error)
            signal transactionSendingComplete(var txHash, var status)

            readonly property var accounts: WalletAccountsModel {}

            function fetchSuggestedRoutes(uuid, accountFrom, accountTo, amount, tokenFrom, tokenTo,
                                          fromChainID, toChainID, preferredChainIDs, sendType) {
                console.debug("fetchSuggestedRoutes called >> uuid = ", uuid, " accountFrom = ", accountFrom, " accountTo =",
                              accountTo, "amount = ", amount, " tokenFrom = ", tokenFrom, " tokenTo = ", tokenTo,
                              " fromChainID = ", fromChainID, " toChainID = ", toChainID,
                              " preferredChainIDs = ", preferredChainIDs, " sendType =", sendType)
                d.uuid = uuid
                fetchSuggestedRoutesSignal()
            }
            function authenticateAndTransfer(uuid, accountFrom, accountTo, tokenFrom,
                                             tokenTo, sendType, tokenName, tokenIsOwnerToken, paths) {
                console.debug("authenticateAndTransfer called >> uuid ", uuid, " accountFrom = ",accountFrom, " accountTo =",
                              accountTo, "tokenFrom = ",tokenFrom, " tokenTo = ",tokenTo, " sendType = ", sendType,
                              " tokenName = ", tokenName, " tokenIsOwnerToken = ", tokenIsOwnerToken, " paths = ", paths)
                d.uuid = uuid
                authenticateAndTransferSignal()
            }

            // only for testing
            signal fetchSuggestedRoutesSignal()
            signal authenticateAndTransferSignal()
        }

        SignalSpy {
            id: fetchSuggestedRoutesSpy
            target: dSwapStore
            signalName: "fetchSuggestedRoutesSignal"
        }

        SignalSpy {
            id: authenticateAndTransferSpy
            target: dSwapStore
            signalName: "authenticateAndTransferSignal"
        }

        TokensStoreMock {
            id: tokensStore
            tokenGroupsModel: TokenGroupsModel {}
            _displayAssetsBelowBalanceThresholdDisplayAmountFunc: () => 0
        }

        SwapModalAdaptor {
            id: adaptor
            swapStore: dSwapStore
            walletAssetsStore: WalletAssetsStoreMock {
                id: thisWalletAssetStore
                walletTokensStore: tokensStore
                readonly property var baseGroupedAccountAssetModel: GroupedAccountsAssetsModel {}
            }
            currencyStore: SharedStores.CurrenciesStore {
                function formatBigNumber(number: string, symbol: string, noSymbolOption: bool) {
                    if (!number)
                        return "N/A"
                    if (!symbol)
                        symbol = "USD"
                    let options = {}
                    if (!!noSymbolOption)
                        options = {noSymbol: true}
                    return formatCurrencyAmount(parseFloat(number), symbol, options)
                }
            }
            networksStore: SharedStores.NetworksStore {
                readonly property SortFilterProxyModel activeNetworks: SortFilterProxyModel {
                    sourceModel: NetworksModel.flatNetworks
                    filters: [
                        ValueFilter { roleName: "isTest"; value: areTestNetworksEnabledCheckbox.checked },
                        ValueFilter { roleName: "isActive"; value: true }
                    ]
                }
            }
            swapFormData: SwapInputParamsForm {
                onSelectedAccountAddressChanged: {
                    if (selectedAccountAddress !== accountComboBox.currentValue)
                        accountComboBox.currentIndex = accountComboBox.indexOfValue(selectedAccountAddress)
                }
            }
            swapOutputData: SwapOutputData {}
        }

        Component {
            id: swapModal
            SwapModal {
                id: modal
                visible: true
                modal: false
                closePolicy: Popup.CloseOnEscape
                destroyOnClose: true
                swapInputParamsForm: adaptor.swapFormData
                swapAdaptor: adaptor
                Binding {
                    target: swapInputParamsForm
                    property: "fromTokensKey"
                    value: fromTokenComboBox.currentValue ?? ""
                }
                Binding {
                    target: swapInputParamsForm
                    property: "toTokenKey"
                    value: toTokenComboBox.currentValue ?? ""
                }
                Binding {
                    target: swapInputParamsForm
                    property: "selectedNetworkChainId"
                    value: networksComboBox.currentValue ?? -1
                }
                Binding {
                    target: swapInputParamsForm
                    property: "selectedAccountAddress"
                    value: accountComboBox.currentValue ?? ""
                }
                Binding {
                    target: swapInputParamsForm
                    property: "fromTokenAmount"
                    value: swapInput.text
                }

                Connections {
                    target: approveTxButton
                    function onClicked() {
                        modal.swapAdaptor.sendApproveTx()
                    }
                }
            }
        }
    }

    ScrollView {
        id: rightPanel
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300
        SplitView.minimumHeight: 300

        ColumnLayout {
            spacing: 10

            CheckBox {
                id: areTestNetworksEnabledCheckbox
                text: "areTestNetworksEnabled"
                checked: true
                onToggled: networksComboBox.currentIndex = 0
            }

            StatusBaseText {
                text:"Selected Account"
            }
            ComboBox {
                id: accountComboBox
                textRole: "name"
                valueRole: "address"
                model: SortFilterProxyModel {
                    sourceModel: dSwapStore.accounts
                    filters: ValueFilter {
                        roleName: "canSend"
                        value: true
                    }
                }
                currentIndex: 0
            }

            StatusBaseText {
                text: "Selected Network"
            }
            ComboBox {
                id: networksComboBox
                textRole: "chainName"
                valueRole: "chainId"
                model: adaptor.filteredFlatNetworksModel
                currentIndex: 0
                onCountChanged: currentIndex = 0
            }

            StatusBaseText {
                text: "From Token"
            }
            ComboBox {
                id: fromTokenComboBox
                textRole: "name"
                valueRole: "key"
                model: d.tokenBySymbolModel
                currentIndex: 4
            }

            StatusInput {
                id: swapInput
                Layout.preferredWidth: 250
                label: "Token amount to swap"
                text: ""
            }

            StatusBaseText {
                text: "To Token"
            }
                ComboBox {
                id: toTokenComboBox
                textRole: "name"
                valueRole: "key"
                model: d.tokenBySymbolModel
                currentIndex: 0
            }

            Button {
                text: "simulate happy path no approval needed"
                onClicked: {
                    d.resetValues()
                    fromTokenComboBox.currentIndex = 0
                    swapInput.text = "0.2"
                    fetchSuggestedRoutesSpy.wait()
                    Backpressure.debounce(this, 250, () => {
                                              dSwapStore.suggestedRoutesReady(d.dummySwapTransactionRoutes.txHasRouteNoApproval, "", "")
                                          })()
                }
            }

            Button {
                text: "simulate happy path with approval needed"
                onClicked: {
                    d.resetValues()
                    accountComboBox.currentIndex = 2
                    fromTokenComboBox.currentIndex = 2
                    swapInput.text = "0.1"
                    fetchSuggestedRoutesSpy.wait()
                    Backpressure.debounce(this, 1000, () => {
                                              dSwapStore.suggestedRoutesReady(d.dummySwapTransactionRoutes.txHasRoutesApprovalNeeded, "", "")
                                          })()
                    Backpressure.debounce(this, 1500, () => {approveTxButton.clicked()})()
                    authenticateAndTransferSpy.wait()
                    Backpressure.debounce(this, 1000, () => {
                                              dSwapStore.transactionSent(networksComboBox.currentValue, "0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", d.uuid, "")
                                          })()
                    Backpressure.debounce(this, 2000, () => {
                                              dSwapStore.transactionSendingComplete("0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "Success")
                                          })()
                    fetchSuggestedRoutesSpy.wait()
                    Backpressure.debounce(this, 1000, () => {
                                              dSwapStore.suggestedRoutesReady(d.dummySwapTransactionRoutes.txHasRouteNoApproval, "", "")
                                          })()
                }
            }

            Button {
                text: "simulate fetching proposal error"
                onClicked: {
                    d.resetValues()
                    fromTokenComboBox.currentIndex = 0
                    swapInput.text = "0.2"
                    fetchSuggestedRoutesSpy.wait()
                    Backpressure.debounce(this, 250, () => {
                                              dSwapStore.suggestedRoutesReady(d.dummySwapTransactionRoutes.txNoRoutes, "ERR-123", "Fetching proposal error")

                    })()
                }
            }

            Button {
                text: "simulate approval failed"
                onClicked: {
                    d.resetValues()
                    accountComboBox.currentIndex = 2
                    fromTokenComboBox.currentIndex = 2
                    swapInput.text = "0.1"
                    fetchSuggestedRoutesSpy.wait()
                    Backpressure.debounce(this, 1000, () => {
                                              dSwapStore.suggestedRoutesReady(d.dummySwapTransactionRoutes.txHasRoutesApprovalNeeded, "", "")
                                          })()
                    Backpressure.debounce(this, 1500, () => {approveTxButton.clicked()})()
                    authenticateAndTransferSpy.wait()
                    Backpressure.debounce(this, 1000, () => {
                                              dSwapStore.transactionSent(networksComboBox.currentValue, "0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", d.uuid, "")
                                          })()
                    Backpressure.debounce(this, 2000, () => {
                                              dSwapStore.transactionSendingComplete("0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "Failed")
                                          })()
                }
            }

            CheckBox {
                id: advancedSignalsCheckBox
                text: "show advanced signals for testing"
                checked: false
            }

            ComboBox {
                id: routerErrorComboBox
                model: [
                    {name: "errNotEnoughTokenBalance", value: Constants.routerErrorCodes.router.errNotEnoughTokenBalance},
                    {name: "errNotEnoughNativeBalance", value: Constants.routerErrorCodes.router.errNotEnoughNativeBalance},
                    {name: "errPriceTimeout", value: Constants.routerErrorCodes.processor.errPriceTimeout},
                    {name: "errNotEnoughLiquidity", value: Constants.routerErrorCodes.processor.errNotEnoughLiquidity},
                    {name: "errPriceImpactTooHigh", value: Constants.routerErrorCodes.processor.errPriceImpactTooHigh}
                ]
                textRole: "name"
                valueRole: "value"
                currentIndex: 0
                visible: advancedSignalsCheckBox.checked
            }

            Button {
                text: "emit no routes found event with error"
                onClicked: {
                    const txRoutes = d.dummySwapTransactionRoutes.txNoRoutes
                    txRoutes.uuid = d.uuid
                    dSwapStore.suggestedRoutesReady(txRoutes, routerErrorComboBox.currentValue, "")
                }
                visible: advancedSignalsCheckBox.checked
            }

            Button {
                text: "emit no approval needed route"
                onClicked: {
                    const txRoutes = d.dummySwapTransactionRoutes.txHasRouteNoApproval
                    txRoutes.uuid = d.uuid
                    dSwapStore.suggestedRoutesReady(txRoutes, "", "")
                }
                visible: advancedSignalsCheckBox.checked
            }

            Button {
                text: "emit approval needed route"
                onClicked: {
                    const txRoutes = d.dummySwapTransactionRoutes.txHasRoutesApprovalNeeded
                    txRoutes.uuid = d.uuid
                    dSwapStore.suggestedRoutesReady(txRoutes, "", "")
                }
                visible: advancedSignalsCheckBox.checked
            }

            Button {
                id: approveTxButton
                text: "call approveTX"
                visible: advancedSignalsCheckBox.checked
            }

            Button {
                text: "emit transactionSent successful"
                onClicked: {
                    dSwapStore.transactionSent(networksComboBox.currentValue, "0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", d.uuid, "")
                }
                visible: advancedSignalsCheckBox.checked
            }

            Button {
                text: "emit transactionSent failure"
                onClicked: {
                    dSwapStore.transactionSent(networksComboBox.currentValue, "", d.uuid, "no password given")
                }
                visible: advancedSignalsCheckBox.checked
            }

            Button {
                text: "emit approval completed successfully"
                onClicked: {
                    dSwapStore.transactionSendingComplete("0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "Success")
                }
                visible: advancedSignalsCheckBox.checked
            }

            Button {
                text: "emit approval completed with failure"
                onClicked: {
                    dSwapStore.transactionSendingComplete("0x877ffe47fc29340312611d4e833ab189fe4f4152b01cc9a05bb4125b81b2a89a", "Failed")
                }
                visible: advancedSignalsCheckBox.checked
            }
        }
    }
}

// category: Popups
