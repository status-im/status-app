import QtQuick

import StatusQ
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

/**
  Transforms and prepares the wallet accounts model to display
  selected token on selected network

  When no token or network is selected, only currency balance for account is shown.
*/
QObject {
    id: root

    // input api

    /** Expected accounts model structure:
    - name: name of the account
    - address: address of the account,
    - colorId: color id for the account,
    - canSend: can send from acount ,
    - position: position set by user in settings,
    - currencyBalance: total currency balance in CurrencyAmount type,
    - migratedToColdWallet: if account is migrated to cold wallet.
    */
    required property var accounts
    /** Expected assets model structure:
    - tokensKey: string -> unique string ID of the token (asset); e.g. "ETH" or contract address
    - name: string -> user visible token name (e.g. "Ethereum")
    - symbol: string -> user visible token symbol (e.g. "ETH")
    - decimals: int -> number of decimal places
    - communityId: string -> optional; ID of the community this token belongs to, if any
    - marketDetails: var -> object containing props like `currencyPrice` for the computed values below
    - balances: submodel -> [ chainId:int, account:string, balance:BigIntString, iconUrl:string ]
    */
    required property var assetsModel
    /** Expected token by symbol model structure:
    - key: id for the token,
    - name: name of the token,
    - symbol: symbol of the token,
    - decimals: decimals for the token
    */
    required property var tokenGroupsModel
    /** Expected networks model structure:
    - chainId: chain Id for network,
    - chainName: name of network,
    - iconUrl: icon representing the network,
    */
    required property var filteredFlatNetworksModel
    /** selectedGroupKey:
        the selected token key
    */
    required property string selectedGroupKey
    /**  selectedNetworkChainId:
        the  selected network chainId
    */
    required property int selectedNetworkChainId

    /**  function to calculate token balance from BigInt:
        the  selected network chainId
    */
    required property var fnFormatCurrencyAmountFromBigInt

    /** output model
    Computed processedWalletAccounts model addon values:
    - accountBalance: balance of selected token on selected network along with network information
    - filters out account that cant be used to send
    */
    readonly property var processedWalletAccounts: SortFilterProxyModel {
        sourceModel: root.accounts
        delayed: true // Delayed to allow `processAccountBalance` dependencies to be resolved
        filters: ValueFilter {
            roleName: "canSend"
            value: true
        }
        sorters: [
            RoleSorter { roleName: "currencyBalanceDouble"; sortOrder: Qt.DescendingOrder },
            RoleSorter { roleName: "position"; sortOrder: Qt.AscendingOrder }
        ]
        proxyRoles: [
            FastExpressionRole {
                name: "accountBalance"
                expression: {
                    // dependencies
                    root.selectedGroupKey
                    root.selectedNetworkChainId
                    return d.processAccountBalance(model.address)
                }
                expectedRoles: ["address"]
            },
            FastExpressionRole {
                 name: "currencyBalanceDouble"
                 expression: model.currencyBalance.amount
                 expectedRoles: ["currencyBalance"]
             }
        ]
    }

    QtObject {
        id: d

        readonly property ObjectProxyModel filteredBalancesModel: ObjectProxyModel {
            sourceModel: root.assetsModel

            delegate: SortFilterProxyModel {
                readonly property var balances: this

                sourceModel: LeftJoinModel {
                    leftModel: model.balances
                    rightModel: root.filteredFlatNetworksModel

                    joinRole: "chainId"
                }

                filters: ValueFilter {
                    roleName: "chainId"
                    value: root.selectedNetworkChainId
                }
            }

            expectedRoles: "balances"
            exposedRoles: "balances"
        }

        function processAccountBalance(address) {
            let selectedTokenGroup = ModelUtils.getByKey(root.tokenGroupsModel, "key", root.selectedGroupKey)
            if (!selectedTokenGroup) {
                return null
            }

            let network = ModelUtils.getByKey(root.filteredFlatNetworksModel, "chainId", root.selectedNetworkChainId)
            if (!network) {
                return null
            }

            let balancesModel = ModelUtils.getByKey(filteredBalancesModel, "key", root.selectedGroupKey, "balances")
            let accountBalance = ModelUtils.getByKey(balancesModel, "account", address)
            if(accountBalance && accountBalance.balance !== "0") {
                accountBalance.formattedBalance = root.fnFormatCurrencyAmountFromBigInt(accountBalance.balance, selectedTokenGroup.symbol, selectedTokenGroup.decimals)
                return accountBalance
            }

            return {
                balance: "0",
                iconUrl: network.iconUrl,
                chainColor: network.chainColor,
                formattedBalance: "0 %1".arg(selectedTokenGroup.symbol)
            }
        }
    }
}
