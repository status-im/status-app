import QtQuick

import StatusQ
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

import utils

/**
  Reusable component for filtering and preparing token groups.
  Handles network filtering, proxy roles, sorting, and callbacks dynamically.
*/
SortFilterProxyModel {
    id: root

    required property var sourceTokenModel
    required property var flatNetworksModel
    required property int selectedNetworkChainId
    required property string modelObjectName
    required property string innerObjectName
    required property var onFetchMoreCallback

    property var onSearchCallback: null
    property var sourceModelConnectionTarget: null
    property bool sort: true

    objectName: modelObjectName

    readonly property string networkName: ModelUtils.getByKey(flatNetworksModel, "chainId", selectedNetworkChainId, "chainName")

    function isPresentOnEnabledNetwork(tokens, selectedChainId) {
        if(selectedChainId < 0)
            return true
        return !!ModelUtils.getFirstModelEntryIf(
                    tokens,
                    (t) => {
                        return selectedChainId === t.chainId
                    })
    }

    sourceModel: SortFilterProxyModel {
        objectName: innerObjectName
        sourceModel: root.sourceTokenModel
        filters: [
            FastExpressionFilter {
                expression: {
                    return root.isPresentOnEnabledNetwork(model.tokens, root.selectedNetworkChainId)
                }
                expectedRoles: ["tokens"]
            }
        ]
    }

    proxyRoles: [
        ConstantRole {
            name: "sectionName"
            value: qsTr("Popular assets on %1").arg(root.networkName)
        },
        FastExpressionRole {
            function tokenIcon(symbol) {
                return Constants.tokenIcon(symbol)
            }
            name: "iconSource"
            expression: model.logoUri || tokenIcon(model.symbol)
            expectedRoles: ["logoUri", "symbol"]
        }
    ]

    sorters: [
        RoleSorter {
            roleName: "name"
            enabled: root.sort
        }
    ]
    filters: [
        ValueFilter {
            roleName: "communityId"
            value: ""
        }
    ]

    property bool hasMoreItems: false
    property bool isLoadingMore: false

    function search(keyword) {
        if (onSearchCallback) {
            onSearchCallback(keyword)
        }
    }

    function fetchMore() {
        if (onFetchMoreCallback) {
            onFetchMoreCallback()
        }
    }
}
