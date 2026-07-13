import QtQuick
import QtQuick.Controls

import AppLayouts.Wallet.controls
import StatusQ.Core.Theme
import utils

Pane {
    readonly property var assetsData: [
        {
            key: "key_1",
            communityId: "",
            name: "Status Test Token",
            currencyBalance: 42.23,
            symbol: "STT",
            logoUri: Constants.tokenIcon("STT"),
            key: "STT",

            balances: [
                {
                    balance: 0.56,
                    iconUrl: "network/ethereum"
                }
            ],

            sectionName: "My assets on Mainnet"
        },
        {
            key: "key_2",
            communityId: "",
            name: "Ether",
            currencyBalance: 4276.86,
            symbol: "ETH",
            logoUri: Constants.tokenIcon("ETH"),
            key: "ETH",

            balances: [
                {
                    balance: 0.12,
                    iconUrl: "network/ethereum"
                }
            ],

            sectionName: "My assets on Mainnet"
        },
        {
            key: "key_2",
            communityId: "",
            name: "Dai Stablecoin",
            currencyBalance: 45.92,
            symbol: "DAI",
            logoUri: Constants.tokenIcon("DAI"),
            key: "DAI",
            balances: [],

            sectionName: "Popular assets"
        },
        {
            key: "key_3",
            communityId: "",
            name: "0x",
            currencyBalance: 41.22,
            symbol: "ZRX",
            logoUri: Constants.tokenIcon("ZRX"),
            key: "ZRX",
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
