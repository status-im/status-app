import QtQuick

import StatusQ
import StatusQ.Models
import StatusQ.Core.Utils as SQUtils

import shared.stores

import utils

import QtModelsToolkit
import SortFilterProxyModel

QtObject {
    id: root

    property TokensStore walletTokensStore

    /*
        This property represents the grouped_account_assets_model from backend

        Exposed fields:
        key                 [string] - refers to token group key
        balances            [model]  - contains a single entry for (token, accountAddress) pair
            account         [string] - wallet account address
            groupKey        [string] - group key that the token belongs to (cross chain id or token key if cross chain id is empty)
            tokenKey        [string] - token unique key (chain - address)
            chainId         [int]    - token's chain id
            tokenAddress    [string] - token's address
            balance         [string] - balance that the `account` has for token with `tokenKey`

    */
    readonly property var baseGroupedAccountAssetModel: walletSectionAssets.groupedAccountAssetsModel

    readonly property var assetsController: ManageTokensController {
        sourceModel: groupedAccountAssetsModel
        settingsKey: "WalletAssets"
        serializeAsCollectibles: false

        onRequestSaveSettings: (jsonData) => {
            savingStarted()
            walletTokensStore.updateTokenPreferences(jsonData)
            savingFinished()
        }
        onRequestLoadSettings: {
            loadingStarted()
            let jsonData = walletTokensStore.getTokenPreferencesJson()
            loadingFinished(jsonData)
        }

        onCommunityTokenGroupHidden: (communityName) => Global.displayToastMessage(
                                         qsTr("%1 community assets successfully hidden").arg(communityName), "", "checkmark-circle",
                                         false, Constants.ephemeralNotificationType.success, "")
        onTokenShown: (key, name) => Global.displayToastMessage(qsTr("%1 is now visible").arg(name), "", "checkmark-circle",
                                                                   false, Constants.ephemeralNotificationType.success, "")
        onCommunityTokenGroupShown: (communityName) => Global.displayToastMessage(
                                        qsTr("%1 community assets are now visible").arg(communityName), "", "checkmark-circle",
                                        false, Constants.ephemeralNotificationType.success, "")
    }

    /* PRIVATE: This model renames the roles
        1. "id" to "communityId"
        2. "name" to "communityName"
        3. "image" to "communityImage"
        4. "description" to "communityDescription"
    in communitiesModule.model so that it can be easily
    joined with the Account Assets model */
    readonly property var _renamedCommunitiesModel: RolesRenamingModel {
        sourceModel: communitiesModule.model
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

    /* PRIVATE: This model joins the "Token Groups Model" and "Communities Model" by communityId */
    property LeftJoinModel _tokenGroupsModelWithCommunityInfo: LeftJoinModel {
        leftModel: root.walletTokensStore.tokenGroupsModel
        rightModel: _renamedCommunitiesModel
        joinRole: "communityId"
    }

    /* This model joins the "Tokens by symbol model combined with Community details"
    and "Grouped Account Assets Model" by tokenskey */
    property LeftJoinModel groupedAccountAssetsModel: LeftJoinModel {
        objectName: "groupedAccountAssetsModel"

        leftModel: root.baseGroupedAccountAssetModel
        rightModel: _tokenGroupsModelWithCommunityInfo
        joinRole: "key" // this key refers to group key
    }
}

