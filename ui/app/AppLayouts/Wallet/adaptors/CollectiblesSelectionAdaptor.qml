import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

import utils

/**
  Adaptor transforming input flat model of collectibles into grouped model,
  grouped by communities and collections to form expected by components like
  e.g. TokenSelector.

  1. Ownership submodels filtered to have only entries for given `account`
  2. Total balance calculated for remaining ownership entries in submodels
  3. Balance exposed to the top level model
  4. Grouping value exposed depending if token comes from community or not
     (community collectibles are grouped by communtiyId, other by collectionId)
  5. Entries with zero balance filtered out
  6. Items are sorted by communityId and collectionId in order to group them correctly
  7. Grouping by groupingValue
  8. For community groups, group once again by collectionId
  9. Expose groupName and type according of it's community group or collection
  10. Expose sub-sub-groups count as a balance for sub-groups
**/
QObject {
    id: root

    /** Account key used for filtering **/
    property string accountKey


    /**
      Expected model structure:

        chainId              [int]    - network chain id
        chainName            [string] - name of network
        iconUrl              [string] - network icon url
    **/
    property var networksModel

    /**
      Expected model structure:

        key                 [string] - unique identifier of a collectible
        chainId             [int] - unique identifier of a network
        collectionUid       [string] - unique identifier of a collection
        contractAddress     [string] - collectible's contract address
        name                [string] - collectible's name e.g. "Magicat"
        collectionName      [string] - collection name e.g. "Crypto Kitties"
        mediaUrl            [url]    - collectible's media url
        imageUrl            [url]    - collectible's image url
        communityId         [string] - unique identifier of a community for community collectible or empty
        ownership           [model]  - submodel of balances per chain/account
            balance         [int]    - balance (always 1 for ERC-721)
            accountAddress  [string] - unique identifier of an account
    **/
    property var collectiblesModel

    /**
      Model structure:

        groupName           [string] - group name (from collection or community name)
        icon                [url]    - from imageUrl or mediaUrl
        type                [string] - can be "community" or "other"
        subitems            [model]  - submodel of collectibles/collections of the group
            key             [string] - key of collection (community type) or collectible (other type)
            name            [string] - name of the subitem (of collectible or collection)
            balance         [int]    - balance of collection (in case of community collectibles)
                                       or collectible (in case of ERC-1155)
            icon            [url]    - icon of the subitem
    **/
    readonly property alias model: communityGroupsGrouppedByCollection

    /** output model which follows same structure as the input collectiblesModel
      The only add on here is that this model is not grouped and is filtered
      based on account and chainId
    **/
    readonly property alias filteredFlatModel: initiallyFilteredAndSorted

    // In case collectibles are to be shown only on specific networks
    property var enabledChainIds: []

    // in case the community ownership and master tokens are to be filtered out
    property bool filterCommunityOwnerAndMasterTokens: false

    LeftJoinModel {
        id: jointCollectiblesByNwChainId
        leftModel: collectiblesModel ?? null
        rightModel: networksModel
        joinRole: "chainId"
    }

    SortFilterProxyModel {
        id: initiallyFilteredAndSorted

        objectName: "collectiblesSelectionAdaptor_initiallyFilteredAndSorted"

        sourceModel: ObjectProxyModel {
            sourceModel: jointCollectiblesByNwChainId

            delegate: QObject {
                readonly property int balance: balanceAggregator.value /* 3 */
                readonly property string groupingValue: model.communityId /* 4 */
                                                        ? model.communityId
                                                        : model.collectionUid


                readonly property url icon:
                    model.imageUrl || model.mediaUrl || Assets.png(Constants.defaultTokenIcon)

                SortFilterProxyModel { /* 1 */
                    id: ownershipFiltered

                    sourceModel: model.ownership

                    filters: ValueFilter {
                        roleName: "accountAddress"
                        value: root.accountKey
                    }
                }

                SumAggregator {  /* 2 */
                    id: balanceAggregator

                    model: ownershipFiltered
                    roleName: "balance"
                }
            }

            expectedRoles: [
                "ownership", "communityId", "collectionUid", "imageUrl",
                "mediaUrl"
            ]
            exposedRoles: ["balance", "groupingValue", "icon"]
        }

        filters: [
            RangeFilter { /* 5 */
                roleName: "balance"
                minimumValue: 1
            },
            // remove tokens not available on selected network(s)
            OneOfFilter {
                roleName: "chainId"
                array: root.enabledChainIds
                enabled: root.enabledChainIds.length
            },
            ValueFilter {
                roleName: "communityPrivilegesLevel"
                value: Constants.TokenPrivilegesLevel.Owner
                enabled: root.filterCommunityOwnerAndMasterTokens
                inverted: true
            },
            ValueFilter {
                roleName: "communityPrivilegesLevel"
                value: Constants.TokenPrivilegesLevel.TMaster
                enabled: root.filterCommunityOwnerAndMasterTokens
                inverted: true
            }
        ]

        sorters: [ /* 6 */
            RoleSorter {
                roleName: "communityId"
                sortOrder: Qt.DescendingOrder
            },
            RoleSorter {
                roleName: "collectionUid"
            }
        ]
    }

    GroupingModel { /* 7 */
        id: grouppedByCollectionOrCommunity

        objectName: "collectiblesSelectionAdaptor_grouppedByCollectionOrCommunity"

        sourceModel: initiallyFilteredAndSorted
        groupingRoleName: "groupingValue"
        submodelRoleName: "subitems"
    }

    ObjectProxyModel {
        id: communityGroupsGrouppedByCollection

        objectName: "collectiblesSelectionAdaptor_communityGroupsGrouppedByCollection"

        sourceModel: grouppedByCollectionOrCommunity

        delegate: QObject {
            readonly property var subitems:
                model.communityId ? collectionCountProxyLoader.item
                                  : model.subitems
            readonly property string type: /* 9 */
                model.communityId ? "community" : "other"
            readonly property string groupName:
                model.communityName || model.collectionName

            readonly property url icon:
                model.communityId ? model.communityImage
                                  : (model.icon || Qt.resolvedUrl(""))

            Loader {
                id: collectionCountProxyLoader

                active: !!model.communityId

                sourceComponent: ObjectProxyModel {
                    sourceModel: GroupingModel { /* 8 */
                        sourceModel: model.communityId ? model.subitems : null

                        groupingRoleName: "collectionUid"
                        submodelRoleName: "subitems"
                    }

                    delegate: QtObject { /* 10 */
                        readonly property int balance: model.subitems.ModelCount.count
                        readonly property string key: model.collectionUid
                    }

                    expectedRoles: ["subitems", "collectionUid"]
                    exposedRoles: ["balance", "key"]
                }
            }
        }

        expectedRoles: [
            "subitems", "collectionName", "communityId",
            "communityName", "communityImage", "icon"
        ]
        exposedRoles: ["subitems", "type", "groupName", "icon"]
    }
}
