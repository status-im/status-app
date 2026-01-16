import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Communities.views
import AppLayouts.Communities.controls

import Storybook
import Models

import SortFilterProxyModel
import utils

SplitView {
    orientation: Qt.Vertical
    SplitView.fillWidth: true

    Logs { id: logs }

    ListModel {
        id: members

        property int counter: 0

        function addMember() {
            const i = counter++
            const key = `pub_key_${i}`

            const firstLetters = ["a", "b", "c", "d"]
            const firstLetterIdx = Math.min(Math.floor(i / firstLetters.length),
                                            firstLetters.length - 1)
            const firstLetter = firstLetters[firstLetterIdx]

            append({
                alias: "",
                colorId: "1",
                displayName: `${firstLetter}contact ${i}`,
                ensName: "",
                icon: "",
                isContact: true,
                localNickname: "",
                onlineStatus: 1,
                pubKey: key,
                isVerified: true,
                isUntrustworthy: false
            })
        }

        Component.onCompleted: {
            for (let i = 0; i < 33; i++)
                addMember()
        }
    }

    Timer {
        id: feesCalculationTimer

        interval: 2000

        property var feesPerContract: []

        function createAmount(amount, symbol, decimals) {
            return {
                amount, symbol,
                displayDecimals: decimals, stripTrailingZeroes: false
            }
        }

        function requestMockedFees(contractKeysAndAmounts) {
            if (!contractKeysAndAmounts)
                return

            editAirdropView.feesAvailable = false
            editAirdropView.totalFeeText = ""
            editAirdropView.feeErrorText = ""
            editAirdropView.feesPerSelectedContract = []

            const fees = []

            contractKeysAndAmounts.forEach(entry => {
                fees.push({
                    contractUniqueKey: entry.contractUniqueKey,
                    feeText: "0.0002120115 ETH (123.15 USD)"
                })
            })

            feesPerContract = fees

            restart()
        }

        onTriggered: {
            editAirdropView.totalFeeText = createAmount(0.0002120115 * feesPerContract.length, "ETH", 4) + "(" ,createAmount(123.15 * feesPerContract.length, "USD", 2),"USD)"
            editAirdropView.feeErrorText = feesErrorsButtonGroup.checkedButton.code ? feesErrorsButtonGroup.checkedButton.text : ""
            editAirdropView.feesAvailable = true
            editAirdropView.feesPerSelectedContract = feesCalculationTimer.feesPerContract
        }
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        EditAirdropView {
            id: editAirdropView

            anchors.fill: parent

            CollectiblesModel {
                id: collectiblesModel
            }

            SortFilterProxyModel {
                id: collectiblesModelWithSupply

                sourceModel: collectiblesModel

                proxyRoles: [
                    ExpressionRole {
                        name: "supply"
                        expression: ((model.index + 1) * 115).toString()
                    },
                    ExpressionRole {
                        name: "infiniteSupply"
                        expression: !(model.index % 4)
                    },
                    ExpressionRole {
                        name: "accountName"
                        expression: "StatusAccount"
                    },
                    ExpressionRole {
                        name: "contractUniqueKey"
                        expression: "contractUniqueKey_" + model.index
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

                filters: ValueFilter {
                    roleName: "category"
                    value: TokenCategories.Category.Community
                }

                Component.onCompleted: {
                    Qt.callLater(() => editAirdropView.collectiblesModel = this)
                }
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
                        expression: ((model.index + 1) * 258).toString()
                    },
                    ExpressionRole {
                        name: "infiniteSupply"
                        expression: !(model.index % 4)
                    },
                    ExpressionRole {
                        name: "accountName"
                        expression: "StatusAccount"
                    },
                    ExpressionRole {
                        name: "contractUniqueKey"
                        expression: "contractUniqueKey_" + model.index
                    },
                    ExpressionRole {
                        name: "chainName"
                        expression: model.index ? "Ethereum Mainnet" : "Sepolia"
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

                Component.onCompleted: {
                    Qt.callLater(() => editAirdropView.assetsModel = this)
                }
            }

            assetsModel: AssetsModel {}
            collectiblesModel: CollectiblesModel {}
            membersModel: members
            totalFeeText: ""
            feeErrorText: ""
            feesPerSelectedContract: []
            feesAvailable: false

            onShowingFeesChanged: {
                feesCalculationTimer.requestMockedFees(editAirdropView.selectedContractKeysAndAmounts)
            }

            accountsModel: ListModel {
                ListElement {
                    name: "Test account"
                    emoji: "😋"
                    address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
                    color: "red"
                }
                ListElement {
                    name: "Another account - generated"
                    emoji: "🚗"
                    address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8888"
                    color: "blue"
                }
            }

            communityDetails: QtObject {
                readonly property string name: "Socks"
                readonly property string id: "SOCKS"
                readonly property string image: ModelsData.icons.socks
                readonly property string color: "red"
                readonly property bool owner: true
            }

            onAirdropClicked: {
                logs.logEvent("EditAirdropView::airdropClicked",
                              ["airdropTokens", "addresses",
                               "membersPubKeys", "feeAccountAddress"],
                              arguments)
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 160

        logsView.logText: logs.logText

        ColumnLayout {
            TextEdit {
                readOnly: true
                selectByMouse: true
                text: "valid address: 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc4"
            }

            MenuSeparator {}

            ButtonGroup {
                id: feesErrorsButtonGroup

                buttons: feesErrorsRow.children
                onCheckedButtonChanged: {
                    feesCalculationTimer.requestMockedFees(editAirdropView.selectedContractKeysAndAmounts)
                }
            }

            RowLayout {
                id: feesErrorsRow

                Label {
                    text: "Fees calculation errors:"
                }

                RadioButton {
                    readonly property int code: Constants.ComputeFeeErrorCode.Success
                    text: `Success (${code})`
                    checked: true
                }

                RadioButton {
                    readonly property int code: Constants.ComputeFeeErrorCode.Infura
                    text: `Infura (${code})`
                }

                RadioButton {
                    readonly property int code: Constants.ComputeFeeErrorCode.Balance
                    text: `Balance (${code})`
                }

                RadioButton {
                    readonly property int code: Constants.ComputeFeeErrorCode.Other
                    text: `Other (${code})`
                }
            }
        }
    }
}

// category: Views

// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22602-495563&t=9dIP8Sji2UlfhsEs-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22628-495258&t=9dIP8Sji2UlfhsEs-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22628-496145&t=9dIP8Sji2UlfhsEs-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22647-497754&t=9dIP8Sji2UlfhsEs-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22647-501014&t=9dIP8Sji2UlfhsEs-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22647-499051&t=kHAcE8WSCyGqhWSH-0
