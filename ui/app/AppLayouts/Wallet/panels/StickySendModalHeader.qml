import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

Control {
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

    /** Forwarded to the inner SendModalHeader. **/
    property var formatCurrencyBalance: (amount) => (amount === undefined ? "" : String(amount))
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

    /** this property decided if the sticky header is visible or not.
    Not using visible property directly here as the animation on
    implicitHeight doesnt work
    **/
    property bool stickyHeaderVisible

    /** input property for programatic selection of network **/
    property int selectedChainId

    /** input property to decide if the header can be interacted with **/
    property bool interactive: true

    /** input property to show only ERC20 assets and no collectibles **/
    property bool displayOnlyAssets

    /** input property to blur the background of the header **/
    property var blurSource: null

    /** property exposing the currently selected token selector tab **/
    property alias tokenSelectorTab: sendModalHeader.tokenSelectorTab

    /** signal to propagate that an asset was selected **/
    signal assetSelected(string key)
    /** signal to propagate that a collection was selected **/
    signal collectionSelected(string key)
    /** signal to propagate that a collectible was selected **/
    signal collectibleSelected(string key)
    /** signal to propagate that a network was selected **/
    signal networkSelected(int chainId)

    /** input function for programatic selection of token
    (asset/collectible/collection) **/
    function setToken(name, icon, key) {
        sendModalHeader.setToken(name, icon, key)
    }

    QtObject {
        id: d
        readonly property int bottomMargin: 12
    }

    implicitHeight: root.stickyHeaderVisible ?
                        implicitContentHeight + Theme.padding + d.bottomMargin : 0

    horizontalPadding: Theme.xlPadding
    bottomPadding: d.bottomMargin
    topPadding: root.stickyHeaderVisible ? Theme.padding : -implicitContentHeight - Theme.padding

    Behavior on implicitHeight {
        NumberAnimation { duration: 350 }
    }
    Behavior on topPadding {
        NumberAnimation { duration: 350 }
    }

    background: Item {

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: radius
            anchors.rightMargin: radius
            color: foregroundRect.color
            visible: !!root.blurSource
            radius: 8

            layer.enabled: !!root.blurSource
            layer.effect: FastBlur {
                radius: 36
            }

            ShaderEffectSource {
                sourceItem: root.blurSource
                anchors.fill: parent
                anchors.leftMargin: Theme.xlPadding - parent.radius
                anchors.rightMargin: -Theme.xlPadding - parent.radius
                sourceRect: Qt.rect(0, 0, width, height)
                live: true
            }
        }

        Item {
            anchors.fill: parent
            Rectangle {
                id: foregroundRect
                anchors.fill: parent
                color: root.implicitHeight > d.bottomMargin ? StatusColors.alphaColor(Theme.palette.baseColor3, 0.85) : StatusColors.transparent
                radius: 8

                // cover for the bottom rounded corners
                Rectangle {
                    width: parent.radius
                    height: parent.radius
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    color: parent.color
                }
                // cover for the bottom rounded corners
                Rectangle {
                    width: parent.radius
                    height: parent.radius
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    color: parent.color
                }
            }

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 5
                samples: 24
                color: StatusColors.alphaColor(Theme.palette.dropShadow, 0.06)
            }
        }
    }

    contentItem: SendModalHeader {
        id: sendModalHeader

        isStickyHeader: true
        isScrolling: root.stickyHeaderVisible
        interactive: root.interactive
        displayOnlyAssets: root.displayOnlyAssets

        networksModel: root.networksModel
        assetsModel: root.assetsModel
        formatCurrencyBalance: root.formatCurrencyBalance
        collectiblesModel: root.collectiblesModel

        selectedChainId: root.selectedChainId

        onCollectibleSelected: (key) => {
                                   root.collectibleSelected(key)
                               }
        onCollectionSelected: (key) => {
                                  root.collectibleSelected(key)
                              }
        onAssetSelected: (key) => {
                             root.assetSelected(key)
                         }
        onNetworkSelected: (chainId) => {
                               root.networkSelected(chainId)
                           }
    }
}
