import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortFilterProxyModel

import AppLayouts.Wallet.stores
import AppLayouts.Wallet.adaptors
import AppLayouts.Wallet.helpers

import StatusQ.Core.Utils

import shared.stores
import utils

import Storybook
import Models
import Mocks

Item {
    id: root

    QtObject {
        id: d

        readonly property int selectedNetworkChainId: ctrlSelectedNetworkChainId.currentValue

        readonly property var flatNetworks: NetworksModel.flatNetworks

        readonly property var tokensStore: TokensStoreMock {
            tokenGroupsModel: TokenGroupsModel {}
            searchResultModel: TokenGroupsModel {
                skipInitialLoad: true
                tokenGroupsForChainModel: d.tokensStore.tokenGroupsModel
            }
        }

        readonly property ChainTokenGroupsHolder chainTokenGroupsHolder: ChainTokenGroupsHolder {
            tokensStore: d.tokensStore
            chainId: d.selectedNetworkChainId
        }
        readonly property var tokenGroupsForChainModel: d.chainTokenGroupsHolder.model
    }

    PaymentRequestAdaptor {
        id: adaptor
        selectedNetworkChainId: d.selectedNetworkChainId
        flatNetworksModel: d.flatNetworks
        tokenGroupsForChainModel: d.tokenGroupsForChainModel
        searchResultModel: d.tokensStore.searchResultModel
    }

    ColumnLayout {
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.topMargin: 10

            Label {
                text: "Chain:"
            }
            ComboBox {
                id: ctrlSelectedNetworkChainId
                Layout.fillWidth: true
                model: d.flatNetworks
                textRole: "chainName"
                valueRole: "chainId"
                displayText: currentText
                currentIndex: 0
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            color: "lightgray"
        }

        RowLayout {
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Qt.AlignHCenter
                    font.bold: true
                    text: "Input"
                }

                GenericListView {
                    label: "Token groups model, total: " + d.tokensStore.tokenGroupsModel.count

                    model: d.tokensStore.tokenGroupsModel

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["index", "key", "name", "symbol", "decimals", "logoUri"]
                    skipEmptyRoles: true
                    insetComponent: Label {
                        text: {
                            if (!model)
                                return ""
                            let chains = "Chains: \n" + JSON.stringify(ModelUtils.modelToFlatArray(model["tokens"], "chainId"))
                            chains = chains.replace(/,/g, '\n')
                            return chains
                        }
                    }
                }

                GenericListView {
                    label: "Token groups for chain model, total: " + (d.tokenGroupsForChainModel?.count ?? 0)

                    model: d.tokenGroupsForChainModel

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["index", "key", "name", "symbol", "decimals", "logoUri"]
                    skipEmptyRoles: true
                }

                GenericListView {
                    label: "Networks model, total: " + d.flatNetworks.count

                    model: d.flatNetworks

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["chainId", "chainName",]
                    skipEmptyRoles: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Qt.AlignHCenter
                    font.bold: true
                    text: "Output"
                }
                GenericListView {
                    label: "Recipient model: " + count

                    model: adaptor.outputModel

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["index", "key", "name", "symbol", "logoUri", "sectionName"]

                    skipEmptyRoles: true
                }
            }
        }
    }
}

// category: Adaptors
