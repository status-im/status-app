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
                currencyBalanceAsString: "14,456.42 USD"
                iconSource: Constants.tokenIcon(symbol)
                isAutoHovered: ctrlIsAutoHovered.checked

                balancesModel: ListModel {
                    readonly property var data: [
                        { chainId: 1, balanceAsString: "1234.50", iconUrl: "network/ethereum" },
                        { chainId: 42161, balanceAsString: "55.91", iconUrl: "network/arbitrum" },
                        { chainId: 10, balanceAsString: "45.12", iconUrl: "network/optimism" },
                        { chainId: 11155420, balanceAsString: "1.23", iconUrl: "network/testnet" }
                    ]
                    Component.onCompleted: append(data)
                }

                enabled: ctrlEnabled.checked
                highlighted: ctrlHighlighted.checked

                onClicked: key => logs.logEvent("TokenSelectorAssetDelegate::onClicked")
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

                Item { Layout.fillHeight: true }
            }
        }
    }
}

// category: Delegates
