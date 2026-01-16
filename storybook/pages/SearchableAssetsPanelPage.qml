import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import AppLayouts.Wallet.panels
import utils

Pane {
    readonly property var assetsData: [
        {
            tokensKey: "stt_key",
            communityId: "",
            name: "Status Test Token",
            currencyBalanceAsString: "42,23 USD",
            symbol: "STT",
            iconSource: Constants.tokenIcon("STT"),
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
            ],

            sectionName: ""
        },
        {
            tokensKey: "eth_key",
            communityId: "",
            name: "Ether",
            currencyBalanceAsString: "4 276,86 USD",
            symbol: "ETH",
            iconSource: Constants.tokenIcon("ETH"),
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
            ],

            sectionName: ""
        },
        {
            tokensKey: "dai_key",
            communityId: "",
            name: "Dai Stablecoin",
            currencyBalanceAsString: "45,92 USD",
            symbol: "DAI",
            iconSource: Constants.tokenIcon("DAI"),
            balances: [],

            sectionName: "Popular assets"
        },
        {
            tokensKey: "zrx_key",
            communityId: "",
            name: "0x",
            currencyBalanceAsString: "41,22 USD",
            symbol: "ZRX",
            iconSource: Constants.tokenIcon("ZRX"),
            balances: [],

            sectionName: "Popular assets"
        },
        {
            tokensKey: "abc_key",
            communityId: "",
            name: "0x",
            currencyBalanceAsString: "41,22 USD",
            symbol: "ABC",
            iconSource: Constants.tokenIcon("ABC"),
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
