import QtQuick
import QtQuick.Controls

import AppLayouts.Wallet.controls
import StatusQ.Core.Theme
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
                }
            ],

            sectionName: "My assets on Mainnet"
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
                    balance: 0.12,
                    iconUrl: "network/ethereum"
                }
            ],

            sectionName: "My assets on Mainnet"
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
