import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core.Theme

import utils

import shared.stores
import shared.stores.send

import AppLayouts.Wallet.stores
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.controls

import AppLayouts.Wallet.popups.swap

import SortFilterProxyModel

import Storybook
import Models
import Mocks

SplitView {
    id: root

    Logs { id: logs }

    ListModel {
        id: plainTokensModel
        ListElement {
            key: "aave"
            name: "Aave"
            symbol: "AAVE"
            image: "https://cryptologos.cc/logos/aave-aave-logo.png"
            communityId: ""
        }
        ListElement {
            key: "usdc"
            name: "USDC"
            symbol: "USDC"
            image: ""
            communityId: ""
        }
        ListElement {
            key: "hst"
            name: "Decision Token"
            symbol: "HST"
            image: "https://etherscan.io/token/images/horizonstate2_28.png"
            communityId: ""
        }
    }

    QtObject {
        id: d

        readonly property SwapInputParamsForm swapInputParamsForm: SwapInputParamsForm {
            selectedAccountAddress: ctrlAccount.currentValue ?? ""
            selectedNetworkChainId: ctrlSelectedNetworkChainId.currentValue ?? -1
            fromGroupKey: ctrlFromTokensKey.text
            fromTokenAmount: ctrlFromTokenAmount.text
            toGroupKey: ctrlToTokenKey.text
            toTokenAmount: ctrlToTokenAmount.text
        }

        readonly property SwapModalAdaptor adaptor: SwapModalAdaptor {
            swapStore: SwapStore {
                readonly property var accounts: WalletAccountsModel {}
                signal suggestedRoutesReady(var txRoutes, string errCode, string errDescription)
                signal transactionSent(var chainId, var txHash, var uuid, var error)
                signal transactionSendingComplete(var txHash, var status)
            }
            networksStore: NetworksStore {
                readonly property var activeNetworks: NetworksModel.flatNetworks
            }
            walletAssetsStore: WalletAssetsStoreMock {
                id: thisWalletAssetStore
                walletTokensStore: TokensStoreMock {
                    tokenGroupsModel: TokenGroupsModel {}
                }
                readonly property var baseGroupedAccountAssetModel: GroupedAccountsAssetsModel {}
            }
            currencyStore: CurrenciesStore {}
            swapFormData: d.swapInputParamsForm
            swapOutputData: SwapOutputData {}
        }
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        color: Theme.palette.baseColor3

        Item {
            width: 492
            height: payPanel.height + receivePanel.height + 4
            anchors.centerIn: parent

            SwapInputPanel {
                id: payPanel
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }

                currencyStore: d.adaptor.currencyStore
                flatNetworksModel: d.adaptor.networksStore.activeNetworks
                tokenSelectorModel: TokenSelectorModelMock {
                    sourceModel: d.adaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel
                }

                selectedNetworkChainId: d.swapInputParamsForm.selectedNetworkChainId
                selectedAccountAddress: d.swapInputParamsForm.selectedAccountAddress
                nonInteractiveGroupKey: receivePanel.selectedHoldingId

                groupKey: d.swapInputParamsForm.fromGroupKey
                tokenAmount: d.swapInputParamsForm.fromTokenAmount

                swapSide: SwapInputPanel.SwapSide.Pay
                fiatInputInteractive: ctrlFiatInputInteractive.checked
                swapExchangeButtonWidth: swapButton.width
                mainInputLoading: ctrlMainInputLoading.checked
                bottomTextLoading: ctrlBottomTextLoading.checked
            }

            SwapInputPanel {
                id: receivePanel
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                currencyStore: d.adaptor.currencyStore
                flatNetworksModel: d.adaptor.networksStore.activeNetworks
                tokenSelectorModel: TokenSelectorModelMock {
                    sourceModel: d.adaptor.walletAssetsStore.walletTokensStore.tokenGroupsModel
                }

                selectedNetworkChainId: d.swapInputParamsForm.selectedNetworkChainId
                selectedAccountAddress: d.swapInputParamsForm.selectedAccountAddress
                nonInteractiveGroupKey: payPanel.selectedHoldingId

                groupKey: d.swapInputParamsForm.toGroupKey
                tokenAmount: d.swapInputParamsForm.toTokenAmount

                swapSide: SwapInputPanel.SwapSide.Receive
                fiatInputInteractive: ctrlFiatInputInteractive.checked
                swapExchangeButtonWidth: swapButton.width
                mainInputLoading: ctrlMainInputLoading.checked
                bottomTextLoading: ctrlBottomTextLoading.checked
            }

            SwapExchangeButton {
                id: swapButton
                anchors.centerIn: parent
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumWidth: 250
        SplitView.preferredWidth: 250

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Chain:"
                }
                ComboBox {
                    Layout.fillWidth: true
                    id: ctrlSelectedNetworkChainId
                    model: d.adaptor.swapStore.flatNetworks
                    textRole: "chainName"
                    valueRole: "chainId"
                    displayText: currentIndex === -1 ? "All chains" : currentText
                    currentIndex: -1 // all chains
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Account:" }
                ComboBox {
                    Layout.fillWidth: true
                    id: ctrlAccount
                    textRole: "name"
                    valueRole: "address"
                    displayText: currentText || "All accounts"
                    model: SortFilterProxyModel {
                        sourceModel: d.adaptor.swapStore.accounts
                        sorters: RoleSorter { roleName: "position" }
                    }
                    currentIndex: -1
                }
            }


            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Pay symbol:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlFromTokensKey
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Pay amount:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlFromTokenAmount
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Receive symbol:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlToTokenKey
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Receive amount:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlToTokenAmount
                }
            }
            Switch {
                id: ctrlFiatInputInteractive
                text: "Fiat input interactive"
                checked: false
            }
            Switch {
                id: ctrlMainInputLoading
                text: "mainInputLoading"
            }
            Switch {
                id: ctrlBottomTextLoading
                text: "bottomTextLoading"
            }

            Label {
                Layout.fillWidth: true
                font.weight: Font.Medium
                text: "<b>Pay:</b><ul><li>Symbol: %1<li>Amount: %2<li>Valid: %3"
                  .arg(payPanel.selectedHoldingId || "N/A")
                  .arg(payPanel.value.toString())
                  .arg(payPanel.valueValid ? "true" : "false")
            }
            Label {
                Layout.fillWidth: true
                font.weight: Font.Medium
                text: "<b>Receive:</b><ul><li>Symbol: %1<li>Amount: %2<li>Valid: %3"
                  .arg(receivePanel.selectedHoldingId || "N/A")
                  .arg(receivePanel.value.toString())
                  .arg(receivePanel.valueValid ? "true" : "false")
            }

            Item { Layout.fillHeight: true }
        }
    }
}

// category: Panels

// https://www.figma.com/design/TS0eQX9dAZXqZtELiwKIoK/Swap---Milestone-1?node-id=3404-111405&t=G96tBLQr2j73HT9X-0
