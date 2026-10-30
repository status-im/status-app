import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortFilterProxyModel

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Utils

import utils

import AppLayouts.Wallet.adaptors
import AppLayouts.Wallet.helpers
import AppLayouts.Wallet.stores
import AppLayouts.Chat.popups
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

        function launchPopup() {
            const modal = paymentRequestModalComponent.createObject(root)
            modal.open()
        }

        readonly property var accounts: WalletAccountsModel {}
        readonly property var flatNetworks: NetworksModel.flatNetworks

        readonly property string selectedAccountAddress: ctrlAccount.currentValue ?? ""
        readonly property int selectedNetworkChainId: ctrlSelectedNetworkChainId.currentValue ?? -1
    }

    PopupBackground {
        id: popupBg

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            id: reopenButton
            anchors.centerIn: parent
            text: "Reopen"
            enabled: !paymentRequestModalComponent.visible

            onClicked: d.launchPopup()
        }

        Component.onCompleted: Qt.callLater(d.launchPopup)

        readonly property var tokensStore: TokensStoreMock {
            tokenGroupsModel: TokenGroupsModel {}
            searchResultModel: TokenGroupsModel {
                skipInitialLoad: true
                tokenGroupsForChainModel: popupBg.tokensStore.tokenGroupsModel
            }
        }

        Component {
            id: paymentRequestModalComponent
            PaymentRequestModal {
                id: paymentRequestModal
                modal: false
                closePolicy: Popup.CloseOnEscape
                destroyOnClose: true

                readonly property SharedStores.CurrenciesStore currenciesStore: SharedStores.CurrenciesStore {}
                readonly property ChainTokenGroupsHolder chainTokenGroupsHolder: ChainTokenGroupsHolder {
                    tokensStore: popupBg.tokensStore
                    chainId: paymentRequestModal.selectedNetworkChainId
                }

                currentCurrency: currenciesStore.currentCurrency
                formatCurrencyAmount: currenciesStore.formatCurrencyAmount
                flatNetworksModel: d.flatNetworks
                accountsModel: d.accounts
                tokenGroupsForChainModel: chainTokenGroupsHolder.model
                searchResultModel: popupBg.tokensStore.searchResultModel

                Connections {
                    target: d
                    function onSelectedNetworkChainIdChanged() {
                        paymentRequestModal.selectedNetworkChainId = d.selectedNetworkChainId
                    }
                    function onSelectedAccountAddressChanged() {
                        paymentRequestModal.selectedAccountAddress = d.selectedAccountAddress
                    }
                }

                Component.onCompleted: {
                    if (d.selectedNetworkChainId > -1)
                        paymentRequestModal.selectedNetworkChainId = d.selectedNetworkChainId
                    if (!!d.selectedAccountAddress)
                        paymentRequestModal.selectedAccountAddress = d.selectedAccountAddress
                }

                onAllTokenGroupsAcquireRequested: popupBg.tokensStore.acquireAllTokenGroups()
                onAllTokenGroupsReleaseRequested: popupBg.tokensStore.releaseAllTokenGroups()
            }
        }
    }

    ScrollView {
        id: rightPanel
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300
        SplitView.minimumHeight: 300

        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10
            spacing: 10

            Label {
                text: "pre-selection:"
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Chain:"
                }
                ComboBox {
                    Layout.fillWidth: true
                    id: ctrlSelectedNetworkChainId
                    model: d.flatNetworks
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
                    id: ctrlAccount
                    Layout.fillWidth: true
                    textRole: "name"
                    valueRole: "address"
                    displayText: currentText || "----"
                    model: SortFilterProxyModel {
                        sourceModel: d.accounts
                        sorters: RoleSorter { roleName: "position" }
                    }
                    currentIndex: -1
                }
            }
        }
    }
}

// category: Popups
// status: good
