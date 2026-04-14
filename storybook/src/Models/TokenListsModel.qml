import QtQuick

import Models

import utils

ListModel {
    id: root

    readonly property string uniswap: "uniswap"
    readonly property string status: "status"
    readonly property string custom: "custom"

    readonly property string ethIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2/logo.png"

    readonly property string sttToken: "STT"
    readonly property string sttName: "Status Test Token"
    readonly property int sttDecimals: 18
    readonly property string sttIcon: "https://assets.coingecko.com/coins/images/779/thumb/status.png?1548610778"

    readonly property string usdcToken: "USDC"
    readonly property string usdcName: "USDC (EVM)"
    readonly property int usdcDecimals: 6
    readonly property string usdcIcon: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png"

    readonly property var data: [
        {
            id: root.uniswap,
            name: "Uniswap Labs Default",
            source: "https://gateway.ipfs.io/ipns/tokens.uniswap.org",
            version: "11.6.0",
            logoUri: ModelsData.assets.uni,
            timestamp: 1710538948,
            fetchedTimestamp: 1710600000,
            tokens: [
                { key: "1-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 1, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "10-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 10, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "42161-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 42161, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "11155111-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 11155111, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "11155420-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 11155420, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "421614-0x0000000000000000000000000000000000000000", groupKey: Constants.ethGroupKey, crossChainId: Constants.ethGroupKey, chainId: 421614, address: "0x0000000000000000000000000000000000000000", name: "Ether", symbol: Constants.ethToken, decimals: Constants.rawDecimals[Constants.ethToken], image: ethIcon, customToken: false, communityId: ""},
                { key: "1-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 1, address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "10-0x0b2c639c533813f4aa9d7837caf62653d097ff85", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 10, address: "0x0b2c639c533813f4aa9d7837caf62653d097ff85", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "8453-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 8453, address: "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "42161-0xaf88d065e77c8cc2239327c5edb3a432268e5831", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 42161, address: "0xaf88d065e77c8cc2239327c5edb3a432268e5831", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "84532-0x036cbd53842c5426634e7929541ec2318f3dcf7e", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 84532, address: "0x036cbd53842c5426634e7929541ec2318f3dcf7e", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "421614-0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 421614, address: "0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "11155111-0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 11155111, address: "0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "11155420-0x5fd84259d66cd46123540766be93dfe6d43130d7", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 11155420, address: "0x5fd84259d66cd46123540766be93dfe6d43130d7", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "56-0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 56, address: "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""}
            ]
        },
        {
            id: root.status,
            name: "Status Token List",
            source: "https://status.im/",
            version: "11.6.0",
            logoUri: ModelsData.assets.snt,
            timestamp: 1710538948,
            fetchedTimestamp: 1710700000,
            tokens: [
                { key: "84532-0xfdb3b57944943a7724fcc0520ee2b10659969a06", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 84532, address: "0xfdb3b57944943a7724fcc0520ee2b10659969a06", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""},
                { key: "11155111-0xe452027cdef746c7cd3db31cb700428b16cd8e51", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 11155111, address: "0xe452027cdef746c7cd3db31cb700428b16cd8e51", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""},
                { key: "11155420-0x0b5dad18b8791ddb24252b433ec4f21f9e6e5ed0", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 11155420, address: "0x0b5dad18b8791ddb24252b433ec4f21f9e6e5ed0", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""},
                { key: "374-0x14c847ce7ab6c8002616176478b32C237fdF0cBb", groupKey: Constants.sttGroupKey, crossChainId: Constants.sttGroupKey, chainId: 374, address: "0x14c847ce7ab6c8002616176478b32C237fdF0cBb", name: sttName, symbol: sttToken, decimals: sttDecimals, image: sttIcon, customToken: false, communityId: ""},
                { key: "1-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 1, address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "10-0x0b2c639c533813f4aa9d7837caf62653d097ff85", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 10, address: "0x0b2c639c533813f4aa9d7837caf62653d097ff85", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "8453-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 8453, address: "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "42161-0xaf88d065e77c8cc2239327c5edb3a432268e5831", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 42161, address: "0xaf88d065e77c8cc2239327c5edb3a432268e5831", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "84532-0x036cbd53842c5426634e7929541ec2318f3dcf7e", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 84532, address: "0x036cbd53842c5426634e7929541ec2318f3dcf7e", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "421614-0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 421614, address: "0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "11155111-0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 11155111, address: "0x1c7d4b196cb0c7b01d743fbc6116a902379c7238", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "11155420-0x5fd84259d66cd46123540766be93dfe6d43130d7", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 11155420, address: "0x5fd84259d66cd46123540766be93dfe6d43130d7", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""},
                { key: "56-0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", groupKey: Constants.usdcGroupKeyEvm, crossChainId: Constants.usdcGroupKeyEvm, chainId: 56, address: "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", name: usdcName, symbol: usdcToken, decimals: usdcDecimals, image: usdcIcon, customToken: false, communityId: ""}
            ]
        }
    ]

    Component.onCompleted: append(data)
}
