import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import Storybook
import Models

import AppLayouts.Wallet.popups.swap

import utils

import QtModelsToolkit

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Horizontal

    property var dialog

    function createAndOpenDialog() {
        dialog = dlgComponent.createObject(popupBg)
        dialog.open()
    }

    Component.onCompleted: createAndOpenDialog()

    QtObject {
        id: priv

        readonly property var accountsModel: WalletAccountsModel {}
        readonly property var selectedAccount: selectedAccountEntry.item

        readonly property var networksModel: NetworksModel.flatNetworks
        readonly property var selectedNetwork: selectedNetworkEntry.item
    }

    ModelEntry {
        id: selectedAccountEntry
        sourceModel: priv.accountsModel
        key: "address"
        value: ctrlAccount.currentValue
    }

    ModelEntry {
        id: selectedNetworkEntry
        sourceModel: priv.networksModel
        key: "chainId"
        value: ctrlNetwork.currentValue
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            id: popupBg
            anchors.fill: parent

            Button {
                anchors.centerIn: parent
                text: "Reopen"

                onClicked: createAndOpenDialog()
            }

            Component {
                id: dlgComponent
                SwapSignModal {
                    anchors.centerIn: parent
                    destroyOnClose: true
                    modal: false

                    title: qsTr("Sign Swap")

                    formatBigNumber: (number, symbol, noSymbolOption) => parseFloat(number).toLocaleString(Qt.locale(), 'f', 2)
                                     + (noSymbolOption ? "" : " " + (symbol || Qt.locale().currencySymbol(Locale.CurrencyIsoCode)))

                    fromTokenSymbol: ctrlHtmlInjection.checked
                                     ? '<font color="#ff0000" size="6"><b>HACKED</b></font>'
                                     : ctrlFromSymbol.text
                    fromTokenAmount: ctrlHtmlInjection.checked
                                     ? '<a href="https://evil.example/?stolen=1">100</a>'
                                     : ctrlFromAmount.text
                    fromTokenContractAddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F"

                    toTokenSymbol: ctrlHtmlInjection.checked
                                   ? '<font color="#27ae60" size="6"><b>USDT</b></font>'
                                   : ctrlToSymbol.text
                    toTokenAmount: ctrlHtmlInjection.checked
                                   ? '<a href="https://evil.example/?stolen=1">100</a>'
                                   : ctrltoAmount.text
                    toTokenContractAddress: "0xdAC17F958D2ee523a2206206994597C13D831ec7"

                    accountName: priv.selectedAccount.name
                    accountAddress: priv.selectedAccount.address
                    accountEmoji: priv.selectedAccount.emoji
                    accountColor: Utils.getColorForId(Theme.palette, priv.selectedAccount.colorId)

                    networkShortName: priv.selectedNetwork.shortName
                    networkName: priv.selectedNetwork.chainName
                    networkIconPath: Assets.svg(priv.selectedNetwork.iconUrl)
                    networkBlockExplorerUrl: priv.selectedNetwork.blockExplorerURL
                    networkChainId: priv.selectedNetwork.chainId

                    serviceProviderName: ctrlHtmlInjection.checked
                                         ? '<font color="#27ae60" size="6"><b>Paraswap</b></font>'
                                         : Constants.swap.paraswapName
                    serviceProviderURL: Constants.swap.paraswapUrl
                    serviceProviderTandCUrl: Constants.swap.paraswapTermsAndConditionUrl

                    fiatFees: formatBigNumber(42.542567, "EUR")
                    cryptoFees: formatBigNumber(0.06, "ETH")
                    slippage: 0.5

                    keyUid: ""
                    migratedToColdWallet: ctrlLoginType.currentText === "Keycard"

                    feesLoading: ctrlLoading.checked

                    expirationSeconds: !!ctrlExpiration.text && parseInt(ctrlExpiration.text) ? parseInt(ctrlExpiration.text) : 0
                    onExpirationSecondsChanged: requestTimestamp = new Date()

                    onAccepted: logs.logEvent("accepted")
                    onRejected: logs.logEvent("rejected")
                    onClosed: logs.logEvent("closed")
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 250
        SplitView.preferredWidth: 250

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true
            TextField {
                Layout.fillWidth: true
                id: ctrlFromSymbol
                text: "DAI"
                placeholderText: "From symbol"
            }
            CheckBox {
                id: ctrlHtmlInjection
                text: "HTML injection demo"
                ToolTip.visible: hovered
                ToolTip.text: "Replaces token symbols, amounts, and service provider name with HTML "
                              + "payloads to verify textFormat: Text.PlainText renders literal markup. "
                              + "Reopen the dialog to apply."
            }
            TextField {
                Layout.fillWidth: true
                id: ctrlFromAmount
                text: "100"
                placeholderText: "From amount"
            }
            TextField {
                Layout.fillWidth: true
                id: ctrlToSymbol
                text: "USDT"
                placeholderText: "To symbol"
            }
            TextField {
                Layout.fillWidth: true
                id: ctrltoAmount
                text: "100"
                placeholderText: "To amount"
            }

            Text {
                text: "Selected Account"
            }
            ComboBox {
                Layout.fillWidth: true
                id: ctrlAccount
                textRole: "name"
                valueRole: "address"
                model: priv.accountsModel
                currentIndex: 0
            }

            Text {
                text: "Selected Network"
            }
            ComboBox {
                Layout.fillWidth: true
                id: ctrlNetwork
                textRole: "chainName"
                valueRole: "chainId"
                model: priv.networksModel
                currentIndex: 0
            }

            Switch {
                id: ctrlLoading
                text: "Fees loading"
            }

            Text {
                text: "Login Type"
            }
            ComboBox {
                Layout.fillWidth: true
                id: ctrlLoginType
                model: ["Password", "Biometrics", "Keycard"]
            }
            // The auth/sign icon is resolved from userProfile via Utils.resolveAuthSignIcon,
            // so drive the mock profile's biometric flag from the selector above.
            Binding {
                target: userProfile
                property: "usingBiometricLogin"
                value: ctrlLoginType.currentText === "Biometrics"
                restoreMode: Binding.RestoreBindingOrValue
            }

            TextField {
                Layout.fillWidth: true
                id: ctrlExpiration
                placeholderText: "Expiration in seconds"
            }
        }
    }
}

// category: Popups
// status: good
// https://www.figma.com/design/TS0eQX9dAZXqZtELiwKIoK/Swap---Milestone-1?node-id=3542-497191&t=ndwmuh3ZXlycGYWa-0
