import QtQuick

import StatusQ
import StatusQ.Models
import StatusQ.Core.Utils as SQUtils

import utils

import QtModelsToolkit
import SortFilterProxyModel


QtObject {
    id: root

    /* PRIVATE: Modules used to get data from backend */
    readonly property var _allCollectiblesModule: !!walletSectionAllCollectibles ? walletSectionAllCollectibles : null

    /* This list contains the complete list of collectibles with separate
       entry per collectible which has a unique [network + contractAddress + tokenID] */
    readonly property var _allCollectiblesModel: !!root._allCollectiblesModule ? root._allCollectiblesModule.allCollectiblesModel : null

    readonly property var allCollectiblesModel: RolesRenamingModel {
        objectName: "allCollectiblesModel"

        sourceModel: root._allCollectiblesModel

        mapping: [
            RoleRename {
                from: "uid"
                to: "key"
            }
        ]
    }

    /* Creates a terminal collectibles-picker model for the send modal, seeded
       with the current collectibles universe and kept updated by the module.
       Returns { model, id }; the caller sets the model's per-modal params
       (accountKey/enabledChainId/filterCommunityOwnerAndMasterTokens) and must
       pass the id to releaseCollectiblesSelectorModel when the modal is
       destroyed so the model stops being tracked and can be freed. */
    function createCollectiblesSelectorModel() {
        if (!root._allCollectiblesModule)
            return { model: null, id: -1 }
        const model = root._allCollectiblesModule.createCollectiblesSelectorModel()
        return { model: model, id: root._allCollectiblesModule.lastCreatedSelectorModelId }
    }

    function releaseCollectiblesSelectorModel(id) {
        if (!!root._allCollectiblesModule && id >= 0)
            root._allCollectiblesModule.releaseCollectiblesSelectorModel(id)
    }

    readonly property var collectiblesController: ManageTokensController {
        sourceModel: root.jointCollectiblesBySymbolModel
        settingsKey: "WalletCollectibles"
        serializeAsCollectibles: true

        onRequestSaveSettings: (jsonData) => {
            savingStarted()
            _allCollectiblesModule.updateCollectiblePreferences(jsonData)
            savingFinished()
        }
        onRequestLoadSettings: {
            loadingStarted()
            let jsonData = _allCollectiblesModule.getCollectiblePreferencesJson()
            loadingFinished(jsonData)
        }

        onCommunityTokenGroupHidden: (communityName) => Global.displayToastMessage(
                                         qsTr("%1 community collectibles successfully hidden").arg(communityName), "", "checkmark-circle",
                                         false, Constants.ephemeralNotificationType.success, "")
        onTokenShown: (symbol, name) => Global.displayToastMessage(qsTr("%1 is now visible").arg(name), "", "checkmark-circle",
                                                                   false, Constants.ephemeralNotificationType.success, "")
        onCommunityTokenGroupShown: (communityName) => Global.displayToastMessage(
                                        qsTr("%1 community collectibles are now visible").arg(communityName), "", "checkmark-circle",
                                        false, Constants.ephemeralNotificationType.success, "")
    }

    /* PRIVATE: This model renames the roles
        1. "id" to "communityId"
        2. "name" to "communityName"
        3. "image" to "communityImage"
        4. "description" to "communityDescription"
        in communitiesModule.model so that it can be easily
        joined with the Collectibles model */
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

    /* TODO: move all transformations to a dedicated adaptors */
    readonly property LeftJoinModel jointCollectiblesBySymbolModel: LeftJoinModel {
        objectName: "jointCollectiblesBySymbolModel"

        leftModel: allCollectiblesModel
        rightModel: _renamedCommunitiesModel
        joinRole: "communityId"
    }

    readonly property bool areCollectiblesFetching: !!root._allCollectiblesModel ? root._allCollectiblesModel.isFetching : true
    readonly property bool areCollectiblesUpdating: !!root._allCollectiblesModel ? root._allCollectiblesModel.isUpdating : false
    readonly property bool areCollectiblesError: !!root._allCollectiblesModel ? root._allCollectiblesModel.isError : false


    /* The following are used to display the detailed view of a collectible */
    readonly property var detailedCollectible: Global.appIsReady ? walletSection.collectibleDetailsController.detailedEntry : null
    readonly property var detailedCollectibleStatus: Global.appIsReady ? walletSection.collectibleDetailsController.status : null
    readonly property bool isDetailedCollectibleLoading: Global.appIsReady ? walletSection.collectibleDetailsController.isDetailedEntryLoading : true

    function getDetailedCollectible(chainId, contractAddress, tokenId) {
        walletSection.collectibleDetailsController.getDetailedCollectible(chainId, contractAddress, tokenId)
    }

    function resetDetailedCollectible() {
        walletSection.collectibleDetailsController.resetDetailedCollectible()
    }

    function hasNFT(ownerAddress, chainId, tokenId, tokenAddress) {
        const uid = getUidForData(tokenId, tokenAddress, chainId)
        ownerAddress = ownerAddress.toLowerCase()
        const ownership = SQUtils.ModelUtils.getByKey(_allCollectiblesModel, "uid", uid, "ownership")
        if (!ownership)
            return false

        for (let i = 0; i < ownership.count; i++) {
            const accountAddress = SQUtils.ModelUtils.get(ownership, i, "accountAddress").toLowerCase()
            if (accountAddress !== ownerAddress)
                continue
            const tokenBalanceStr = SQUtils.ModelUtils.get(ownership, i, "balance").toLowerCase()
            if (tokenBalanceStr !== "")
                return true
        }
        return false
    }

    function getUidForData(tokenId, tokenAddress, chainId) {
        return _allCollectiblesModel.getUidForData(tokenId, tokenAddress, chainId)
    }
}
