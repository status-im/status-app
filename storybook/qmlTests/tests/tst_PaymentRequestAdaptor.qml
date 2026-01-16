import QtQuick
import QtTest
import QtQml

import AppLayouts.Wallet.adaptors

import StatusQ
import StatusQ.Core.Utils

import utils

import QtModelsToolkit

Item {
    id: root

    Component {
        id: testComponent

        PaymentRequestAdaptor {
            selectedNetworkChainId: 1
            flatNetworksModel: ListModel {
                Component.onCompleted: append([
                    {
                        chainId: 1,
                        chainName: "Mainnet",
                        blockExplorerURL: "https://etherscan.io/",
                        iconUrl: "network/ethereum",
                        chainColor: "#627EEA",
                        shortName: "eth",
                        nativeCurrencyName: "Ether",
                        nativeCurrencySymbol: "ETH",
                        nativeCurrencyDecimals: 18,
                        isTest: false,
                        layer: 1,
                        isRouteEnabled: true,
                        isEnabled: true,
                        isActive: true,
                        isDeactivatable: false,
                    },
                    {
                        chainId: 10,
                        chainName: "Optimism",
                        blockExplorerURL: "https://optimistic.etherscan.io",
                        iconUrl: "network/optimism",
                        chainColor: "#E90101",
                        shortName: "oeth",
                        nativeCurrencyName: "Ether",
                        nativeCurrencySymbol: "ETH",
                        nativeCurrencyDecimals: 18,
                        isTest:  false,
                        layer:   2,
                        isRouteEnabled: true,
                        isEnabled: true,
                        isActive: false,
                        isDeactivatable: true,
                    },
                    {
                        chainId: 11155420,
                        chainName: "Optimism Sepolia",
                        blockExplorerURL: "https://sepolia-optimism.etherscan.io/",
                        iconUrl: "network/optimism-test",
                        chainColor: "#939BA1",
                        shortName: "oeth",
                        nativeCurrencyName: "Ether",
                        nativeCurrencySymbol: "ETH",
                        nativeCurrencyDecimals: 18,
                        isTest:  true,
                        layer:   2,
                        isRouteEnabled: true,
                        isEnabled: true,
                        isActive: true,
                        isDeactivatable: true,
                    },
                    {
                        chainId: 42161,
                        chainName: "Arbitrum",
                        blockExplorerURL: "https://arbiscan.io/",
                        iconUrl: "network/arbitrum",
                        chainColor: "#51D0F0",
                        shortName: "arb1",
                        nativeCurrencyName: "Ether",
                        nativeCurrencySymbol: "ETH",
                        nativeCurrencyDecimals: 18,
                        isTest:  false,
                        layer:   2,
                        isRouteEnabled: true,
                        isEnabled: false,
                        isActive: true,
                        isDeactivatable: true,
                    },
                    {
                        chainId: 421614,
                        chainName: "Arbitrum Sepolia",
                        blockExplorerURL: "https://sepolia.arbiscan.io/",
                        iconUrl: "network/arbitrum-test",
                        chainColor: "#939BA1",
                        shortName: "arb1",
                        nativeCurrencyName: "Ether",
                        nativeCurrencySymbol: "ETH",
                        nativeCurrencyDecimals: 18,
                        isTest:  true,
                        layer:   2,
                        isRouteEnabled: true,
                        isEnabled: false,
                        isActive: true,
                        isDeactivatable: true,
                    },
                ])
            }
            tokenGroupsForChainModel: ListModel {
                Component.onCompleted: append([{
                    key: Constants.ethGroupKey,
                    name: "Ether",
                    symbol: "ETH",
                    decimals: 18,
                    communityId: "",
                    description: "Ethereum is a decentralized, open-source blockchain platform that enables developers to build and deploy smart contracts and decentralized applications (dApps). It runs on a global network of nodes, making it highly secure and resistant to censorship. Ethereum introduced the concept of programmable money, allowing users to interact with the blockchain through self-executing contracts, also known as smart contracts. Ethereum's native currency, Ether (ETH), powers these contracts and facilitates transactions on the network.",
                    websiteUrl: "https://www.ethereum.org/",
                    tokens: [
                        { chainId: 1, address: "0x0000000000000000000000000000000000000000"},
                        { chainId: 10, address: "0x0000000000000000000000000000000000000000"},
                    ]
                },
                {
                    key: Constants.sntGroupKey,
                    name: "Status",
                    symbol: "SNT",
                    decimals: 18,
                    communityId: "",
                    description: "Status Network Token (SNT) is a utility token used within the Status.im platform, which is an open-source messaging and social media platform built on the Ethereum blockchain. SNT is designed to facilitate peer-to-peer communication and interactions within the decentralized Status network.",
                    websiteUrl: "https://status.im/",
                    tokens: [
                        {chainId: 1, address: "0x744d70fdbe2ba4cf95131626614a1763df805b9e"},
                        {chainId: 10, address: "0x650af3c15af43dcb218406d30784416d64cfb6b2"}
                    ]
                },
                {
                    key: Constants.daiGroupKey,
                    name: "Dai Stablecoin",
                    symbol: "DAI",
                    decimals: 18,
                    communityId: "",
                    description: "Dai (DAI) is a decentralized, stablecoin cryptocurrency built on the Ethereum blockchain. It is designed to maintain a stable value relative to the US Dollar, and is backed by a reserve of collateral-backed tokens and other assets. Dai is an ERC-20 token, meaning it is fully compatible with other networks and wallets that support Ethereum-based tokens, making it an ideal medium of exchange and store of value.",
                    websiteUrl: "https://makerdao.com/",
                    tokens: [
                        { chainId: 1, address: "0x6b175474e89094c44da98b954eedeac495271d0f"},
                        { chainId: 42161, address: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1"},
                    ]
                },
                {
                    key: "1-0x0000000000000000000000000000000000000001",
                    name: "Meth",
                    symbol: "MET",
                    decimals: 0,
                    communityId: "ddls",
                    description: "It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. ",
                    websiteUrl: "",
                    tokens: [
                       { chainId: 1, address: "0x0000000000000000000000000000000000000001"}
                    ]
                },
                ])
            }
        }
    }

    TestCase {
        name: "PaymentRequestAdaptor"

        function test_model_contents() {
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)

            // Community and not selected network are filtered out
            compare(adaptor.outputModel.ModelCount.count, 3)
            compare(adaptor.outputModel.get(0).key, Constants.daiGroupKey)
            compare(adaptor.outputModel.get(1).key, Constants.ethGroupKey)
            compare(adaptor.outputModel.get(2).key, Constants.sntGroupKey)

            adaptor.selectedNetworkChainId = 999
            compare(adaptor.outputModel.ModelCount.count, 0)

            adaptor.selectedNetworkChainId = 42161
            compare(adaptor.outputModel.ModelCount.count, 1)
            compare(adaptor.outputModel.get(0).key, Constants.daiGroupKey)

            adaptor.selectedNetworkChainId = 10
            compare(adaptor.outputModel.ModelCount.count, 2)
            compare(adaptor.outputModel.get(0).key, Constants.ethGroupKey)
            compare(adaptor.outputModel.get(1).key, Constants.sntGroupKey)
        }
    }
}
