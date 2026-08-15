import QtQuick

import StatusQ
import StatusQ.Models
import StatusQ.Core.Utils as SQUtils

import utils

import QtModelsToolkit
import SortFilterProxyModel

import AppLayouts.Wallet.stores

import Storybook
import Models
import Mocks

WalletAssetsStore {
    id: root

    walletTokensStore: TokensStoreMock {}

    property var baseGroupedAccountAssetModel: BaseGroupedAccountsAssetsModel {}

    readonly property var assetsController: QtObject {
        property int revision
        function filterAcceptsSymbol(symbol) {
            return true
        }
    }

    readonly property var communityModel: ListModel {
        Component.onCompleted: append([
            {
                id: "ddls",
                name: "Doodles",
                image: ModelsData.collectibles.doodles,
                description: ""
            },
            {
                id: "sox",
                name: "Socks",
                image: ModelsData.icons.socks,
                description: ""
            },
            {
                id: "ast",
                name: "Astafarians",
                image: ModelsData.icons.dribble,
                description: ""
            }
        ])
    }

    readonly property var _renamedCommunitiesModel: RolesRenamingModel {
        sourceModel: communityModel
        mapping: [
            RoleRename {
                from: "id"
                to: "communityId"
            },
            RoleRename {
                from: "name"
                to: "communityName"
            },
            RoleRename {
                from: "image"
                to: "communityImage"
            },
            RoleRename {
                from: "description"
                to: "communityDescription"
            }
        ]
    }

    property LeftJoinModel _tokenGroupsModelWithCommunityInfo: LeftJoinModel {
        leftModel: walletTokensStore.tokenGroupsModel
        rightModel: _renamedCommunitiesModel
        joinRole: "communityId"
    }

    // This is the joined model that exposes all roles (matching production)
    property LeftJoinModel groupedAccountAssetsModel: LeftJoinModel {
        objectName: "groupedAccountAssetsModel"
        leftModel: baseGroupedAccountAssetModel
        rightModel: _tokenGroupsModelWithCommunityInfo
        joinRole: "key"
    }

    readonly property SortFilterProxyModel bridgeableGroupedAccountAssetsModel: SortFilterProxyModel {
        objectName: "bridgeableGroupedAccountAssetsModel"
        sourceModel: root.groupedAccountAssetsModel

        filters: [
            FastExpressionFilter {
                function isBSC(chainId) {
                    return chainId === Constants.chains.binanceSmartChainMainnetChainId ||
                            chainId === Constants.chains.binanceSmartChainTestnetChainId
                }

                // this function returns true if the token group item contains at least one token which can be bridged via Hop
                function supportedByHopBridge(tokens) {
                    return false
                }
                expression: {
                    return supportedByHopBridge(model.tokens)
                }
                expectedRoles: ["tokens"]
            }
        ]
    }
}
