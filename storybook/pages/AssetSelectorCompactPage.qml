import QtQuick
import QtQuick.Controls

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
            tokensKey: "STT",

            balances: [
                {
                    balanceAsString: "0,56",
                    iconUrl: "network/ethereum"
                }
            ],

            sectionName: "My assets on Mainnet"
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
                    balanceAsString: "0,12",
                    iconUrl: "network/ethereum"
                }
            ],

            sectionName: "My assets on Mainnet"
        },
        {
            tokensKey: "key_2",
            communityId: "",
            name: "Dai Stablecoin",
            currencyBalanceAsString: "45,92 USD",
            symbol: "DAI",
            iconSource: Constants.tokenIcon("DAI"),
            tokensKey: "DAI",
            balances: [],

            sectionName: "Popular assets"
        },
        {
            tokensKey: "key_3",
            communityId: "",
            name: "0x",
            currencyBalanceAsString: "41,22 USD",
            symbol: "ZRX",
            iconSource: Constants.tokenIcon("ZRX"),
            tokensKey: "ZRX",
            balances: [],

            sectionName: "Popular assets"
        }
    ]

    ListModel {
        id: assetsModel

        Component.onCompleted: append(assetsData)
    }

    background: Rectangle {
        color: Theme.palette.baseColor3
    }

    AssetSelectorCompact {
        id: panel

        anchors.centerIn: parent
        width: 400

        model: assetsModel

        onSelected: console.log("asset selected:", key)
    }
}

// category: Controls
