import QtQuick

import StatusQ
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

import utils

QObject {
    id: root

    /**
      Filters and prepares token groups for PaymentRequestModal needs. Filters tokens by selected network chain ID
      and excludes community tokens. Supports lazy loading and search functionality.

      Expected tokenGroupsForChainModel structure:
      - key: string -> token group key (e.g. "eth-native" or cross-chain ID)
      - name: string -> token group name (e.g. "Ether")
      - symbol: string -> token symbol (e.g. "ETH")
      - decimals: int -> number of decimal places
      - logoUri: string -> token group logo/image URL
      - tokens: model/array -> contains tokens that belong to this group, each token has:
          - chainId: int -> chain ID where this token exists
          - address: string -> token contract address (or "0x0000..." for native tokens)
          - key: string -> unique token key (e.g. "1-0x0000000000000000000000000000000000000000")
          - symbol: string -> token symbol
          - name: string -> token name
          - decimals: int -> token decimals
          - image: string -> token image URL
      - communityId: string -> optional; ID of the community this token belongs to (empty string for non-community tokens)
      - marketDetails: object -> optional; market data containing properties like `currencyPrice`

      Expected searchResultModel structure:
      Same as tokenGroupsForChainModel, but contains only token groups that match the search keyword.

      Expected flatNetworksModel structure:
      - chainId: int -> unique chain identifier
      - chainName: string -> network name (e.g. "Ethereum Mainnet")
      - iconUrl: string -> network icon URL

      Computed values in outputModel:
      - iconSource: string -> computed from logoUri or Constants.tokenIcon(symbol) - should be removed, cause all tokens should have non empty logoUri role
      - sectionName: string -> e.g. "Popular assets on Ethereum Mainnet"
    */

    // Input API
    /** Token groups for chain, loaded on demand, without balances **/
    required property var tokenGroupsForChainModel
    /** token groups that match the search keyword **/
    property var searchResultModel
    /** All networks model **/
    required property var flatNetworksModel
    /** Selected network chain id **/
    required property int selectedNetworkChainId


    function loadMoreItems() {
        root.outputModel.fetchMore()
    }

    function search(keyword) {
        let kw = keyword.trim()
        if (kw === "") {
            root.outputModel.search(kw)
            d.searchKeyword = kw
        } else {
            d.searchKeyword = kw
            root.outputModel.search(kw)
        }
    }

    // output model - lazy loaded subset for display
    readonly property var outputModel: !!d.searchKeyword ? d.searchModel : d.fullOutputModel

    QtObject {
        id: d

        property string searchKeyword: ""

        // output model - lazy loaded full model
        readonly property GroupsModel fullOutputModel: GroupsModel {
            modelObjectName: "TokenSelectorViewAdaptor_allTokensModel"
            innerObjectName: "PaymentRequestAdaptor_allTokensPlain"
            sourceTokenModel: root.tokenGroupsForChainModel
            flatNetworksModel: root.flatNetworksModel
            selectedNetworkChainId: root.selectedNetworkChainId
            onFetchMoreCallback: function() {
                root.tokenGroupsForChainModel.fetchMore()
            }
            sourceModelConnectionTarget: root.tokenGroupsForChainModel
        }

        // output model - search results model
        readonly property GroupsModel searchModel: GroupsModel {
            modelObjectName: "TokenSelectorViewAdaptor_outputSearchResultModel"
            innerObjectName: "PaymentRequestAdaptor_searchResultTokensPlain"
            sourceTokenModel: root.searchResultModel
            flatNetworksModel: root.flatNetworksModel
            selectedNetworkChainId: root.selectedNetworkChainId
            onFetchMoreCallback: function() {
                root.searchResultModel.fetchMore()
            }
            onSearchCallback: function(keyword) {
                root.searchResultModel.search(keyword)
            }
            sourceModelConnectionTarget: root.searchResultModel
            sort: false
        }
    }

    Connections {
        target: root.tokenGroupsForChainModel

        function onHasMoreItemsChanged() {
            d.fullOutputModel.hasMoreItems = root.tokenGroupsForChainModel.hasMoreItems
        }

        function onIsLoadingMoreChanged() {
            d.fullOutputModel.isLoadingMore = root.tokenGroupsForChainModel.isLoadingMore
        }
    }

    Connections {
        target: root.searchResultModel

        function onHasMoreItemsChanged() {
            d.searchModel.hasMoreItems = root.searchResultModel.hasMoreItems
        }

        function onIsLoadingMoreChanged() {
            d.searchModel.isLoadingMore = root.searchResultModel.isLoadingMore
        }
    }
}
