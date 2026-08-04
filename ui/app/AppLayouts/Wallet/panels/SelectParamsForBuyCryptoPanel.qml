import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Components
import StatusQ.Components.private

import AppLayouts.Wallet.controls

import utils

ColumnLayout {
    id: root

    // required properties
    required property var assetsModel
    required property var selectedProvider
    required property string selectedTokenGroupKey
    required property int selectedNetworkChainId
    required property var filteredFlatNetworksModel

    /** Forwarded to AssetSelectorCompact; see SearchableAssetsPanel.formatCurrencyBalance. **/
    property var formatCurrencyBalance: (amount) => (amount === undefined ? "" : Number(amount).toLocaleCurrencyString(Qt.locale()))

    signal networkSelected(int chainId)
    signal tokenSelected(string tokenGroupKey)

    onSelectedTokenGroupKeyChanged: assetSelector.update()
    onSelectedNetworkChainIdChanged: assetSelector.update()

    spacing: 20

    StatusListItem {
        objectName: "selectParamsForBuyCryptoPanelHeader"
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft
        leftPadding: 0
        rightPadding: 0

        title: qsTr("Buy via %1").arg(!!root.selectedProvider ? root.selectedProvider.name: "")
        subTitle: qsTr("Select which network and asset")
        statusListItemTitle.color: Theme.palette.directColor1
        asset.name: !!root.selectedProvider ? root.selectedProvider.logoUrl: ""
        asset.isImage: true
        color: StatusColors.transparent
        enabled: false
    }

    StatusMenuSeparator {
        Layout.fillWidth: true
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        StatusBaseText {
            text: qsTr("Select network")
            color: Theme.palette.directColor1
            font.pixelSize: Theme.primaryTextFontSize
            lineHeight: 22
            lineHeightMode: Text.FixedHeight
            verticalAlignment: Text.AlignVCenter
        }
        NetworkFilter {
            objectName: "networkFilter"
            Layout.fillWidth: true
            control.popup.width: parent.width
            multiSelection: false
            showSelectionIndicator: false
            flatNetworks: root.filteredFlatNetworksModel
            selection: [root.selectedNetworkChainId]
            onSelectionChanged: root.networkSelected(selection[0])
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        StatusBaseText {
            text: qsTr("Select asset")
            color: Theme.palette.directColor1
            font.pixelSize: Theme.primaryTextFontSize
            lineHeight: 22
            lineHeightMode: Text.FixedHeight
            verticalAlignment: Text.AlignVCenter
        }

        AssetSelectorCompact {
            id: assetSelector

            objectName: "assetSelector"

            Layout.fillWidth: true

            model: root.assetsModel
            formatCurrencyBalance: root.formatCurrencyBalance

            flatNetworksModel: root.filteredFlatNetworksModel
            selectedChainId: root.selectedNetworkChainId
            onChainSelected: function(chainId) {
                if (chainId !== -1)
                    root.networkSelected(chainId)
            }

            onSelected: root.tokenSelected(key)

            function update() {
                Qt.callLater(()=> {
                    if (!root.assetsModel || !root.selectedTokenGroupKey
                        || root.selectedNetworkChainId === -1)
                        return

                    const entry = ModelUtils.getByKey(root.assetsModel,
                                                      "key", root.selectedTokenGroupKey)
                    if (entry) {
                        assetSelector.setSelection(entry.name, entry.symbol,
                                                   entry.logoUri || Constants.tokenIcon(entry.symbol), entry.key)
                        root.tokenSelected(entry.key)
                    } else {
                        assetSelector.reset()
                        root.tokenSelected("")
                    }
                })
            }
        }
    }
}
