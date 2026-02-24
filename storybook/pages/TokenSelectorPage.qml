import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Wallet.controls
import StatusQ.Core.Theme
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
            key: "STT",

            balances: [
                {
                    balanceAsString: "0,56",
                    iconUrl: "network/Network=Ethereum"
                },
                {
                    balanceAsString: "0,22",
                    iconUrl: "network/Network=Arbitrum"
                },
                {
                    balanceAsString: "0,12",
                    iconUrl: "network/Network=Optimism"
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
            key: "ETH",

            balances: [
                {
                    balanceAsString: "1,01",
                    iconUrl: "network/Network=Optimism"
                },
                {
                    balanceAsString: "0,47",
                    iconUrl: "network/Network=Arbitrum"
                },
                {
                    balanceAsString: "0,12",
                    iconUrl: "network/Network=Ethereum"
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
            key: "DAI",

            balances: [
                {
                    balanceAsString: "45,12",
                    iconUrl: "network/Network=Arbitrum"
                },
                {
                    balanceAsString: "0,56",
                    iconUrl: "network/Network=Optimism"
                },
                {
                    balanceAsString: "0,12",
                    iconUrl: "network/Network=Ethereum"
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
                    iconUrl: "network/Network=Ethereum"
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
                    iconUrl: "network/Network=Ethereum"
                },
                {
                    key: "collection_1_key_2",
                    name: "Magicat",
                    balance: 1,
                    icon: Constants.tokenIcon("ENJ"),
                    chainId: 11155111,
                    iconUrl: "network/Network=Ethereum"
                },
                {
                    key: "collection_1_key_3",
                    name: "Happy Meow",
                    balance: 1,
                    icon: Constants.tokenIcon("FUN"),
                    chainId: 11155111,
                    iconUrl: "network/Network=Ethereum"
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
                    iconUrl: "network/Network=Ethereum"
                },
                {
                    key: "collection_2_key_2",
                    name: "Unicorn 2",
                    balance: 1,
                    icon: Constants.tokenIcon("CVC"),
                    chainId: 11155111,
                    iconUrl: "network/Network=Ethereum"
                }
            ]
        },
        {
            groupName: "Unicorn",
            icon: Constants.tokenIcon("ELF"),
            chainId: 11155111,
            iconUrl: "network/Network=Ethereum",
            type: "other",
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

    background: Rectangle {
        color: Theme.palette.baseColor3
    }

    TokenSelector {
        id: panel

        anchors.centerIn: parent

        size: smallCheckbox.checked ? TokenSelectorButton.Size.Small :
                                      TokenSelectorButton.Size.Normal

        assetsModel: assetsModelCheckBox.checked ? assetsModel : null
        collectiblesModel: collectiblesModelCheckBox.checked ? collectiblesModel : null

        onCollectibleSelected: console.log("collectible selected:", key)
        onCollectionSelected: console.log("collection selected:", key)
        onAssetSelected: console.log("asset selected:", key)
    }

    RowLayout {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

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

        CheckBox {
            id: smallCheckbox

            text: "small"
        }
    }
}

// category: Controls
