import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit

import utils

ListModel {

    readonly property string ethIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2/logo.png"

    readonly property string sttToken: "STT"
    readonly property string sttName: "Status Test Token"
    readonly property int sttDecimals: 18
    readonly property string sttIcon: "https://assets.coingecko.com/coins/images/779/thumb/status.png?1548610778"

    readonly property string sntToken: "SNT"
    readonly property string sntName: "Status"
    readonly property int sntDecimals: 18
    readonly property string sntIcon: "https://assets.coingecko.com/coins/images/779/thumb/status.png?1548610778"

    readonly property string daiToken: "DAI"
    readonly property string daiName: "DAI"
    readonly property int daiDecimals: 18
    readonly property string daiIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x6B175474E89094C44Da98b954EedeAC495271d0F/logo.png"

    readonly property string aaveToken: "AAVE"
    readonly property string aaveName: "Aave"
    readonly property int aaveDecimals: 18
    readonly property string aaveIcon: "https://assets.coingecko.com/coins/images/12645/thumb/AAVE.png?1601374110"

    readonly property string usdcToken: "USDC"
    readonly property string usdcName: "USDC (EVM)"
    readonly property int usdcDecimals: 6
    readonly property string usdcIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png"

    readonly property string ghstGroupKey: "aavegotchi"
    readonly property string ghstToken: "GHST"
    readonly property string ghstName: "Aavegotchi"
    readonly property int ghstDecimals: 18
    readonly property string ghstIcon: "https://assets.coingecko.com/coins/images/12467/thumb/ghst_200.png?1600750321"

    readonly property string wethGroupKey: "weth"
    readonly property string wethToken: "WETH"
    readonly property string wethName: "Wrapped Ether"
    readonly property int wethDecimals: 18
    readonly property string wethIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2/logo.png"

    readonly property string usdtToken: "USDT"
    readonly property string usdtName: "USDT (EVM)"
    readonly property int usdtDecimals: 6
    readonly property string usdtIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xdAC17F958D2ee523a2206206994597C13D831ec7/logo.png"


    readonly property var data: [
        {
            key: Constants.ethGroupKey,
            name: "Ether",
            symbol: Constants.ethToken,
            decimals: Constants.rawDecimals[Constants.ethToken],
            logoUri: ethIcon,
            tokens: [
                { key: "1-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 1, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "10-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 10, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "42161-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 42161, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "560048-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 560048, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "11155111-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 11155111, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "11155420-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 11155420, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "421614-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 421614, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "Ethereum is a decentralized, open-source blockchain platform that enables developers to build and deploy smart contracts and decentralized applications (dApps). It runs on a global network of nodes, making it highly secure and resistant to censorship. Ethereum introduced the concept of programmable money, allowing users to interact with the blockchain through self-executing contracts, also known as smart contracts. Ethereum's native currency, Ether (ETH), powers these contracts and facilitates transactions on the network.",
            websiteUrl: "https://www.ethereum.org/",
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
            detailsLoading: false,
            marketDetailsLoading: false,
        },
        {
            key: Constants.sttGroupKey,
            name: sttName,
            symbol: sttToken,
            decimals: sttDecimals,
            logoUri: sttIcon,
            tokens: [
                { key: "84532-0xfdb3b57944943a7724fcc0520ee2b10659969a06", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 84532, address: "0xfdb3b57944943a7724fcc0520ee2b10659969a06", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""},
                { key: "560048-0xe452027cdef746c7cd3db31cb700428b16cd8e51", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 560048, address: "0xe452027cdef746c7cd3db31cb700428b16cd8e51", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""},
                { key: "11155111-0xe452027cdef746c7cd3db31cb700428b16cd8e51", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 11155111, address: "0xe452027cdef746c7cd3db31cb700428b16cd8e51", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""},
                { key: "11155420-0x0b5dad18b8791ddb24252b433ec4f21f9e6e5ed0", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 11155420, address: "0x0b5dad18b8791ddb24252b433ec4f21f9e6e5ed0", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""},
                { key: "1660990954-0x1c3ac2a186c6149ae7cb4d716ebbd0766e4f898a", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 421614, address: "0x1c3ac2a186c6149ae7cb4d716ebbd0766e4f898a", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "Status Network Token (SNT) is a utility token used within the Status.im platform, which is an open-source messaging and social media platform built on the Ethereum blockchain. SNT is designed to facilitate peer-to-peer communication and interactions within the decentralized Status network.",
            websiteUrl: "https://status.im/",
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
            detailsLoading: false,
            marketDetailsLoading: false,
        },
        {
            key: Constants.sntGroupKey,
            name: sntName,
            symbol: sntToken,
            decimals: sntDecimals,
            logoUri: sntIcon,
            tokens: [
                { key: "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e", groupKey: Constants.sntGroupKey, crossChainId: Constants.sntGroupKey, chainId: 1, address: "0x744d70fdbe2ba4cf95131626614a1763df805b9e", name: sntName, symbol: sntToken, decimals: sntDecimals, image: sntIcon, customToken: false, communityId: ""},
                { key: "10-0x650af3c15af43dcb218406d30784416d64cfb6b2", groupKey: Constants.sntGroupKey, crossChainId: Constants.sntGroupKey, chainId: 10, address: "0x650af3c15af43dcb218406d30784416d64cfb6b2", name: sntName, symbol: sntToken, decimals: sntDecimals, image: sntIcon, customToken: false, communityId: ""},
                { key: "8453-0x662015ec830df08c0fc45896fab726542e8ac09e", groupKey: Constants.sntGroupKey, crossChainId: Constants.sntGroupKey, chainId: 8453, address: "0x662015ec830df08c0fc45896fab726542e8ac09e", name: sntName, symbol: sntToken, decimals: sntDecimals, image: sntIcon, customToken: false, communityId: ""},
                { key: "42161-0x707f635951193ddafbb40971a0fcaab8a6415160", groupKey: Constants.sntGroupKey, crossChainId: Constants.sntGroupKey, chainId: 42161, address: "0x707f635951193ddafbb40971a0fcaab8a6415160", name: sntName, symbol: sntToken, decimals: sntDecimals, image: sntIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "Status Network Token (SNT) is a utility token used within the Status.im platform, which is an open-source messaging and social media platform built on the Ethereum blockchain. SNT is designed to facilitate peer-to-peer communication and interactions within the decentralized Status network.",
            websiteUrl: "https://status.im/",
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
            detailsLoading: false,
            marketDetailsLoading: false,
        },
        {
            key: Constants.daiGroupKey,
            name: daiName,
            symbol: daiToken,
            decimals: daiDecimals,
            logoUri: daiIcon,
            tokens: [
                { key: "1-0x6b175474e89094c44da98b954eedeac495271d0f", groupKey: Constants.daiGroupKey, crossChainId: Constants.daiGroupKey, chainId: 1, address: "0x6b175474e89094c44da98b954eedeac495271d0f", name: daiName, symbol: daiToken, decimals: daiDecimals, image: daiIcon, customToken: false, communityId: ""},
                { key: "56-0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3", groupKey: Constants.daiGroupKey, crossChainId: Constants.daiGroupKey, chainId: 56, address: "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3", name: daiName, symbol: daiToken, decimals: daiDecimals, image: daiIcon, customToken: false, communityId: ""},
                { key: "8453-0x50c5725949a6f0c72e6c4a641f24049a917db0cb", groupKey: Constants.daiGroupKey, crossChainId: Constants.daiGroupKey, chainId: 8453, address: "0x50c5725949a6f0c72e6c4a641f24049a917db0cb", name: daiName, symbol: daiToken, decimals: daiDecimals, image: daiIcon, customToken: false, communityId: ""},
                { key: "42161-0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", groupKey: Constants.daiGroupKey, crossChainId: Constants.daiGroupKey, chainId: 42161, address: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", name: daiName, symbol: daiToken, decimals: daiDecimals, image: daiIcon, customToken: false, communityId: ""},
                { key: "560048-0x3e622317f8c93f7328350cf0b56d9ed4c620c5d6", groupKey: Constants.daiGroupKey, crossChainId: Constants.daiGroupKey, chainId: 560048, address: "0x3e622317f8c93f7328350cf0b56d9ed4c620c5d6", name: daiName, symbol: daiToken, decimals: daiDecimals, image: daiIcon, customToken: false, communityId: ""},
                { key: "11155111-0x3e622317f8c93f7328350cf0b56d9ed4c620c5d6", groupKey: Constants.daiGroupKey, crossChainId: Constants.daiGroupKey, chainId: 11155111, address: "0x3e622317f8c93f7328350cf0b56d9ed4c620c5d6", name: daiName, symbol: daiToken, decimals: daiDecimals, image: daiIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "Dai (DAI) is a decentralized, stablecoin cryptocurrency built on the Ethereum blockchain. It is designed to maintain a stable value relative to the US Dollar, and is backed by a reserve of collateral-backed tokens and other assets. Dai is an ERC-20 token, meaning it is fully compatible with other networks and wallets that support Ethereum-based tokens, making it an ideal medium of exchange and store of value.",
            websiteUrl: "https://makerdao.com/",
            marketDetails: {
                marketCap: ({amount: 3641953745.413845, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 1.000069852130498, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0.9989457077643417, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.003162399421324529,
                changePctDay: 0.0008257482387743841,
                changePct24hour: 0.04426443627508443,
                change24hour: 0.0004424433543155981,
                currencyPrice: ({amount: 0.9999000202515163, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            detailsLoading: false,
            marketDetailsLoading: false
        },
        {
            key: Constants.aaveGroupKey,
            name: aaveName,
            symbol: aaveToken,
            decimals: aaveDecimals,
            logoUri: aaveIcon,
            tokens: [
                { key: "1-0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9", groupKey: Constants.aaveGroupKey, crossChainId: Constants.aaveGroupKey, chainId: 1, address: "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9", name: aaveName, symbol: aaveToken, decimals: aaveDecimals, image: aaveIcon, customToken: false, communityId: ""},
                { key: "10-0x76fb31fb4af56892a25e32cfc43de717950c9278", groupKey: Constants.aaveGroupKey, crossChainId: Constants.aaveGroupKey, chainId: 10, address: "0x76fb31fb4af56892a25e32cfc43de717950c9278", name: aaveName, symbol: aaveToken, decimals: aaveDecimals, image: aaveIcon, customToken: false, communityId: ""},
                { key: "56-0xfb6115445bff7b52feb98650c87f44907e58f802", groupKey: Constants.aaveGroupKey, crossChainId: Constants.aaveGroupKey, chainId: 56, address: "0xfb6115445bff7b52feb98650c87f44907e58f802", name: aaveName, symbol: aaveToken, decimals: aaveDecimals, image: aaveIcon, customToken: false, communityId: ""},
                { key: "8453-0x63706e401c06ac8513145b7687a14804d17f814b", groupKey: Constants.aaveGroupKey, crossChainId: Constants.aaveGroupKey, chainId: 8453, address: "0x63706e401c06ac8513145b7687a14804d17f814b", name: aaveName, symbol: aaveToken, decimals: aaveDecimals, image: aaveIcon, customToken: false, communityId: ""},
                { key: "42161-0xba5ddd1f9d7f570dc94a51479a000e3bce967196", groupKey: Constants.aaveGroupKey, crossChainId: Constants.aaveGroupKey, chainId: 42161, address: "0xba5ddd1f9d7f570dc94a51479a000e3bce967196", name: aaveName, symbol: aaveToken, decimals: aaveDecimals, image: aaveIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "",
            websiteUrl: "",
            marketDetails: {
                marketCap: ({amount: 3641953745.413845, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 1.000069852130498, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0.9989457077643417, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.003162399421324529,
                changePctDay: 0.0008257482387743841,
                changePct24hour: 0.04426443627508443,
                change24hour: 0.0004424433543155981,
                currencyPrice: ({amount: 0.9999000202515163, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            detailsLoading: false,
            marketDetailsLoading: false
        },
        {
            key: Constants.usdcGroupKeyEvm,
            name: usdcName,
            symbol: usdcToken,
            decimals: usdcDecimals,
            logoUri: usdcIcon,
            tokens: [
                { key: "1-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 1, address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "10-0x0b2c639c533813f4aa9d7837caf62653d097ff85", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 10, address: "0x0b2c639c533813f4aa9d7837caf62653d097ff85", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "8453-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 8453, address: "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "42161-0xaf88d065e77c8cc2239327c5edb3a432268e5831", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 42161, address: "0xaf88d065e77c8cc2239327c5edb3a432268e5831", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "84532-0x036cbd53842c5426634e7929541ec2318f3dcf7e", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 84532, address: "0x036cbd53842c5426634e7929541ec2318f3dcf7e", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "421614-0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 421614, address: "0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "560048-0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 560048, address: "0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "11155111-0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 11155111, address: "0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "11155420-0x5fd84259d66cd46123540766be93dfe6d43130d7", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 11155420, address: "0x5fd84259d66cd46123540766be93dfe6d43130d7", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "1660990954-0xc445a18ca49190578dad62fba3048c07efc07ffe", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 1660990954, address: "0xc445a18ca49190578dad62fba3048c07efc07ffe", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "56-0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 56, address: "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "",
            websiteUrl: "",
            marketDetails: {
                marketCap: ({amount: 3641953745.413845, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 1.000069852130498, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0.9989457077643417, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.003162399421324529,
                changePctDay: 0.0008257482387743841,
                changePct24hour: 0.04426443627508443,
                change24hour: 0.0004424433543155981,
                currencyPrice: ({amount: 0.9999000202515163, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            detailsLoading: false,
            marketDetailsLoading: false

        },
        {
            key: ghstGroupKey,
            name: ghstName,
            symbol: ghstToken,
            decimals: ghstDecimals,
            logoUri: ghstIcon,
            tokens: [
                { key: "1-0x3f382dbd960e3a9bbceae22651e88158d2791550", groupKey: ghstGroupKey, crossChainId: ghstGroupKey, chainId: 1, address: "0x3f382dbd960e3a9bbceae22651e88158d2791550", name: ghstName, symbol: ghstToken, decimals: ghstDecimals, image: ghstIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "",
            websiteUrl: "",
            marketDetails: {
                marketCap: ({amount: 3641953745.413845, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 1.000069852130498, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0.9989457077643417, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0.003162399421324529,
                changePctDay: 0.0008257482387743841,
                changePct24hour: 0.04426443627508443,
                change24hour: 0.0004424433543155981,
                currencyPrice: ({amount: 0.9999000202515163, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            detailsLoading: false,
            marketDetailsLoading: false

        },
        {
            key: "11155420-0x6b175474e89094c44da98b954eedeac495271e0f",
            name: "0x",
            symbol: "ZRX",
            decimals: 0,
            logoUri: "",
            tokens: [
                { key: "11155420-0x6b175474e89094c44da98b954eedeac495271e0f", groupKey: "11155420-0x6b175474e89094c44da98b954eedeac495271e0f", crossChainId: "", chainId: 11155420, address: "0x6b175474e89094c44da98b954eedeac495271e0f", name: "0x", symbol: "ZRX", decimals: 0, image: "", customToken: false, communityId: "ddls"}
            ],
            communityId: "ddls",
            description: "It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout." ,
            websiteUrl: "",
            marketDetails: {
                marketCap: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                highDay: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                lowDay: ({amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false}),
                changePctHour: 0,
                changePctDay: 0,
                changePct24hour: 0,
                change24hour: 0,
                currencyPrice: ({amount: 0.07, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false})
            },
            detailsLoading: false,
            marketDetailsLoading: false
        },
        {
            key: "11155420-0x6b175474e89094c44da98b954eedeac495271p0f",
            name: "Omg",
            symbol: "OMG",
            decimals: 0,
            logoUri: "",
            tokens: [
                { key: "11155420-0x6b175474e89094c44da98b954eedeac495271p0f", groupKey: "11155420-0x6b175474e89094c44da98b954eedeac495271p0f", crossChainId: "", chainId: 11155420, address: "0x6b175474e89094c44da98b954eedeac495271p0f", name: "Omg", symbol: "OMG", decimals: 0, image: "", customToken: false, communityId: "sox"}
            ],
            communityId: "sox",
            description: "",
            websiteUrl: "",
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
            detailsLoading: false,
            marketDetailsLoading: false
        },
        {
            key: "11155420-0x6b175474e89094c44da98b954eedeac495271a0f",
            name: "Ast",
            symbol: "AST",
            decimals: 0,
            logoUri: "",
            tokens: [
                { key: "11155420-0x6b175474e89094c44da98b954eedeac495271a0f", groupKey: "11155420-0x6b175474e89094c44da98b954eedeac495271a0f", crossChainId: "", chainId: 11155420, address: "0x6b175474e89094c44da98b954eedeac495271a0f", name: "Ast", symbol: "AST", decimals: 0, image: "", customToken: false, communityId: "ast"}
            ],
            communityId: "ast",
            description: "",
            websiteUrl: "",
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
            detailsLoading: false,
            marketDetailsLoading: false
        },
        {
            key: wethGroupKey,
            name: wethName,
            symbol: wethToken,
            decimals: wethDecimals,
            logoUri: wethIcon,
            tokens: [
                { key: "1-0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", groupKey: wethGroupKey, crossChainId: wethGroupKey, chainId: 1, address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", name: wethName, symbol: wethToken, decimals: wethDecimals, image: wethIcon, customToken: false, communityId: ""},
                { key: "10-0x4200000000000000000000000000000000000006", groupKey: wethGroupKey, crossChainId: wethGroupKey, chainId: 10, address: "0x4200000000000000000000000000000000000006", name: wethName, symbol: wethToken, decimals: wethDecimals, image: wethIcon, customToken: false, communityId: ""},
                { key: "56-0x2170ed0880ac9a755fd29b2688956bd959f933f8", groupKey: wethGroupKey, crossChainId: wethGroupKey, chainId: 56, address: "0x2170ed0880ac9a755fd29b2688956bd959f933f8", name: wethName, symbol: wethToken, decimals: wethDecimals, image: wethIcon, customToken: false, communityId: ""},
                { key: "42161-0x82af49447d8a07e3bd95bd0d56f35241523fbab1", groupKey: wethGroupKey, crossChainId: wethGroupKey, chainId: 42161, address: "0x82af49447d8a07e3bd95bd0d56f35241523fbab1", name: wethName, symbol: wethToken, decimals: wethDecimals, image: wethIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "Wrapped Ethereum is a decentralized, open-source blockchain platform",
            websiteUrl: "https://www.wrapped-ethereum.org/",
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
            detailsLoading: false,
            marketDetailsLoading: false,
        },
        {
            key: Constants.usdtGroupKeyEvm,
            name: usdtName,
            symbol: usdtToken,
            decimals: usdtDecimals,
            logoUri: usdtIcon,
            tokens: [
                { key: "1-0xdac17f958d2ee523a2206206994597c13d831ec7", groupKey: Constants.usdtGroupKeyEvm, crossChainId: Constants.usdtGroupKeyEvm, chainId: 1, address: "0xdac17f958d2ee523a2206206994597c13d831ec7", name: usdtName, symbol: usdtToken, decimals: usdtDecimals, image: usdtIcon, customToken: false, communityId: ""},
                { key: "10-0x94b008aa00579c1307b0ef2c499ad98a8ce58e58", groupKey: Constants.usdtGroupKeyEvm, crossChainId: Constants.usdtGroupKeyEvm, chainId: 10, address: "0x94b008aa00579c1307b0ef2c499ad98a8ce58e58", name: usdtName, symbol: usdtToken, decimals: usdtDecimals, image: usdtIcon, customToken: false, communityId: ""},
                { key: "8453-0xfde4c96c8593536e31f229ea8f37b2ada2699bb2", groupKey: Constants.usdtGroupKeyEvm, crossChainId: Constants.usdtGroupKeyEvm, chainId: 8453, address: "0xfde4c96c8593536e31f229ea8f37b2ada2699bb2", name: usdtName, symbol: usdtToken, decimals: usdtDecimals, image: usdtIcon, customToken: false, communityId: ""},
                { key: "42161-0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", groupKey: Constants.usdtGroupKeyEvm, crossChainId: Constants.usdtGroupKeyEvm, chainId: 42161, address: "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", name: usdtName, symbol: usdtToken, decimals: usdtDecimals, image: usdtIcon, customToken: false, communityId: ""},
                { key: "56-0x55d398326f99059ff775485246999027b3197955", groupKey: Constants.usdtGroupKeyEvm, crossChainId: Constants.usdtGroupKeyEvm, chainId: 56, address: "0x55d398326f99059ff775485246999027b3197955", name: usdtName, symbol: usdtToken, decimals: usdtDecimals, image: usdtIcon, customToken: false, communityId: ""}
            ],
            communityId: "",
            description: "Tether USD is a decentralized, open-source blockchain platform",
            websiteUrl: "https://www.tether-usdt.org/",
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
            detailsLoading: false,
            marketDetailsLoading: false,
        },
    ]

    property bool skipInitialLoad: false

    Component.onCompleted: {
        if (!skipInitialLoad) {
            append(data)
        }
    }

    property bool hasMoreItems: false
    property bool isLoadingMore: false

    property var tokenGroupsForChainModel // used for search only

    function search(keyword) {
        clear() // clear the existing model

        if (!keyword || keyword.trim() === "") {
            return
        }

        if (!tokenGroupsForChainModel) {
            console.warn("search: tokenGroupsForChainModel is not set")
            return
        }

        const lowerKeyword = keyword.toLowerCase()
        for (let i = 0; i < tokenGroupsForChainModel.ModelCount.count; i++) {
            const item = ModelUtils.get(tokenGroupsForChainModel, i)
            const symbolMatch = item.symbol && item.symbol.toLowerCase().includes(lowerKeyword)
            const nameMatch = item.name && item.name.toLowerCase().includes(lowerKeyword)
            if (symbolMatch || nameMatch) {
                append(item)
            }
        }
    }

    function fetchMore() {
    }
}
