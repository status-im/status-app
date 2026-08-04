import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import Storybook
import Models

import AppLayouts.Wallet.views

import utils

SplitView {
    id: root
    orientation: Qt.Vertical

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        background: Rectangle {
            color: Theme.palette.baseColor3
        }

        Rectangle {
            width: 380
            height: 200
            color: Theme.palette.statusListItem.backgroundColor
            border.color: Theme.palette.primaryColor1
            border.width: 1
            anchors.centerIn: parent

            TokenSelectorAssetDelegate {
                width: 333
                anchors.centerIn: parent

                name: "Ethereum"
                symbol: "ETH"
                iconSource: Constants.tokenIcon(symbol)
                cryptoBalanceStr: "8.42 ETH"
                currencyBalanceAsString: "14,456.42 USD"
                isAutoHovered: ctrlIsAutoHovered.checked

                balancesModel: ListModel {
                    readonly property var data: [
                        { chainId: 1, balance: 1234.50, iconUrl: "network/ethereum" },
                        { chainId: 42161, balance: 55.91, iconUrl: "network/arbitrum" },
                        { chainId: 10, balance: 45.12, iconUrl: "network/optimism" },
                        { chainId: 11155420, balance: 1.23, iconUrl: "network/testnet" }
                    ]
                    Component.onCompleted: append(data)
                }
                currentBalance: 1336.76
                defaultNetworkIcon: "network/ethereum"
                tokenAddress: ctrlShowAddress.checked
                              ? "0xdAC17F958D2ee523a2206206994597C13D831ec7" : ""

                enabled: ctrlEnabled.checked
                highlighted: ctrlHighlighted.checked

                onClicked: logs.logEvent("TokenSelectorAssetDelegate::onClicked")
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 300
        SplitView.preferredHeight: 300

        logsView.logText: logs.logText

        RowLayout {
            anchors.fill: parent

            ColumnLayout {
                Switch {
                    id: ctrlEnabled
                    text: "Enabled"
                    checked: true
                }
                Switch {
                    id: ctrlHighlighted
                    text: "Highlighted"
                    checked: false
                }
                Switch {
                    id: ctrlIsAutoHovered
                    text: "isAutoHovered"
                    checked: false
                }
                Switch {
                    id: ctrlShowAddress
                    text: "Show address"
                    checked: false
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}

// category: Delegates
