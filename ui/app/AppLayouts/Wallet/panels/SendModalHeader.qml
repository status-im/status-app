import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme

import AppLayouts.Wallet.controls

import utils

RowLayout {
    id: root

    /**
    Expected model structure:
    - tokensKey: unique string ID of the token (asset); e.g. "ETH" or contract address
    - name: user visible token name (e.g. "Ethereum")
    - symbol: user visible token symbol (e.g. "ETH")
    - decimals: number of decimal places
    - communityId:optional; ID of the community this token belongs to, if any
    - marketDetails: object containing props like `currencyPrice` for the computed values below
    - balances: submodel[ chainId:int, account:string, balance:BigIntString, iconUrl:string ]
    - currentBalance: amount of tokens
    - currencyBalance: e.g. `1000.42` in user's fiat currency
    - currencyBalanceAsString: e.g. "1 000,42 CZK" formatted as a string according to the user's locale
    - balanceAsString: `1.42` formatted as e.g. "1,42" in user's locale
    - iconSource: string
    **/
    required property var assetsModel
    /**
    Expected model structure:
    - groupName: group name (from collection or community name)
    - icon: from imageUrl or mediaUrl
    - type: can be "community" or "other"
    - subitems: submodel of collectibles/collections of the group
    - key: key of collection (community type) or collectible (other type)
    - name: name of the subitem (of collectible or collection)
    - balance: balance of collection (in case of community collectibles)
               or collectible (in case of ERC-1155)
    - icon: icon of the subitem
    **/
    required property var collectiblesModel
    /**
    Expected model structure:
    - chainId: network chain id
    - chainName: name of network
    - iconUrl: network icon url
    **/
    required property var networksModel

    /** input property holds header is being scrolled **/
    property bool isScrolling

    /** input property holds if the header is the sticky header **/
    property bool isStickyHeader

    /** input property to show only ERC20 assets and no collectibles **/
    property bool displayOnlyAssets

    /** input property to decide if the header can be interacted with **/
    property bool interactive: true

    /** input property for programatic selection of network **/
    property int selectedChainId

    /** property exposing the currently selected token selector tab **/
    property alias tokenSelectorTab: tokenSelector.currentTab

    /** signal to propagate that an asset was selected **/
    signal assetSelected(string key)
    /** signal to propagate that a collection was selected **/
    signal collectionSelected(string key)
    /** signal to propagate that a collectible was selected **/
    signal collectibleSelected(string key)
    /** signal to propagate that a network was selected **/
    signal networkSelected(int chainId)
    /** signal to propagate that a search in assets was performed **/
    signal searchInAssets(string keyword)
    /** signal to propagate that more assets should be fetched **/
    signal fetchMoreAssets()

    /** input function for programatic selection of token
    (asset/collectible/collection) **/
    function setToken(name, icon, key) {
        tokenSelector.setSelection(name, icon, key)
    }

    implicitHeight: sendModalTitleText.height

    spacing: 8

    // if not closed during scrolling they move with the header and it feels undesirable
    onIsScrollingChanged: {
        tokenSelector.close()
        networkFilter.control.popup.close()
    }

    StatusBaseText {
        id: sendModalTitleText

        objectName: "sendModalTitleText"

        Layout.preferredWidth: contentWidth

        lineHeightMode: Text.FixedHeight
        lineHeight: root.isStickyHeader ? 30 : 38
        font.pixelSize: root.isStickyHeader ? 22 : 28
        elide: Text.ElideRight

        text: qsTr("Send")
    }

    TokenSelector {
        id: tokenSelector

        objectName: "tokenSelector"

        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth

        size: root.isStickyHeader ?
                  TokenSelectorButton.Size.Small:
                  TokenSelectorButton.Size.Normal

        enabled: root.interactive
        showSectionName: false

        assetsModel: root.assetsModel
        collectiblesModel: root.displayOnlyAssets ? null: root.collectiblesModel

        onCollectibleSelected: (key) => root.collectibleSelected(key)
        onCollectionSelected: (key) => root.collectionSelected(key)
        onAssetSelected: (key) => root.assetSelected(key)
        onSearchInAssets: (keyword) => root.searchInAssets(keyword)
        onFetchMoreAssets: root.fetchMoreAssets()
    }

    // Horizontal spacer
    RowLayout {}

    StatusBaseText {
        Layout.alignment: Qt.AlignRight

        text: qsTr("On:")
        color: Theme.palette.baseColor1
        font.pixelSize: Theme.additionalTextSize
        lineHeight: 38
        lineHeightMode: Text.FixedHeight
        verticalAlignment: Text.AlignVCenter

        visible: networkFilter.visible
    }

    NetworkFilter {
        id: networkFilter

        objectName: "networkFilter"

        Layout.alignment: Qt.AlignTop

        flatNetworks: root.networksModel

        multiSelection: false
        showSelectionIndicator: false
        showTitle: false
        interactive: root.interactive

        Binding on selection {
            value: [root.selectedChainId]
            when: root.selectedChainId !== 0
        }
        onSelectionChanged: {
            if (root.selectedChainId !== selection[0]) {
                root.networkSelected(selection[0])
            }
        }

        onToggleNetwork: (chainId) => root.networkSelected(chainId)
    }
}
