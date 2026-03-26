import QtQuick

import utils

ListModel {
    readonly property string ethIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2/logo.png"
    readonly property string sttIcon: "https://assets.coingecko.com/coins/images/779/thumb/status.png?1548610778"
    readonly property string daiIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x6B175474E89094C44Da98b954EedeAC495271d0F/logo.png"
    readonly property string aaveIcon: "https://assets.coingecko.com/coins/images/12645/thumb/AAVE.png?1601374110"
    readonly property string usdcIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png"

    readonly property var data: [
        {
            key: Constants.daiGroupKey,
            name: "DAI",
            symbol: "DAI",
            decimals: 18,
            logoUri: daiIcon,
            communityId: "",
            marketDetails: {
                marketCap: ({amount: 3641953745.413845, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 1.000069852130498, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0.9989457077643417, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.07309458752001088,
                changePctDay: 0.010631936782811216,
                changePct24hour: 0.04426443627508443,
                change24hour: 0.0004424433543155981,
                currencyPrice: ({amount: 0.9999000202515163, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.daiGroupKey, tokenKey: "1-0x6b175474e89094c44da98b954eedeac495271d0f", chainId: 1, tokenAddress: "0x6b175474e89094c44da98b954eedeac495271d0f", balance: "0" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.daiGroupKey, tokenKey: "10-0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", chainId: 10, tokenAddress: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", balance: "987654321000000000" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.daiGroupKey, tokenKey: "42161-0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", chainId: 42161, tokenAddress: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", balance: "0" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.daiGroupKey, tokenKey: "11155111-0x3e622317f8c93f7328350cf0b56d9ed4c620c5d6", chainId: 11155111, tokenAddress: "0x3e622317f8c93f7328350cf0b56d9ed4c620c5d6", balance: "0" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.daiGroupKey, tokenKey: "1-0x6b175474e89094c44da98b954eedeac495271d0f", chainId: 1, tokenAddress: "0x6b175474e89094c44da98b954eedeac495271d0f", balance: "0" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.daiGroupKey, tokenKey: "10-0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", chainId: 10, tokenAddress: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", balance: "123456789123456789" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.daiGroupKey, tokenKey: "11155111-0x3e622317f8c93f7328350cf0b56d9ed4c620c5d6", chainId: 11155111, tokenAddress: "0x3e622317f8c93f7328350cf0b56d9ed4c620c5d6", balance: "123456789123456789" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.daiGroupKey, tokenKey: "42161-0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", chainId: 42161, tokenAddress: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", balance: "45123456789123456789" },
            ]
        },
        {
            key: Constants.ethGroupKey,
            name: "Ether",
            symbol: "ETH",
            decimals: 18,
            logoUri: ethIcon,
            communityId: "",
            marketDetails: {
                marketCap: ({amount: 250980621528.3937, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 2090.658790484828, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 2059.795033958552, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.3655439934313061,
                changePctDay: 1.19243897022671,
                changePct24hour: 0.05209315257442912,
                change24hour: 0.9121310349524345,
                currencyPrice: ({amount: 2098.790000016801, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.ethGroupKey, tokenKey: "1-0x0000000000000000000000000000000000000000", chainId: 1, tokenAddress: "0x0000000000000000000000000000000000000000", balance: "122082928968121891" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.ethGroupKey, tokenKey: "11155420-0x0000000000000000000000000000000000000000", chainId: 11155420, tokenAddress: "0x0000000000000000000000000000000000000000", balance: "1013151281976507736" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.ethGroupKey, tokenKey: "421614-0x0000000000000000000000000000000000000000", chainId: 421614, tokenAddress: "0x0000000000000000000000000000000000000000", balance: "473057568699284613" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.ethGroupKey, tokenKey: "560048-0x0000000000000000000000000000000000000000", chainId: 560048, tokenAddress: "0x0000000000000000000000000000000000000000", balance: "307400931315122839" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.ethGroupKey, tokenKey: "11155111-0x0000000000000000000000000000000000000000", chainId: 11155111, tokenAddress: "0x0000000000000000000000000000000000000000", balance: "307400931315122839" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.ethGroupKey, tokenKey: "11155420-0x0000000000000000000000000000000000000000", chainId: 11155420, tokenAddress: "0x0000000000000000000000000000000000000000", balance: "122082928968121891" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.ethGroupKey, tokenKey: "421614-0x0000000000000000000000000000000000000000", chainId: 421614, tokenAddress: "0x0000000000000000000000000000000000000000", balance: "0" },
            ]
        },
        {
            key: Constants.sttGroupKey,
            name: "Status Test Token",
            symbol: "STT",
            decimals: 18,
            logoUri: sttIcon,
            communityId: "",
            marketDetails: {
                marketCap: ({amount: 289140007.5701632, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 0.04361387720794776, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0.0405415571067135, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.7372177058415699,
                changePctDay: 4.094492504074038,
                changePct24hour: 5.038796965532456,
                change24hour: 0.002038287801810013,
                currencyPrice: ({amount: 0.04258000295521924, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.sttGroupKey, tokenKey: "560048-0xe452027cdef746c7cd3db31cb700428b16cd8e51", chainId: 560048, tokenAddress: "0xe452027cdef746c7cd3db31cb700428b16cd8e51", balance: "45123456789123456789" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.sttGroupKey, tokenKey: "11155111-0xe452027cdef746c7cd3db31cb700428b16cd8e51", chainId: 11155111, tokenAddress: "0xe452027cdef746c7cd3db31cb700428b16cd8e51", balance: "45123456789123456789" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.sttGroupKey, tokenKey: "11155420-0x0b5dad18b8791ddb24252b433ec4f21f9e6e5ed0", chainId: 11155420, tokenAddress: "0x0b5dad18b8791ddb24252b433ec4f21f9e6e5ed0", balance: "999999999998998500000000000016777216" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.sttGroupKey, tokenKey: "84532-0xfdb3b57944943a7724fcc0520ee2b10659969a06", chainId: 84532, tokenAddress: "0xfdb3b57944943a7724fcc0520ee2b10659969a06", balance: "1077000000000000000000" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.sttGroupKey, tokenKey: "11155420-0x0b5dad18b8791ddb24252b433ec4f21f9e6e5ed0", chainId: 11155420, tokenAddress: "0x0b5dad18b8791ddb24252b433ec4f21f9e6e5ed0", balance: "122082928968121891" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.sttGroupKey, tokenKey: "84532-0xfdb3b57944943a7724fcc0520ee2b10659969a06", chainId: 84532, tokenAddress: "0xfdb3b57944943a7724fcc0520ee2b10659969a06", balance: "222000000000000000" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.sttGroupKey, tokenKey: "560048-0xe452027cdef746c7cd3db31cb700428b16cd8e51", chainId: 560048, tokenAddress: "0xe452027cdef746c7cd3db31cb700428b16cd8e51", balance: "559133758939097000" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.sttGroupKey, tokenKey: "11155111-0xe452027cdef746c7cd3db31cb700428b16cd8e51", chainId: 11155111, tokenAddress: "0xe452027cdef746c7cd3db31cb700428b16cd8e51", balance: "559133758939097000" }
            ]
        },
        {
            key: Constants.usdcGroupKeyEvm,
            name: "USDC (EVM)",
            symbol: "USDC",
            decimals: 6,
            logoUri: usdcIcon,
            communityId: "",
            marketDetails: {
                marketCap: ({amount: 3641953745.413845, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 1.000069852130498, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0.9989457077643417, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.07309458752001088,
                changePctDay: 0.010631936782811216,
                changePct24hour: 0.04426443627508443,
                change24hour: 0.0004424433543155981,
                currencyPrice: ({amount: 0.9999000202515163, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.usdcGroupKeyEvm, tokenKey: "1-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", chainId: 1, tokenAddress: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", balance: "45123456789123456789" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.usdcGroupKeyEvm, tokenKey: "11155420-0x5fd84259d66cd46123540766be93dfe6d43130d7", chainId: 11155420, tokenAddress: "0x5fd84259d66cd46123540766be93dfe6d43130d7", balance: "999999999998998500000000000016777216" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.usdcGroupKeyEvm, tokenKey: "10-0x0b2c639c533813f4aa9d7837caf62653d097ff85", chainId: 10, tokenAddress: "0x0b2c639c533813f4aa9d7837caf62653d097ff85", balance: "1077000000000000000000" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.usdcGroupKeyEvm, tokenKey: "11155420-0x5fd84259d66cd46123540766be93dfe6d43130d7", chainId: 11155420, tokenAddress: "0x5fd84259d66cd46123540766be93dfe6d43130d7", balance: "122082928968121891" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.usdcGroupKeyEvm, tokenKey: "421614-0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d", chainId: 421614, tokenAddress: "0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d", balance: "222000000000000000" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.usdcGroupKeyEvm, tokenKey: "11155111-0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", chainId: 11155111, tokenAddress: "0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", balance: "559133758939097000" }
            ]
        },
        {
            key: Constants.aaveGroupKey,
            name: "Aave",
            symbol: "AAVE",
            decimals: 18,
            logoUri: aaveIcon,
            communityId: "",
            marketDetails: {
                marketCap: ({amount: 3641953745.413845, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 1.000069852130498, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0.9989457077643417, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.07309458752001088,
                changePctDay: 0.010631936782811216,
                changePct24hour: 0.04426443627508443,
                change24hour: 0.0004424433543155981,
                currencyPrice: ({amount: 0.9999000202515163, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.aaveGroupKey, tokenKey: "10-0x76fb31fb4af56892a25e32cfc43de717950c9278", chainId: 10, tokenAddress: "0x76fb31fb4af56892a25e32cfc43de717950c9278", balance: "559133758939097000" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.aaveGroupKey, tokenKey: "42161-0xba5ddd1f9d7f570dc94a51479a000e3bce967196", chainId: 42161, tokenAddress: "0xba5ddd1f9d7f570dc94a51479a000e3bce967196", balance: "0" },
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: Constants.aaveGroupKey, tokenKey: "1-0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9", chainId: 1, tokenAddress: "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9", balance: "123456789123456789" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.aaveGroupKey, tokenKey: "10-0x76fb31fb4af56892a25e32cfc43de717950c9278", chainId: 10, tokenAddress: "0x76fb31fb4af56892a25e32cfc43de717950c9278", balance: "123456789123456789" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.aaveGroupKey, tokenKey: "1-0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9", chainId: 1, tokenAddress: "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9", balance: "123456789123456789" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: Constants.aaveGroupKey, tokenKey: "42161-0xba5ddd1f9d7f570dc94a51479a000e3bce967196", chainId: 42161, tokenAddress: "0xba5ddd1f9d7f570dc94a51479a000e3bce967196", balance: "45123456789123456789" },
            ]
        },
        {
            key: "11155420-0x6b175474e89094c44da98b954eedeac495271e0f",
            name: "Custom Token 1",
            symbol: "CT1",
            decimals: 18,
            logoUri: "",
            communityId: "",
            marketDetails: {
                marketCap: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0,
                changePctDay: 0,
                changePct24hour: 0,
                change24hour: 0,
                currencyPrice: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: "11155420-0x6b175474e89094c44da98b954eedeac495271e0f", tokenKey: "11155420-0x6b175474e89094c44da98b954eedeac495271e0f", chainId: 11155420, tokenAddress: "0x6b175474e89094c44da98b954eedeac495271e0f", balance: "100" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: "11155420-0x6b175474e89094c44da98b954eedeac495271e0f", tokenKey: "11155420-0x6b175474e89094c44da98b954eedeac495271e0f", chainId: 11155420, tokenAddress: "0x6b175474e89094c44da98b954eedeac495271e0f", balance: "1" }
            ]
        },
        {
            key: "11155420-0x6b175474e89094c44da98b954eedeac495271p0f",
            name: "Custom Token 2",
            symbol: "CT2",
            decimals: 18,
            logoUri: "",
            communityId: "",
            marketDetails: {
                marketCap: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0,
                changePctDay: 0,
                changePct24hour: 0,
                change24hour: 0,
                currencyPrice: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: "11155420-0x6b175474e89094c44da98b954eedeac495271p0f", tokenKey: "11155420-0x6b175474e89094c44da98b954eedeac495271p0f", chainId: 11155420, tokenAddress: "0x6b175474e89094c44da98b954eedeac495271p0f", balance: "20" },
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: "11155420-0x6b175474e89094c44da98b954eedeac495271p0f", tokenKey: "11155420-0x6b175474e89094c44da98b954eedeac495271p0f", chainId: 11155420, tokenAddress: "0x6b175474e89094c44da98b954eedeac495271p0f", balance: "10" }
            ]
        },
        {
            key: "11155420-0x6b175474e89094c44da98b954eedeac495271a0f",
            name: "Custom Token 3",
            symbol: "CT3",
            decimals: 18,
            logoUri: "",
            communityId: "",
            marketDetails: {
                marketCap: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0,
                changePctDay: 0,
                changePct24hour: 0,
                change24hour: 0,
                currencyPrice: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", groupKey: "11155420-0x6b175474e89094c44da98b954eedeac495271a0f", tokenKey: "11155420-0x6b175474e89094c44da98b954eedeac495271a0f", chainId: 11155420, tokenAddress: "0x6b175474e89094c44da98b954eedeac495271a0f", balance: "1" }
            ]
        },
        {
            key: "ddls-community-token",
            name: "Doodles Collectible",
            symbol: "DDL",
            decimals: 18,
            logoUri: sttIcon,
            communityId: "ddls",
            marketDetails: {
                marketCap: ({amount: 1000000, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 2, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 1.5, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.5,
                changePctDay: 1.2,
                changePct24hour: 2.4,
                change24hour: 0.02,
                currencyPrice: ({amount: 1.8, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            balances: [
                { account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", groupKey: "ddls-community-token", tokenKey: "11155420-ddls-token", chainId: 11155420, tokenAddress: "0x00000000000000000000000000000000000000dd", balance: "2500000000000000000" }
            ]
        }
    ]

    Component.onCompleted: append(data)
}
