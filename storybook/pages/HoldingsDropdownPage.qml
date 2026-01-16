import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook
import Models

import AppLayouts.Communities.popups
import AppLayouts.Communities.controls

import SortFilterProxyModel

import utils

SplitView {
    id: root

    orientation: Qt.Vertical

    Pane {
        id: container

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        RowLayout {

            Label {
                text: "Open flow:"
            }

            Button {
                text: "Add"
                onClicked: {
                    holdingsDropdown.close()
                    holdingsDropdown.open()
                }
            }

            Button {
                text: "Update"
                onClicked: {
                    holdingsDropdown.close()
                    holdingsDropdown.setActiveTab(Constants.TokenType.ENS)
                    holdingsDropdown.openUpdateFlow()
                }
            }
        }

        HoldingsDropdown {
            id: holdingsDropdown

            directParent: container
            relativeX: container.width/2 - width/2
            relativeY: container.height/2 - height/2

            allTokensMode: ctrlAllTokensMode.checked

            CollectiblesModel {
                id: collectiblesModel
            }

            SortFilterProxyModel {
                id: collectiblesModelWithSupply

                sourceModel: collectiblesModel

                proxyRoles: [
                    ExpressionRole {
                        name: "supply"
                        expression: (model.index === 1 ? 1 : (model.index + 1) * 115).toString()
                    },
                    ExpressionRole {
                        name: "multiplierIndex"
                        expression: 0
                    },
                    ExpressionRole {
                        name: "infiniteSupply"
                        expression: !((model.index + 1) % 4)
                    },
                    ExpressionRole {
                        name: "chainName"
                        expression: model.index ? "Optimism" : "Arbitrum"
                    },
                    ExpressionRole {

                        readonly property string icon1: "network/optimism"
                        readonly property string icon2: "network/arbitrum"

                        name: "chainIcon"
                        expression: model.index ? icon1 : icon2
                    }
                ]
            }

            AssetsModel {
                id: assetsModel
            }

            SortFilterProxyModel {
                id: assetsModelWithSupply

                sourceModel: assetsModel

                proxyRoles: [
                    ExpressionRole {
                        name: "supply"
                        expression: ((model.index + 1) * 584).toString()
                                    + "0".repeat(18)
                    },
                    ExpressionRole {
                        name: "multiplierIndex"
                        expression: 18
                    },
                    ExpressionRole {
                        name: "infiniteSupply"
                        expression: !(model.index % 4)
                    },
                    ExpressionRole {
                        name: "chainName"
                        expression: model.index ? "Ethereum Mainnet" : "Sepolia"
                    },
                    ExpressionRole {
                        name: "decimals"
                        expression: decimalsText.text
                    },
                    ExpressionRole {
                        readonly property string icon1: "network/ethereum"
                        readonly property string icon2: "network/testnet"

                        name: "chainIcon"
                        expression: model.index ? icon1 : icon2
                    }
                ]

                filters: ValueFilter {
                    roleName: "category"
                    value: TokenCategories.Category.Community
                }
            }

            collectiblesModel: collectiblesModelWithSupply

            assetsModel: assetsModelWithSupply
            isENSTab: isEnsTabChecker.checked

            onOpened: contentItem.parent.parent = container
            Component.onCompleted: {
                holdingsDropdown.close()
                holdingsDropdown.open()
            }
        }
    }


    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 250

        RowLayout {
            CheckBox {
                id: isEnsTabChecker
                text: "ENS tab visible"
                checked: true
            }

            CheckBox {
                id: isAirdropMode
                text: "Airdrop mode"
                checked: false
            }

            CheckBox {
                id: ctrlAllTokensMode
                text: "All tokens mode"
            }

            Label {
                text: "Assets Decimals"
            }

            TextField {
                id: decimalsText
                Layout.preferredWidth: 50
                text: "2"
            }
        }
    }
}

// category: Popups

// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22721%3A499660&t=F5yiYQV2YGPBdrJ8-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22827%3A501381&t=7gqqAFbdG5KrPOmn-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22733%3A502088&t=5QSRGGAhrksqBs8e-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22772%3A496580&t=7gqqAFbdG5KrPOmn-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22772%3A496653&t=7gqqAFbdG5KrPOmn-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22734%3A502737&t=7gqqAFbdG5KrPOmn-0
