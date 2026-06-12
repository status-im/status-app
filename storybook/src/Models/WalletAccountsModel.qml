import QtQuick

import utils

ListModel {

    readonly property string accountAddress1: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
    readonly property string accountAddress2: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881"
    readonly property string accountAddress3: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882"
    readonly property string accountAddress4: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8883"
    readonly property string accountAddress5: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884"

    readonly property var data: [
        {
            name: "helloworld",
            emoji: "😋",
            colorId: Constants.walletAccountColors.primary,
            color: "#2A4AF5",
            address: accountAddress1,
            mixedcaseAddress: accountAddress1,
            walletType: "",
            canSend: true,
            position: 0,
            assets: [
                {
                    symbol: "socks",
                    enabledNetworkBalance: {
                        displayDecimals: 2,
                        stripTrailingZeroes: true,
                        amount: 15.0,
                        symbol: "SOX"
                    }
                },
                {
                    symbol: "snt",
                    enabledNetworkBalance: {
                        displayDecimals: 2,
                        stripTrailingZeroes: true,
                        amount: 670.2345,
                        symbol: "SNT"
                    }
                },
                {
                    symbol: "zrx",
                    enabledNetworkBalance: {
                        displayDecimals: 4,
                        stripTrailingZeroes: true,
                        amount: 7.456000,
                        symbol: "ZRX"
                    }
                }
            ],
            currencyBalance: ({amount: 1.25,
                                  symbol: "USD",
                                  displayDecimals: 2,
                                  stripTrailingZeroes: false}),
            migratedToColdWallet: true
        },
        {
            name: "Hot wallet (generated)",
            emoji: "☀️",
            colorId: Constants.walletAccountColors.army,
            color: "#216266",
            address: accountAddress2,
            mixedcaseAddress: accountAddress2,
            walletType: Constants.generatedWalletType,
            canSend: true,
            position: 3,
            assets: [
                {
                    symbol: "deadbeef",
                    enabledNetworkBalance: {
                        displayDecimals: 1,
                        stripTrailingZeroes: true,
                        amount: 1,
                        symbol: "DBF"
                    }
                }
            ],
            currencyBalance: ({amount: 10,
                                  symbol: "USD",
                                  displayDecimals: 2,
                                  stripTrailingZeroes: false}),
            migratedToColdWallet: false
        },
        {
            name: "Family (seed)",
            emoji: "🎨",
            colorId: Constants.walletAccountColors.magenta,
            color: "#EC266C",
            address: accountAddress3,
            mixedcaseAddress: accountAddress3,
            walletType: Constants.seedWalletType,
            canSend: true,
            position: 1,
            assets: [
                {
                    symbol: "Aave",
                    enabledNetworkBalance: {
                        displayDecimals: 6,
                        stripTrailingZeroes: true,
                        amount: 42,
                        symbol: "AAVE"
                    }
                },
                {
                    symbol: "dai",
                    enabledNetworkBalance: {
                        displayDecimals: 2,
                        stripTrailingZeroes: true,
                        amount: 120.123,
                        symbol: "DAI"
                    }
                }
            ],
            currencyBalance: ({amount: 110.05,
                                  symbol: "USD",
                                  displayDecimals: 2,
                                  stripTrailingZeroes: false}),
            migratedToColdWallet: false
        },
        {
            name: "Tag Heuer (watch)",
            emoji: "⌚",
            colorId: Constants.walletAccountColors.copper,
            color: "#CB6256",
            address: accountAddress4,
            mixedcaseAddress: accountAddress4,
            walletType: Constants.watchWalletType,
            canSend: false,
            position: 2,
            assets: [
            ],
            currencyBalance: ({amount: 3,
                                  symbol: "USD",
                                  displayDecimals: 2,
                                  stripTrailingZeroes: false}),
            migratedToColdWallet: false
        },
        {
            name: "Fab (key)",
            emoji: "🔑",
            colorId: Constants.walletAccountColors.camel,
            color: "#C78F67",
            address: accountAddress5,
            mixedcaseAddress: accountAddress5,
            walletType: Constants.keyWalletType,
            canSend: true,
            position: 4,
            assets: [
                {
                    symbol: "socks",
                    enabledNetworkBalance: {
                        displayDecimals: 2,
                        stripTrailingZeroes: false,
                        amount: 3.5,
                        symbol: "SOX"
                    }
                }
            ],
            currencyBalance: ({amount: 999,
                                  symbol: "USD",
                                  displayDecimals: 2,
                                  stripTrailingZeroes: false}),
            migratedToColdWallet: false
        }
    ]

    Component.onCompleted: append(data)
}
