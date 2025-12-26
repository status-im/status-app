import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

import utils

QObject {
    id: root

    /**
      Transforms and prepares input data (assets) for TokenSelectorView needs. The assets model is internally
      joined with `flatNetworksModel` for the `balances` submodel

      Expected assets model structure:
      - tokensKey: string -> unique string ID of the token (asset); e.g. "ETH" or contract address
      - name: string -> user visible token name (e.g. "Ethereum")
      - symbol: string -> user visible token symbol (e.g. "ETH")
      - decimals: int -> number of decimal places
      - communityId: string -> optional; ID of the community this token belongs to, if any
      - marketDetails: var -> object containing props like `currencyPrice` for the computed values below
      - balances: submodel -> [ chainId:int, account:string, balance:BigIntString, iconUrl:string ]

      Computed values:
      - currentBalance: double (amount of tokens)
      - currencyBalance: double (e.g. `1000.42` in user's fiat currency)
      - currencyBalanceAsString: string (e.g. "1 000,42 CZK" formatted as a string according to the user's locale)
      - balanceAsString: string (`1.42` formatted as e.g. "1,42" in user's locale)
      - iconSource: string
    */

    // input API
    required property var assetsModel

    property var allTokenGroupsForChainModel // all token groups, loaded on demand
    property var searchResultModel // token groups that match the search keyword
    property var listOfAvailableTokens // considered only if non-empty, otherwise all token groups default to true

    // expected roles: chainId, chainName, iconUrl
    required property var flatNetworksModel

    // CurrenciesStore.currentCurrency, e.g. "USD"
    required property string currentCurrency

    // optional filter properties; empty/default values means no filtering
    property bool showAllTokens // whether to show all tokens, or just the ones we own
    property var enabledChainIds: []
    property string accountAddress
    property bool showCommunityAssets
    // Incase of SendModal we show SNT, ETH and DAI with 0 balance
    property bool showZeroBalanceForDefaultTokens: false

    function loadMoreItems() {
        root.outputAssetsModel.fetchMore()
    }

    function search(keyword) {
        let kw = keyword.trim()
        if (kw === "") {
            root.outputAssetsModel.search(kw)
            d.searchKeyword = kw
        } else {
            d.searchKeyword = kw
            root.outputAssetsModel.search(kw)
        }
    }

    // output model - lazy loaded subset for display
    readonly property var outputAssetsModel: {
        // These dependencies ensure the binding re-evaluates when loaders change
        allTokensLoader.item
        searchResultTokensLoader.item

        return !!d.searchKeyword ? d.outputSearchResultAssetsModel : root.fullOutputAssetsModel
    }

    Loader {
        id: allTokensLoader
        active: root.showAllTokens && !!root.allTokenGroupsForChainModel
        sourceComponent: allTokensComponent
    }

    Loader {
        id: searchResultTokensLoader
        active: root.showAllTokens && !!root.searchResultModel
        sourceComponent: searchResultTokensComponent
    }

    SortFilterProxyModel {
        id: tokensWithBalance
        filters: [
            ValueFilter {
                roleName: "balancesModelCount"
                value: 0
                inverted: true
            }
        ]
        sorters: [
            FastExpressionSorter {
                expression: {
                    const lhs = modelLeft.currencyBalance?? 0
                    const rhs = modelRight.currencyBalance?? 0
                    if (lhs < rhs)
                        return 1
                    else if (lhs > rhs)
                        return -1
                    return 0
                }
                expectedRoles: ["currencyBalance"]
            }
        ]
        sourceModel: ObjectProxyModel {
            sourceModel: root.assetsModel

            objectName: "TokenSelectorViewAdaptor_assetsObjectProxyModel"

            delegate: SortFilterProxyModel {
                id: delegateRoot

                // properties exposed as roles to the top-level model
                readonly property string key: model.key // refers to token group key
                readonly property int decimals: model.decimals
                readonly property double currentBalance: aggregator.value
                readonly property double currencyBalance: {
                    if (!!model.marketDetails) {
                        return currentBalance * model.marketDetails.currencyPrice.amount
                    }
                    return 0
                }
                readonly property int displayDecimals: !!model.marketDetails ? model.marketDetails.currencyPrice.displayDecimals : 0
                readonly property string currencyBalanceAsString:
                    currencyBalance ? LocaleUtils.currencyAmountToLocaleString({amount: currencyBalance, symbol: root.currentCurrency, displayDecimals})
                                    : ""

                readonly property var balances: this
                readonly property int balancesModelCount: delegateRoot.ModelCount.count

                sourceModel: joinModel

                proxyRoles: [
                    FastExpressionRole {
                        name: "balanceAsDouble"
                        expression: balanceToDouble(model.balance, delegateRoot.decimals)
                        expectedRoles: ["balance"]

                        function balanceToDouble(balance: string, decimals: int): double {
                            if (typeof balance !== 'string')
                                return 0
                            let bigIntBalance = AmountsArithmetic.fromString(balance)
                            if (isNaN(bigIntBalance))
                                return 0
                            return AmountsArithmetic.toNumber(bigIntBalance, decimals)
                        }                        
                    },
                    FastExpressionRole {
                        name: "balanceAsString"
                        expression: convert(model.balanceAsDouble)
                        expectedRoles: ["balanceAsDouble"]

                        function convert(amount: double): string {
                            return LocaleUtils.currencyAmountToLocaleString({amount, displayDecimals: 2}, {noSymbol: true})
                        }
                    }
                ]

                filters: [
                    ValueFilter {
                        roleName: "balance"
                        value: "0"
                        inverted: true
                        enabled: !root.showZeroBalanceForDefaultTokens
                    },
                    RegExpFilter {
                        roleName: "account"
                        pattern: root.accountAddress
                        caseSensitivity: Qt.CaseInsensitive
                        enabled: root.accountAddress !== ""
                    },
                    OneOfFilter {
                        roleName: "chainId"
                        array: root.enabledChainIds
                        enabled: root.enabledChainIds.length
                    }
                ]

                sorters: [
                    // sort by biggest (sub)balance first
                    RoleSorter {
                        roleName: "balanceAsDouble"
                        sortOrder: Qt.DescendingOrder
                    }
                ]

                readonly property LeftJoinModel joinModel: LeftJoinModel {
                    leftModel: model.balances
                    rightModel: root.flatNetworksModel
                    joinRole: "chainId"
                }

                readonly property SumAggregator aggregator: SumAggregator {
                    model: delegateRoot
                    roleName: "balanceAsDouble"
                }
            }

            exposedRoles: ["key", "balances", "currentBalance", "currencyBalance", "currencyBalanceAsString", "balanceAsString", "balancesModelCount"]
            expectedRoles: ["key", "communityId", "balances", "decimals", "marketDetails"]
        }
    }

    ModelEntry {
        id: firstEnabledChain
        sourceModel: root.flatNetworksModel
        key: "chainId"
        value: root.enabledChainIds.length ? root.enabledChainIds[0] : null
    }



    // output model - lazy loaded full model
    readonly property SortFilterProxyModel fullOutputAssetsModel: SortFilterProxyModel {

        objectName: "TokenSelectorViewAdaptor_outputAssetsModel"

        sourceModel: root.showAllTokens?
                         allTokensLoader.item
                       : tokensWithBalance.ModelCount.count? tokensWithBalance : null

        proxyRoles: [
            FastExpressionRole {
                name: "sectionName"
                expression: d.getSectionName(!!model.currentBalance)
                expectedRoles: ["currentBalance"]
            },
            FastExpressionRole {
                name: "iconSource"
                expression: model.logoUri || d.tokenIcon(model.symbol)
                expectedRoles: ["logoUri", "symbol"]
            },
            FastExpressionRole {
                name: "groupAvailable" // group is available if at least one token is in the list of available tokens
                expression: d.isAvailable(model.tokens)
                expectedRoles: ["tokens"]
            }
        ]

        sorters: [
            RoleSorter {
                roleName: "sectionName"
                ascendingOrder: false
            },
            RoleSorter {
                roleName: "currencyBalance"
                ascendingOrder: false
            }
        ]
        filters: [
            ValueFilter {
                roleName: "communityId"
                value: ""
                enabled: !root.showCommunityAssets
            }
        ]

        property bool hasMoreItems: false
        property bool isLoadingMore: false

        function search(keyword) {
        }

        function fetchMore() {
            root.allTokenGroupsForChainModel.fetchMore()
        }
    }

    // internals
    QtObject {
        id: d

        property string searchKeyword: ""

        // output model - search results model
        readonly property SortFilterProxyModel outputSearchResultAssetsModel: SortFilterProxyModel {

            objectName: "TokenSelectorViewAdaptor_outputSearchResultAssetsModel"

            sourceModel: searchResultTokensLoader.item

            proxyRoles: [
                FastExpressionRole {
                    name: "sectionName"
                    expression: d.getSectionName(!!model.currentBalance)
                    expectedRoles: ["currentBalance"]
                },
                FastExpressionRole {
                    name: "iconSource"
                    expression: model.logoUri || d.tokenIcon(model.symbol)
                    expectedRoles: ["logoUri", "symbol"]
                },
                FastExpressionRole {
                    name: "groupAvailable" // group is available if at least one token is in the list of available tokens
                    expression: d.isAvailable(model.tokens)
                    expectedRoles: ["tokens"]
                }
            ]

            sorters: [
                RoleSorter {
                    roleName: "sectionName"
                    ascendingOrder: false
                },
                RoleSorter {
                    roleName: "currencyBalance"
                    ascendingOrder: false
                }
            ]
            filters: [
                ValueFilter {
                    roleName: "communityId"
                    value: ""
                    enabled: !root.showCommunityAssets
                }
            ]

            property bool hasMoreItems: false
            property bool isLoadingMore: false

            function search(keyword) {
                root.searchResultModel.search(keyword)
            }

            function fetchMore() {
                root.searchResultModel.fetchMore()
            }
        }

        function getSectionName(hasBalance) {
            if (!hasBalance)
                return qsTr("Popular assets")

            if (firstEnabledChain.available)
                return qsTr("Your assets on %1").arg(firstEnabledChain.item.chainName)
        }

        function tokenIcon(symbol) {
            return Constants.tokenIcon(symbol)
        }

        function isAvailable(tokens) {
            if (!root.listOfAvailableTokens) {
                return true
            }

            for (let i = 0; i < tokens.ModelCount.count; i++) {
                const token = ModelUtils.get(tokens, i)
                let tokenKey = token.key.toLowerCase()
                if (token.address === Constants.zeroAddress) {
                    // special handling for native tokens
                    tokenKey = Utils.buildTokenKey(token.chainId, Constants.zeroAddress1)
                }
                for (let j = 0; j < root.listOfAvailableTokens.length; j++) {
                    if (tokenKey !== root.listOfAvailableTokens[j].toLowerCase()) {
                        continue
                    }
                    return true
                }
            }
            return false
        }
    }

    Connections {
        target: root.allTokenGroupsForChainModel

        function onHasMoreItemsChanged() {
            root.fullOutputAssetsModel.hasMoreItems = root.allTokenGroupsForChainModel.hasMoreItems
        }

        function onIsLoadingMoreChanged() {
            root.fullOutputAssetsModel.isLoadingMore = root.allTokenGroupsForChainModel.isLoadingMore
        }
    }

    Connections {
        target: root.searchResultModel

        function onHasMoreItemsChanged() {
            d.outputSearchResultAssetsModel.hasMoreItems = root.searchResultModel.hasMoreItems
        }

        function onIsLoadingMoreChanged() {
            d.outputSearchResultAssetsModel.isLoadingMore = root.searchResultModel.isLoadingMore
        }
    }


    Component {
        id: allTokensComponent
        LeftJoinModel {
            rightModel: tokensWithBalance
            leftModel: root.allTokenGroupsForChainModel
            joinRole: "key"
            rolesToJoin: ["key", "currentBalance", "currencyBalance", "currencyBalanceAsString", "balanceAsString", "balances"]
        }
    }

    Component {
        id: searchResultTokensComponent
        LeftJoinModel {
            rightModel: tokensWithBalance
            leftModel: root.searchResultModel
            joinRole: "key"
            rolesToJoin: ["key", "currentBalance", "currencyBalance", "currencyBalanceAsString", "balanceAsString", "balances"]
        }
    }
}
