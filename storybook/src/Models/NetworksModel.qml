pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property int ethNet: 1
    readonly property int optimismNet: 10
    readonly property int arbitrumNet: 42161
    readonly property int baseNet: 8453
    readonly property int hermezNet: 4
    readonly property int testnetNet: 5
    readonly property int customNet: 6

    readonly property int mainnetChainId: 1
    readonly property int hoodiChainId: 560048
    readonly property int sepMainnetChainId: 11155111
    readonly property int optChainId: 10
    readonly property int sepOptChainId: 11155420
    readonly property int arbChainId: 42161
    readonly property int sepArbChainId: 421614
    readonly property int baseChainId: 8453
    readonly property int sepBaseChainId: 84532
    readonly property int binanceSmartChainMainnetChainId: 56
    readonly property int binanceSmartChainTestnetChainId: 97


    function getShortChainName(chainId) {
        if(chainId === root.ethNet)
            return "eth"

        if(chainId === root.optimismNet)
            return "oeth"

        if(chainId === root.baseNet)
            return "base"

        if(chainId === root.arbitrumNet)
            return "arb1"

        if(chainId === root.hermezNet)
            return "her"

        if(chainId === root.testnetNet)
            return "goe"

        if(chainId === root.customNet)
            return "cus"
    }

    function getChainName(chainId) {
        if(chainId === root.ethNet)
            return "Mainnet"

        if(chainId === root.optimismNet)
            return "Optimism"

        if(chainId === root.arbitrumNet)
            return "Arbitrum"

        if(chainId === root.baseNet)
            return "Base"

        if(chainId === root.hermezNet)
            return "Hermez"

        if(chainId === root.testnetNet)
            return "Sepolia"

        if(chainId === root.customNet)
            return "Custom"
    }

    readonly property var mainnetRpcProviders: ListModel {
        Component.onCompleted: append([
                    {
                        name: "Embedded Mainnet #1",
                        url: "https://mainnet.infura.io/v3/",
                        isEnabled: true,
                        providerType: "embedded-proxy",
                        authType: "none",
                        authLogin: "",
                        authPassword: "",
                        authToken: ""
                    },
                    {
                        name: "Embedded Mainnet #2",
                        url: "https://mainnet.alchemy.io/v3/",
                        isEnabled: true,
                        providerType: "embedded-direct",
                        authType: "none",
                        authLogin: "",
                        authPassword: "",
                        authToken: ""
                    },
                    {
                        name: "User Mainnet #1",
                        url: "https://mainnet.mynode.io/1/",
                        isEnabled: true,
                        providerType: "user",
                        authType: "none",
                        authLogin: "",
                        authPassword: "",
                        authToken: ""
                    },
                    {
                        name: "User Mainnet #2",
                        url: "https://mainnet.mynode.io/2/",
                        isEnabled: false,
                        providerType: "user",
                        authType: "none",
                        authLogin: "",
                        authPassword: "",
                        authToken: ""
                    }
                ])
    }

    readonly property var hoodiRpcProviders: ListModel {
        Component.onCompleted: append([
                {
                    name: "Embedded Hoodi #1",
                    url: "https://hoodi.infura.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-proxy",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "Embedded Hoodi #2",
                    url: "https://hoodi.alchemy.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-direct",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                }
            ])
    }

    readonly property var sepMainnetRpcProviders: ListModel {
        Component.onCompleted: append([
                {
                    name: "Embedded Sepolia #1",
                    url: "https://sepolia.infura.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-proxy",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "Embedded Sepolia #2",
                    url: "https://sepolia.alchemy.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-direct",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Sepolia #1",
                    url: "https://sepolia.mynode.io/1/",
                    isEnabled: true,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Sepolia #2",
                    url: "https://sepolia.mynode.io/2/",
                    isEnabled: false,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                }
            ])
    }

    readonly property var optimismRpcProviders: ListModel {
        Component.onCompleted: append([
                {
                    name: "Embedded Optimism #1",
                    url: "https://optimism.infura.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-proxy",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "Embedded Optimism #2",
                    url: "https://optimism.alchemy.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-direct",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Optimism #1",
                    url: "https://optimism.mynode.io/1/",
                    isEnabled: true,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Optimism #2",
                    url: "https://optimism.mynode.io/2/",
                    isEnabled: false,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                }
            ])
    }

    readonly property var sepOptimismRpcProviders: ListModel {
        Component.onCompleted: append([
                {
                    name: "Embedded Sepolia Optimism #1",
                    url: "https://optimism.infura.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-proxy",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                }
            ])
    }

    readonly property var arbitrumRpcProviders: ListModel {
        Component.onCompleted: append([
                {
                    name: "Embedded Arbitrum #1",
                    url: "https://arbitrum.infura.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-proxy",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "Embedded Arbitrum #2",
                    url: "https://arbitrum.alchemy.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-direct",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Arbitrum #1",
                    url: "https://arbitrum.mynode.io/1/",
                    isEnabled: true,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Arbitrum #2",
                    url: "https://arbitrum.mynode.io/2/",
                    isEnabled: false,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                }
            ])
    }

    readonly property var sepArbitrumRpcProviders: ListModel {
        Component.onCompleted: append([
                {
                    name: "Embedded Sepolia Arbitrum #1",
                    url: "https://sepolia-arbitrum.infura.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-proxy",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "Embedded Sepolia Arbitrum #2",
                    url: "https://sepolia-arbitrum.alchemy.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-direct",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Sepolia Arbitrum #1",
                    url: "https://sepolia-arbitrum.mynode.io/1/",
                    isEnabled: true,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Sepolia Arbitrum #2",
                    url: "https://sepolia-arbitrum.mynode.io/2/",
                    isEnabled: false,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                }
            ])
    }

    readonly property var baseRpcProviders: ListModel {
        Component.onCompleted: append([
                {
                    name: "Embedded Base #1",
                    url: "https://base.infura.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-proxy",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "Embedded Base #2",
                    url: "https://base.alchemy.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-direct",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Base #1",
                    url: "https://base.mynode.io/1/",
                    isEnabled: true,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Base #2",
                    url: "https://base.mynode.io/2/",
                    isEnabled: false,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                }
            ])
    }

    readonly property var sepBaseRpcProviders: ListModel {
        Component.onCompleted: append([
                {
                    name: "Embedded Sepolia Base #1",
                    url: "https://sepolia-base.infura.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-proxy",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "Embedded Sepolia Base #2",
                    url: "https://sepolia-base.alchemy.io/v3/",
                    isEnabled: true,
                    providerType: "embedded-direct",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Sepolia Base #1",
                    url: "https://sepolia-base.mynode.io/1/",
                    isEnabled: true,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                },
                {
                    name: "User Sepolia Base #2",
                    url: "https://sepolia-base.mynode.io/2/",
                    isEnabled: false,
                    providerType: "user",
                    authType: "none",
                    authLogin: "",
                    authPassword: "",
                    authToken: ""
                }
            ])
    }



    readonly property var flatNetworks: ListModel {
        Component.onCompleted: append([
            {
                chainId: mainnetChainId,
                chainName: "Mainnet",
                rpcProviders: mainnetRpcProviders,
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
                chainId: hoodiChainId,
                chainName: "Hoodi",
                rpcProviders: hoodiRpcProviders,
                blockExplorerURL: "https://hoodi.etherscan.io/",
                iconUrl: "network/ethereum-test",
                chainColor: "#627EEA",
                shortName: "eth",
                nativeCurrencyName: "Ether",
                nativeCurrencySymbol: "ETH",
                nativeCurrencyDecimals: 18,
                isTest: true,
                layer: 1,
                isRouteEnabled: true,
                isEnabled: true,
                isActive: true,
                isDeactivatable: false,
            },
            {
                chainId: sepMainnetChainId,
                chainName: "Sepolia Mainnet",
                rpcProviders: sepMainnetRpcProviders,
                blockExplorerURL: "https://sepolia.etherscan.io/",
                iconUrl: "network/ethereum-test",
                chainColor: "#627EEA",
                shortName: "eth",
                nativeCurrencyName: "Ether",
                nativeCurrencySymbol: "ETH",
                nativeCurrencyDecimals: 18,
                isTest: true,
                layer: 1,
                isRouteEnabled: true,
                isEnabled: false,
                isActive: false,
                isDeactivatable: true,
            },
            {
                chainId: optChainId,
                chainName: "Optimism",
                rpcProviders: optimismRpcProviders,
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
                chainId: sepOptChainId,
                chainName: "Optimism Sepolia",
                rpcProviders: sepOptimismRpcProviders,
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
                chainId: arbChainId,
                chainName: "Arbitrum",
                rpcProviders: arbitrumRpcProviders,
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
                chainId: sepArbChainId,
                chainName: "Arbitrum Sepolia",
                rpcProviders: sepArbitrumRpcProviders,
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
            {
                chainId: baseChainId,
                chainName: "Base",
                rpcProviders: baseRpcProviders,
                blockExplorerURL: "https://base-explorer.io/",
                iconUrl: "network/base",
                chainColor: "#51D0F0",
                shortName: "base",
                nativeCurrencyName: "Ether",
                nativeCurrencySymbol: "ETH",
                nativeCurrencyDecimals: 18,
                isTest:  false,
                layer:   2,
                isRouteEnabled: true,
                isEnabled: false,
                isActive: false,
                isDeactivatable: true,
            },
            {
                chainId: sepBaseChainId,
                chainName: "Base Sepolia",
                rpcProviders: sepBaseRpcProviders,
                blockExplorerURL: "https://sepolia.base-explorer.io/",
                iconUrl: "network/base-test",
                chainColor: "#939BA1",
                shortName: "base",
                nativeCurrencyName: "Ether",
                nativeCurrencySymbol: "ETH",
                nativeCurrencyDecimals: 18,
                isTest:  true,
                layer:   2,
                isRouteEnabled: true,
                isEnabled: false,
                isActive: true,
                isDeactivatable: true,
            }]
        )
    }

    readonly property var sendFromNetworks: ListModel {
        function updateFromNetworks(paths){
            reset()
            for(let i=0; i<paths.length; i++) {
                for(let k=0; k<count; k++) {
                    if(paths[i].fromNetwork.toString() === get(k).chainId.toString()) {
                        get(k).amountIn = paths[i].amountIn
                        get(k).toNetworks = get(k).toNetworks + ":" + paths[i].toNetwork
                        get(k).hasGas = true
                        get(k).locked = paths[i].amountInLocked
                    }
                }
            }
        }
        function reset() {
            for( let j=0; j<count; j++) {
                get(j).amountIn = ""
                get(j).toNetworks = ""
                get(j).hasGas = true
                get(j).locked = false
            }
        }
        Component.onCompleted: append([
                   {
                       chainId: 1,
                       isRoutePreferred: true,
                       hasGas: true,
                       tokenBalance: ({
                            displayDecimals: true,
                            stripTrailingZeroes: true,
                            amount: 23333213.234
                       }),
                       locked: false,
                       lockedAmount: "",
                       amountIn: "",
                       amountOut: "",
                       toNetworks: ""
                    },
                   {
                        chainId: 10,
                        isRoutePreferred: true,
                        hasGas: true,
                        tokenBalance: ({
                            displayDecimals: true,
                            stripTrailingZeroes: true,
                            amount: 23333213.234
                        }),
                        locked: false,
                        lockedAmount: "",
                        amountIn: "",
                        amountOut: "",
                        toNetworks: ""
                   },
                   {
                        chainId: 42161,
                        isRoutePreferred: true,
                        hasGas: true,
                        tokenBalance: ({
                            displayDecimals: true,
                            stripTrailingZeroes: true,
                            amount: 23333213.234
                        }),
                        locked: false,
                        lockedAmount: "",
                        amountIn: "",
                        amountOut: "",
                        toNetworks: ""
                    }
               ])
    }

    readonly property var sendToNetworks: ListModel {
        function updateRoutePreferredChains(chainIds) {
            for( let i=0; i<count; i++) {
                get(i).isRoutePreferred = false
                get(i).isRouteEnabled = false
                if(chainIds.length === 0) {
                    if(get(i).layer() === 1) {
                        get(i).isRoutePreferred = true
                        get(i).isRouteEnabled = true
                    }
                }
                else {
                    for (let k =0;k<chainIds.split(":").length;k++) {
                        if(get(i).chainId.toString() === chainIds[k].toString()) {
                            get(i).isRoutePreferred = true
                            get(i).isRouteEnabled = true
                        }
                    }
                }
            }
        }
        function updateToNetworks(paths){
            reset()
            for(let i=0;i<paths.length;i++) {
                for( let k=0; k<count; k++) {
                    if(paths[i].toNetwork.toString() === get(k).chainId.toString()) {
                        if(!!get(k).amountOut) {
                            let res = parseInt(get(k).amountOut) + parseInt(paths[i].amountOut)
                            get(k).amountOut = res.toString()
                        }
                        else {
                            get(k).amountOut = paths[i].amountOut
                        }
                    }
                }
            }
        }
        function reset() {
            for( let j=0; j<count; j++) {
                get(j).amountOut = ""
            }
        }
        Component.onCompleted: append([
                   {
                       chainId: 1,
                       isRoutePreferred: true,
                       hasGas: true,
                       tokenBalance: ({
                            displayDecimals: true,
                            stripTrailingZeroes: true,
                            amount: 23333213.234
                       }),
                       locked: false,
                       lockedAmount: "",
                       amountIn: "",
                       amountOut: "",
                       toNetworks: ""
                    },
                   {
                        chainId: 10,
                        hasGas: true,
                        tokenBalance: ({
                            displayDecimals: true,
                            stripTrailingZeroes: true,
                            amount: 23333213.234
                        }),
                        locked: false,
                        lockedAmount: "",
                        amountIn: "",
                        amountOut: "",
                        toNetworks: ""
                   },
                   {
                        chainId: 42161,
                        isRoutePreferred: true,
                        hasGas: true,
                        tokenBalance: ({
                            displayDecimals: true,
                            stripTrailingZeroes: true,
                            amount: 23333213.234
                        }),
                        locked: false,
                        lockedAmount: "",
                        amountIn: "",
                        amountOut: "",
                        toNetworks: ""
                    }
               ])
    }
}
