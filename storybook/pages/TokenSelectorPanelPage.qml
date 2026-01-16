import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import AppLayouts.Wallet.panels
import utils

Pane {
    readonly property var assetsData: [
        {
            tokensKey: "key_1",
            communityId: "",
            name: "Status Test Token",
            currencyBalanceAsString: "42,23 USD",
            symbol: "STT",
            iconSource: Constants.tokenIcon("STT"),
            tokensKey: "STT",

            balances: [
                {
                    balanceAsString: "0,56",
                    iconUrl: "network/ethereum"
                },
                {
                    balanceAsString: "0,22",
                    iconUrl: "network/arbitrum"
                },
                {
                    balanceAsString: "0,12",
                    iconUrl: "network/optimism"
                }
            ]
        },
        {
            tokensKey: "key_2",
            communityId: "",
            name: "Ether",
            currencyBalanceAsString: "4 276,86 USD",
            symbol: "ETH",
            iconSource: Constants.tokenIcon("ETH"),
            tokensKey: "ETH",

            balances: [
                {
                    balanceAsString: "1,01",
                    iconUrl: "network/optimism"
                },
                {
                    balanceAsString: "0,47",
                    iconUrl: "network/arbitrum"
                },
                {
                    balanceAsString: "0,12",
                    iconUrl: "network/ethereum"
                }
            ]
        },
        {
            tokensKey: "key_2",
            communityId: "",
            name: "Dai Stablecoin",
            currencyBalanceAsString: "45,92 USD",
            symbol: "DAI",
            iconSource: Constants.tokenIcon("DAI"),
            tokensKey: "DAI",

            balances: [
                {
                    balanceAsString: "45,12",
                    iconUrl: "network/arbitrum"
                },
                {
                    balanceAsString: "0,56",
                    iconUrl: "network/optimism"
                },
                {
                    balanceAsString: "0,12",
                    iconUrl: "network/ethereum"
                }
            ]
        }
    ]

    readonly property var collectiblesData: [
        {
            groupName: "My community",
            icon: Constants.tokenIcon("BQX"),
            type: "community",
            subitems: [
                {
                    key: "my_community_key_1",
                    name: "My token",
                    balance: 1,
                    icon: Constants.tokenIcon("CFI"),
                    chainId: 11155111,
                    iconUrl: "network/ethereum"
                }
            ]
        },
        {
            groupName: "Crypto Kitties",
            icon: Constants.tokenIcon("ENJ"),
            type: "other",
            subitems: [
                {
                    key: "collection_1_key_1",
                    name: "Furbeard",
                    balance: 1,
                    icon: Constants.tokenIcon("FUEL"),
                    chainId: 11155111,
                    iconUrl: "network/ethereum"
                },
                {
                    key: "collection_1_key_2",
                    name: "Magicat",
                    balance: 1,
                    icon: Constants.tokenIcon("ENJ"),
                    chainId: 11155111,
                    iconUrl: "network/ethereum"
                },
                {
                    key: "collection_1_key_3",
                    name: "Happy Meow",
                    balance: 1,
                    icon: Constants.tokenIcon("FUN"),
                    chainId: 11155111,
                    iconUrl: "network/ethereum"
                }
            ]
        },
        {
            groupName: "Super Rare",
            icon: Constants.tokenIcon("CVC"),
            type: "other",
            subitems: [
                {
                    key: "collection_2_key_1",
                    name: "Unicorn 1",
                    balance: 12,
                    icon: Constants.tokenIcon("CVC"),
                    chainId: 11155111,
                    iconUrl: "network/ethereum"
                },
                {
                    key: "collection_2_key_2",
                    name: "Unicorn 2",
                    balance: 1,
                    icon: Constants.tokenIcon("CVC"),
                    chainId: 11155111,
                    iconUrl: "network/ethereum"
                }
            ]
        },
        {
            groupName: "Unicorn",
            icon: Constants.tokenIcon("ELF"),
            type: "other",
            chainId: 11155111,
            iconUrl: "network/ethereum",
            subitems: [
                {
                    key: "collection_3_key_1",
                    name: "Unicorn",
                    balance: 1,
                    icon: Constants.tokenIcon("ELF")
                }
            ]
        }
    ]

    ListModel {
        id: assetsModel

        Component.onCompleted: append(assetsData)
    }

    ListModel {
        id: collectiblesModel

        Component.onCompleted: append(collectiblesData)
    }

    Rectangle {
        anchors.fill: panel
        anchors.margins: -1

        color: "transparent"
        border.color: "lightgray"
    }

    TokenSelectorPanel {
        id: panel

        anchors.centerIn: parent

        width: 350

        assetsModel: assetsModelCheckBox.checked ? assetsModel : null
        collectiblesModel: collectiblesModelCheckBox.checked
                           ? collectiblesModel : null

        onCollectibleSelected: {
            highlightedKey = key
            console.log("collectible selected:", key)
        }

        onCollectionSelected: {
            highlightedKey = key
            console.log("collection selected:", key)
        }

        onAssetSelected: {
            highlightedKey = key
            console.log("asset selected:", key)
        }
    }

    RowLayout {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        Button {
            text: "Select assets tab"

            onClicked: panel.currentTab = TokenSelectorPanel.Tabs.Assets
        }

        Button {
            text: "Select collectibles tab"

            onClicked: panel.currentTab = TokenSelectorPanel.Tabs.Collectibles
        }

        CheckBox {
            id: assetsModelCheckBox

            checked: true
            text: "Assets model assigned"
        }

        CheckBox {
            id: collectiblesModelCheckBox

            checked: true
            text: "Collectibles model assigned"
        }
    }
}

// category: Controls
