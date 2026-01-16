import QtQuick
import QtQuick.Controls

import AppLayouts.Wallet.controls
import StatusQ.Core.Theme
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
                }
            ],

            sectionName: "My assets on Mainnet"
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
                    balanceAsString: "0,12",
                    iconUrl: "network/ethereum"
                }
            ],

            sectionName: "My assets on Mainnet"
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
        }
    ]

    ListModel {
        id: assetsModel

        Component.onCompleted: append(assetsData)
    }

    background: Rectangle {
        color: Theme.palette.baseColor3
    }

    AssetSelector {
        id: panel

        anchors.centerIn: parent

        model: assetsModel

        onSelected: console.log("asset selected:", key)
    }

    Button {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        text: "reset"

        onClicked: panel.reset()
    }
}

// category: Controls
