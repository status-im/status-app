import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

import AppLayouts.Communities.panels
import AppLayouts.Communities.controls
import utils

import SortFilterProxyModel

import Storybook
import Models


SplitView {
    orientation: Qt.Vertical
    SplitView.fillWidth: true

    property bool globalUtilsReady: false
    property bool mainModuleReady: false

    Logs { id: logs }

    QtObject {
        function getColorId(publicKey) {
            return Math.floor(Math.random() * 10)
        }

        Component.onCompleted: {
            Utils.globalUtilsInst = this
            globalUtilsReady = true

        }
        Component.onDestruction: {
            globalUtilsReady = false
            Utils.globalUtilsInst = {}
        }
    }

    QtObject {
        function getContactDetailsAsJson() {
            return JSON.stringify({ ensVerified: true })
        }

        Component.onCompleted: {
            mainModuleReady = true
            Utils.mainModuleInst = this
        }
        Component.onDestruction: {
            mainModuleReady = false
            Utils.mainModuleInst = {}
        }
    }

    MintedTokensModel {
        id: mintedTokensModel
    }

    ListModel {
        id: emptyModel
    }

    Button {
        text: "Back"
        onClicked: loader.item.navigateBack()
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        color: Theme.palette.statusAppLayout.rightPanelBackgroundColor

        Loader {
            id: loader

            anchors.fill: parent
            active: globalUtilsReady && mainModuleReady

            sourceComponent: AirdropsSettingsPanel {
                id: airdropsSettingsPanel

                anchors.fill: parent
                anchors.topMargin: 50
                internalRightPadding: 50

                // User profile
                isOwner: ownerChecked.checked
                isTokenMasterOwner: masterTokenOwnerChecked.checked
                isAdmin: adminChecked.checked

                // Owner and TMaster related props:
                isOwnerTokenDeployed: deployCheck.checked
                isTMasterTokenDeployed: deployCheck.checked

                // Models
                assetsModel: AssetsModel {}
                collectiblesModel: ListModel {}

                enabledChainIds: "1"

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
                            name: "multiplierIndex"
                            expression: 0
                        },
                        ExpressionRole {
                            name: "infiniteSupply"
                            expression: !(model.index % 4)
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
                        Qt.callLater(() => airdropsSettingsPanel.collectiblesModel = this)
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
                            expression: model.index ? "Ethereum Mainnet" : "Goerli"
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

                    Component.onCompleted: {
                        Qt.callLater(() => airdropsSettingsPanel.assetsModel = this)
                    }
                }

                membersModel: UsersModel {}

                communityDetails: QtObject {
                    readonly property string name: "Socks"
                    readonly property string id: "SOCKS"
                    readonly property string image: ModelsData.icons.socks
                    readonly property string color: "red"
                    readonly property bool owner: true
                }
                accountsModel: WalletAccountsModel {}

                onAirdropClicked: logs.logEvent("AirdropsSettingsPanel::onAirdropClicked")
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 250

        logsView.logText: logs.logText

        Column {
            CheckBox {
                id: ownerChecked
                checked: true

                text: "Is Owner? [Owner will be able to create an OWNER and TOKEN MASTER token]"
            }

            CheckBox {
                id: masterTokenOwnerChecked
                checked: true

                text: "Is TMaster token owner? [TMaster token owner will be able to mint / airdrop tokens once the TMaster is already created]"
            }

            CheckBox {
                id: adminChecked
                checked: true

                text: "Is admin? [Admis will be able to see token views, but NOT manage them, like creating new artwork or asset]"
            }

            CheckBox {
                id: deployCheck
                checked: false

                text: "Owner and TMaster tokens deployed"
            }

            Row {
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Assets Decimals"
                }

                TextField {
                    id: decimalsText
                    text: "2"
                    width: 50
                }
            }
        }
    }
}

// category: Panels
