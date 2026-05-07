import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Popups
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils

import shared.controls
import "../../controls"

import SortFilterProxyModel

import utils

StatusMenu {
    id: root

    property var tokensFilter: []
    property var tokensList: []
    readonly property bool allTokensChecked: tokensFilter.length === 0

    property bool loadingCollectibles: false
    property var collectiblesList: []
    property var collectiblesFilter: []
    readonly property bool allCollectiblesChecked: collectiblesFilter.length === 0

    signal back()
    signal tokenToggled(string tokenSymbol)
    signal collectibleToggled(string uid)

    implicitWidth: 289

    function resetView() {
        tokensSearchBox.clear()
        collectiblesSearchBox.reset()
    }

    QtObject {
        id: d
        function searchAddressInList(addressPerChain, searchString) {
            let addressFound = false
            let tokenAddresses = SQUtils.ModelUtils.modelToFlatArray(addressPerChain, "address")
            for (let i =0; i< tokenAddresses.length; i++){
                if(tokenAddresses[i].toUpperCase().startsWith(searchString)) {
                    addressFound = true
                    break;
                }
            }
            return addressFound
        }
    }

    contentItem: ColumnLayout {
        spacing: 12
        MenuBackButton {
            id: backButton
            Layout.fillWidth: true
            onClicked: {
                close()
                back()
            }
        }

        StatusSwitchTabBar {
            id: tabBar
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            StatusSwitchTabButton {
                text: qsTr("Assets")
            }
            StatusSwitchTabButton {
                text: qsTr("Collectibles")
            }
        }

        StackLayout {
            id: layout
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                ButtonGroup {
                    id: tokenButtonGroup
                    exclusive: false
                }

                StatusBaseText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No Assets")
                    visible: root.tokensList.rowCount() === 0
                }

                SearchBox {
                    id: tokensSearchBox
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.preferredHeight: 36
                    placeholderText: qsTr("Search asset name")
                }

                StatusListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    model: SortFilterProxyModel {
                        id: tokenProxyModel
                        sourceModel: root.tokensList
                        filters: FastExpressionFilter {
                            readonly property string tokenSearchValue: tokensSearchBox.text.toUpperCase()
                            function search(symbol, name, addressPerChain, searchString) {
                                return (
                                    searchString === "" ||
                                    symbol.toUpperCase().startsWith(searchString) ||
                                    name.toUpperCase().startsWith(searchString) ||
                                    d.searchAddressInList(addressPerChain, searchString)
                                )
                            }
                            enabled: root.tokensList.rowCount() > 0
                            expression:search(symbol, name, addressPerChain, tokenSearchValue)
                            expectedRoles: ["symbol", "name", "addressPerChain"]
                        }
                    }
                    delegate: ActivityTypeCheckBox {
                        width: ListView.view.width
                        height: 44
                        title: model.name
                        titleAsideText: model.symbol
                        assetSettings.name: model.symbol ? Constants.tokenIcon(symbol) : ""
                        assetSettings.isImage: true
                        buttonGroup: tokenButtonGroup
                        allChecked: root.allTokensChecked
                        checked: root.allTokensChecked || root.tokensFilter.includes(model.symbol)
                        onActionTriggered: root.tokenToggled(model.symbol)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                ButtonGroup {
                    id: collectibleButtonGroup
                    exclusive: false
                }

                StatusBaseText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No Collectibles")
                    visible: root.collectiblesList.count === 0
                }

                SearchBox {
                    id: collectiblesSearchBox
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.preferredHeight: 36
                    placeholderText: qsTr("Search collectible name")
                }

                StatusListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    reuseItems: true
                    model: SortFilterProxyModel {
                        id: collectibleProxyModel
                        sourceModel: root.collectiblesList
                        filters: ExpressionFilter {
                            enabled: root.collectiblesList.count > 0 && !!collectiblesSearchBox.text
                            readonly property string searchText: collectiblesSearchBox.text.toUpperCase()
                            expression: {
                                return String(name).toUpperCase().startsWith(searchText)
                            }
                        }
                    }
                    delegate: ActivityTypeCheckBox {
                        required property var model
                        width: ListView.view.width
                        height: 44
                        title: model.name ?? ""
                        assetSettings.name: model.imageUrl ?? ""
                        assetSettings.isImage: true
                        assetSettings.bgWidth: 32
                        assetSettings.bgHeight: 32
                        assetSettings.bgRadius: assetSettings.bgHeight/2
                        buttonGroup: collectibleButtonGroup
                        allChecked: root.allCollectiblesChecked
                        checked: !loading && (root.allCollectiblesChecked || root.collectiblesFilter.includes(model.uid))
                        onActionTriggered: root.collectibleToggled(model.uid)
                        loading: root.loadingCollectibles
                    }
                }
            }
        }
    }
}
