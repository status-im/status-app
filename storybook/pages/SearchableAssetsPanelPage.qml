import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import AppLayouts.Wallet.panels
import utils

Pane {
    readonly property var assetsData: [
        {
            key: "stt_key",
            communityId: "",
            name: "Status Test Token",
            currencyBalance: 42.23,
            symbol: "STT",
            logoUri: Constants.tokenIcon("STT"),
            balances: [
                {
                    balance: 0.56,
                    iconUrl: "network/ethereum"
                },
                {
                    balance: 0.22,
                    iconUrl: "network/arbitrum"
                },
                {
                    balance: 0.12,
                    iconUrl: "network/optimism"
                }
            ],

            sectionName: ""
        },
        {
            key: "eth_key",
            communityId: "",
            name: "Ether",
            currencyBalance: 4276.86,
            symbol: "ETH",
            logoUri: Constants.tokenIcon("ETH"),
            balances: [
                {
                    balance: 1.01,
                    iconUrl: "network/optimism"
                },
                {
                    balance: 0.47,
                    iconUrl: "network/arbitrum"
                },
                {
                    balance: 0.12,
                    iconUrl: "network/ethereum"
                }
            ],

            sectionName: ""
        },
        {
            key: "dai_key",
            communityId: "",
            name: "Dai Stablecoin",
            currencyBalance: 45.92,
            symbol: "DAI",
            logoUri: Constants.tokenIcon("DAI"),
            balances: [],

            sectionName: "Popular assets"
        },
        {
            key: "zrx_key",
            communityId: "",
            name: "0x",
            currencyBalance: 41.22,
            symbol: "ZRX",
            logoUri: Constants.tokenIcon("ZRX"),
            balances: [],

            sectionName: "Popular assets"
        },
        {
            key: "abc_key",
            communityId: "",
            name: "0x",
            currencyBalance: 41.22,
            symbol: "ABC",
            logoUri: Constants.tokenIcon("ABC"),
            balances: [],

            sectionName: "Popular assets"
        }
    ]

    ListModel {
        id: assetsModel

        Component.onCompleted: append(assetsData)
    }

    Rectangle {
        anchors.fill: panel
        anchors.margins: -1

        color: "transparent"
        border.color: "lightgray"
    }

    SearchableAssetsPanel {
        id: panel

        anchors.centerIn: parent

        width: 450
        highlightedKey: "key_2"

        model: assetsModel

        onSelected: console.log("selected:", key)
    }
}

// category: Panels
