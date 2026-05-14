import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Models
import StatusQ.Popups
import StatusQ.Popups.Dialog

import shared.controls
import shared.panels
import shared.popups

import utils

import AppLayouts.Wallet.views.collectibles
import AppLayouts.Wallet.controls

import QtModelsToolkit
import SortFilterProxyModel

ColumnLayout {
    id: root

    required property var ownedAccountsModel
    required property var controller
    required property var activeNetworks
    required property string addressFilters
    required property string networkFilters
    property bool sendEnabled: true
    property bool filterVisible
    property bool isFetching: false // Indicates if a collectibles page is being loaded from the backend
    property bool isUpdating: false // Indicates if the collectibles list is being updated
    property bool isError: false // Indicates an error occurred while updating/fetching the collectibles list
    property alias bannerComponent: banner.sourceComponent

    // allows/disables choosing custom sort order from a sorter
    property bool customOrderAvailable

    property alias selectedFilterGroupIds: cmbFilter.selectedFilterGroupIds

    required property var unsupportedChainIds

    signal collectibleClicked(int chainId, string contractAddress, string tokenId, string uid, int tokenType, string communityId)
    signal sendRequested(string collectionUid, int tokenType, string fromAddress)
    signal receiveRequested(string symbol)
    signal switchToCommunityRequested(string communityId)
    signal manageTokensRequested()

    spacing: 0

    function setSortOrder(order) {
        d.sortOrder = order
    }

    function getSortOrder() {
        return d.sortOrder
    }

    function getSortValue() {
        return d.sortValue
    }

    function sortByValue(value) {
        d.sortValue = value
    }

    QtObject {
        id: d

        property int sortValue: SortOrderComboBox.TokenOrderAlpha
        property int sortOrder: Qt.DescendingOrder

        readonly property int cellHeight: 225
        readonly property int communityCellHeight: 242
        readonly property int cellWidth: 176
        readonly property int headerHeight: 56

        readonly property bool isCustomView: cmbTokenOrder.currentValue === SortOrderComboBox.TokenOrderCustom

        readonly property var sourceModel: root.controller.sourceModel
        readonly property bool isLoading: root.isUpdating || root.isFetching

        function setSortByDateIsDisabled(value) {
            const orderByDateIndex =  cmbTokenOrder.indexOfValue(SortOrderComboBox.TokenOrderDateAdded)

            cmbTokenOrder.model[orderByDateIndex].isDisabled = value
            cmbTokenOrder.modelChanged()

            if (!value && cmbTokenOrder.currentIndex === orderByDateIndex) {
                cmbTokenOrder.indexOfValue(SortOrderComboBox.TokenOrderAlpha)
            }
        }

        onIsLoadingChanged: {
            d.loadingItemsModel.refresh()
        }

        readonly property var loadingItemsModel: ListModel {
            Component.onCompleted: {
                refresh()
            }

            function refresh() {
                clear()
                if (d.isLoading) {
                    for (let i = 0; i < 10; i++) {
                        append({ isLoading: true, name: qsTr("Loading collectible...") })
                    }
                }
            }
        }

        readonly property var communityModel: CustomSFPM {
            isCommunity: true
        }

        readonly property var communityModelWithLoadingItems: ConcatModel {
            sources: [
                SourceModel {
                    model: d.communityModel
                    markerRoleValue: "communityModel"
                },
                SourceModel {
                    model: d.loadingItemsModel
                    markerRoleValue: "loadingItemsModel"
                }
            ]

            markerRoleName: "sourceGroup"
        }

        readonly property var nonCommunityModel: CustomSFPM {
            isCommunity: false
        }

        readonly property var nonCommunityModelWithLoadingItems: ConcatModel {
            sources: [
                SourceModel {
                    model: d.nonCommunityModel
                    markerRoleValue: "nonCommunityModel"
                },
                SourceModel {
                    model: d.loadingItemsModel
                    markerRoleValue: "loadingItemsModel"
                }
            ]

            markerRoleName: "sourceGroup"
        }

        readonly property var allCollectiblesModel: ConcatModel {
            sources: [
                SourceModel {
                    model: d.communityModel
                    markerRoleValue: "loadingItemsModel"
                },
                SourceModel {
                    model: d.nonCommunityModel
                    markerRoleValue: "nonCommunityModel"
                }
            ]
            markerRoleName: "sourceGroup"
        }


        readonly property bool hasRegularCollectibles: d.nonCommunityModel.count || d.loadingItemsModel.count
        readonly property bool hasCommunityCollectibles: d.communityModel.count || d.loadingItemsModel.count
        readonly property bool onlyRegularCollectiblesType: hasRegularCollectibles && !hasCommunityCollectibles

        readonly property var addrFilters: root.addressFilters.split(":")

        function getFirstUserOwnedAddress(ownershipModel) {
            if (!ownershipModel) return ""

            for (let i = 0; i < ownershipModel.rowCount(); i++) {
                const accountAddress = ModelUtils.get(ownershipModel, i, "accountAddress")
                if (ModelUtils.contains(root.ownedAccountsModel, "address", accountAddress, Qt.CaseInsensitive))
                    return accountAddress
            }
            return ""
        }

        readonly property int networksCount: root.activeNetworks.ModelCount.count

        function getUnsupportedChainIds() {
            let activeChainIds = ModelUtils.modelToFlatArray(root.activeNetworks, "chainId")
            return root.unsupportedChainIds.filter(chainId => activeChainIds.includes(chainId))
        }

        property FunctionAggregator hasAllTimestampsAggregator: FunctionAggregator {
            model: d.allCollectiblesModel
            initialValue: true
            roleName: "lastTxTimestamp"

            aggregateFunction: (aggr, value) => aggr && value > 0

            onValueChanged: {
                Qt.callLater(() => {
                    d.hasAllTimestamps = value
                    d.setSortByDateIsDisabled(value)
                })
            }

            Component.onCompleted: d.hasAllTimestamps = value
        }

        property bool hasAllTimestamps
    }

    component CustomSFPM: GroupsSFPM {
        id: customFilter
        property bool isCommunity

        sourceModel: d.sourceModel
        proxyRoles: [
            FastExpressionRole {
                name: "groupName"
                expression: !!model.communityId ? model.communityName : model.collectionName
                expectedRoles: ["communityId", "collectionName", "communityName"]
            },
            FastExpressionRole {
                name: "lastTxTimestamp"
                expression: {
                    d.addrFilters
                    return root.controller.getOwnershipTotalBalanceAndLastTimestamp(model.ownership, d.addrFilters)["timestamp"]
                }
                expectedRoles: ["ownership"]
            }
        ]
        filters: [
            FastExpressionFilter {
                expression: {
                    root.controller.revision
                    return (customFilter.isCommunity ? !!model.communityId : !model.communityId) && root.controller.filterAcceptsKey(model.symbol) // TODO: use token/group key
                }
                expectedRoles: ["symbol", "communityId"]
            },
            FastExpressionFilter {
                enabled: customFilter.isCommunity && cmbFilter.hasEnabledFilters
                expression: cmbFilter.selectedFilterGroupIds.includes(model.communityId) ||
                            (!model.communityId && cmbFilter.selectedFilterGroupIds.includes(""))
                expectedRoles: ["communityId"]
            },
            FastExpressionFilter {
                enabled: !customFilter.isCommunity && cmbFilter.hasEnabledFilters
                expression: cmbFilter.selectedFilterGroupIds.includes(model.collectionUid) ||
                            (!model.collectionUid && cmbFilter.selectedFilterGroupIds.includes(""))
                expectedRoles: ["collectionUid"]
            }
        ]
        sorters: [
            FastExpressionSorter {
                expression: {
                    root.controller.revision
                    return root.controller.compareTokens(modelLeft.symbol, modelRight.symbol)
                }
                enabled: d.isCustomView
                expectedRoles: ["symbol"]
            },
            RoleSorter {
                roleName: cmbTokenOrder.currentSortRoleName
                sortOrder: cmbTokenOrder.currentSortOrder
                enabled: !d.isCustomView
            }
        ]
    }

    component GroupsSFPM: SortFilterProxyModel {
        sourceModel: d.sourceModel
        proxyRoles: [
            FastExpressionRole {
                name: "balance"
                expression: {
                    d.addrFilters
                    return root.controller.getOwnershipTotalBalanceAndLastTimestamp(model.ownership, d.addrFilters)["balance"]
                }
                expectedRoles: ["ownership"]
            }
        ]
        filters: [
            OneOfFilter {
                roleName: "chainId"
                array: root.networkFilters
                separator: ":"
            },
            ValueFilter {
                roleName: "balance"
                value: 0
                inverted: true
            }
        ]
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: root.filterVisible ? implicitHeight : 0
        spacing: 20
        opacity: root.filterVisible ? 1 : 0

        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

        StatusDialogDivider {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.halfPadding

            FilterComboBox {
                id: cmbFilter
                sourceModel: GroupsSFPM {}

                regularTokensModel: root.controller.regularTokensModel
                collectionGroupsModel: root.controller.collectionGroupsModel
                communityTokenGroupsModel: root.controller.communityTokenGroupsModel
                hasCommunityGroups: d.hasCommunityCollectibles
            }

            Rectangle {
                Layout.preferredHeight: 34
                Layout.preferredWidth: 1
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                color: Theme.palette.baseColor2
            }

            StatusBaseText {
                color: Theme.palette.baseColor1
                font.pixelSize: Theme.additionalTextSize
                text: qsTr("Sort by:")
            }

            SortOrderComboBox {
                id: cmbTokenOrder
                hasCustomOrderDefined: root.customOrderAvailable
                Binding on currentIndex {
                    value: {
                        cmbTokenOrder.count
                        let sortValue = d.sortValue
                        if (root.sortValue === SortOrderComboBox.TokenOrderDateAdded && !d.hasAllTimestamps)
                            sortValue = SortOrderComboBox.TokenOrderAlpha
                        let id = cmbTokenOrder.indexOfValue(sortValue)
                        if (id === -1)
                            id = cmbTokenOrder.indexOfValue(SortOrderComboBox.TokenOrderAlpha)
                        return id
                    }
                    when: cmbTokenOrder.count > 0
                }
                onCurrentValueChanged: d.sortValue = cmbTokenOrder.currentValue
                Binding on currentSortOrder {
                    value: d.sortOrder
                }
                onCurrentSortOrderChanged: d.sortOrder = cmbTokenOrder.currentSortOrder
                model: [
                    { value: SortOrderComboBox.TokenOrderDateAdded, text: qsTr("Date added"), icon: "", sortRoleName: "lastTxTimestamp", isDisabled: !d.hasAllTimestamps }, // Custom SFPM role
                    { value: SortOrderComboBox.TokenOrderAlpha, text: qsTr("Collectible name"), icon: "", sortRoleName: "name" },
                    { value: SortOrderComboBox.TokenOrderGroupName, text: qsTr("Collection/community name"), icon: "", sortRoleName: "groupName" }, // Custom SFPM role communityName || collectionName
                    { value: SortOrderComboBox.TokenOrderCustom, text: qsTr("Custom order"), icon: "", sortRoleName: "" },
                    { value: SortOrderComboBox.TokenOrderNone, text: "---", icon: "", sortRoleName: "" }, // separator
                    { value: SortOrderComboBox.TokenOrderCreateCustom, text: hasCustomOrderDefined ? qsTr("Edit custom order →") : qsTr("Create custom order →"),
                        icon: "", sortRoleName: "" }
                ]
                onCreateOrEditRequested: {
                    root.manageTokensRequested()
                }
            }

            Item { Layout.fillWidth: true }

            StatusLinkText {
                visible: cmbFilter.hasEnabledFilters
                normalColor: Theme.palette.primaryColor1
                text: qsTr("Clear filter")
                onClicked: cmbFilter.clearFilter()
            }
        }

        StatusDialogDivider {
            Layout.fillWidth: true
        }
    }

    CollectiblesNotSupportedTag {
        id: collectiblesNotSupportedTag

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        visible: unsupportedChainIds.length > 0

        unsupportedChainIds: d.networksCount, d.getUnsupportedChainIds()
    }

    Loader {
        id: banner
        Layout.fillWidth: true
    }

    ShapeRectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.topMargin: Theme.padding
        visible: !d.hasRegularCollectibles && !d.hasCommunityCollectibles
        text: qsTr("Collectibles will appear here")
    }

    DoubleFlickableWithFolding {
        id: doubleFlickable

        Layout.fillWidth: true
        Layout.fillHeight: true

        clip: true

        ScrollBar.vertical: StatusScrollBar {
            policy: ScrollBar.AsNeeded
            visible: resolveVisibility(policy, doubleFlickable.height, doubleFlickable.contentHeight)
        }

        flickable1: CustomGridView {
            id: communityCollectiblesView

            header: d.hasCommunityCollectibles ? communityHeaderComponent : null
            width: doubleFlickable.width
            cellHeight: d.communityCellHeight
            model: d.communityModelWithLoadingItems

            Component {
                id: communityHeaderComponent

                FoldableHeader {
                    height: d.headerHeight
                    width: doubleFlickable.width
                    title: qsTr("Community minted")
                    titleColor: Theme.palette.baseColor1
                    folded: doubleFlickable.flickable1Folded
                    rightAdditionalComponent: StatusFlatButton {
                        icon.name: "info"
                        textColor: Theme.palette.baseColor1

                        onClicked: Global.openPopup(communityInfoPopupCmp)
                    }
                    onToggleFolding:doubleFlickable.flip1Folding()
                }
            }
        }

        flickable2: CustomGridView {
            id: regularCollectiblesView

            header: !d.hasRegularCollectibles || d.onlyRegularCollectiblesType ? null : regularHeaderComponent
            width: doubleFlickable.width
            cellHeight: d.cellHeight
            model: d.nonCommunityModelWithLoadingItems

            Component {
                id: regularHeaderComponent

                FoldableHeader {
                    height: d.headerHeight
                    width: doubleFlickable.width
                    title: qsTr("Others")
                    titleColor: Theme.palette.baseColor1
                    folded: doubleFlickable.flickable2Folded

                    onToggleFolding:doubleFlickable.flip2Folding()
                }
            }
        }
    }

    component CustomGridView: StatusGridView {
        id: gridView

        interactive: false

        cellWidth: d.cellWidth
        delegate: collectibleDelegate
    }

    Component {
        id: collectibleDelegate
        CollectibleView {
            width: d.cellWidth
            height: isCommunityCollectible ? d.communityCellHeight : d.cellHeight
            title: model.name ?? ""
            subTitle: model.collectionName ? model.collectionName : model.collectionUid ? model.collectionUid : ""
            mediaUrl: model.mediaUrl ?? ""
            mediaType: model.mediaType ?? ""
            fallbackImageUrl: model.imageUrl ?? ""
            backgroundColor: model.backgroundColor ? model.backgroundColor : Theme.palette.baseColor5
            isLoading: !!model.isLoading
            privilegesLevel: model.communityPrivilegesLevel ?? Constants.TokenPrivilegesLevel.Community
            ornamentColor: model.communityColor ?? "transparent"
            communityId: model.communityId ?? ""
            communityName: model.communityName ?? ""
            communityImage: model.communityImage ?? ""
            balance: model.balance ?? 1

            onClicked: root.collectibleClicked(model.chainId, model.contractAddress, model.tokenId, model.symbol, model.tokenType, model.communityId ?? "")
            onContextMenuRequested: function(x, y) {
                const userOwnedAddress = d.getFirstUserOwnedAddress(model.ownership)
                tokenContextMenu.createObject(this, {collectionUid: model.collectionUid, key: model.key, symbol: model.symbol, chainId: model.chainId, tokenName: model.name, tokenImage: model.imageUrl,
                                                  communityId: model.communityId, communityName: model.communityName,
                                                  communityImage: model.communityImage, tokenType: model.tokenType,
                                                  soulbound: model.soulbound, userOwnedAddress}).popup(x, y)
            }
            onSwitchToCommunityRequested: (communityId) => root.switchToCommunityRequested(communityId)
        }
    }

    Component {
        id: tokenContextMenu
        StatusMenu {
            id: tokenMenu
            onClosed: destroy()

            property string collectionUid
            property string key
            property string symbol
            property int chainId
            property string tokenName
            property string tokenImage
            property string communityId
            property string communityName
            property string communityImage
            property string userOwnedAddress
            property int tokenType
            property bool ownedByUser: !!userOwnedAddress
            property bool soulbound

            // Show send button for owned collectibles
            // Disable send button for owned soulbound collectibles
            Instantiator {
                model: tokenMenu.ownedByUser ? 1 : 0
                delegate: StatusAction {
                    enabled: root.sendEnabled && !tokenMenu.soulbound
                    visibleOnDisabled: true
                    icon.name: "send"
                    text: qsTr("Send")
                    onTriggered: root.sendRequested(tokenMenu.collectionUid, tokenMenu.tokenType, tokenMenu.userOwnedAddress)
                }
                onObjectAdded: (index, object) => tokenMenu.insertAction(0, object)
                onObjectRemoved: (index, object) => tokenMenu.removeAction(0)
            }

            StatusAction {
                icon.name: "receive"
                text: qsTr("Receive")
                onTriggered: root.receiveRequested(symbol)
            }
            StatusMenuSeparator {}
            StatusAction {
                icon.name: "settings"
                text: qsTr("Manage tokens")
                onTriggered: root.manageTokensRequested()
            }
            StatusAction {
                enabled: symbol !== Utils.getNativeTokenSymbol(chainId)
                type: StatusAction.Type.Danger
                icon.name: "hide"
                text: qsTr("Hide collectible")
                onTriggered: Global.openConfirmHideCollectiblePopup(symbol, tokenName, tokenImage, !!communityId)
            }
            StatusAction {
                enabled: !!communityId
                type: StatusAction.Type.Danger
                icon.name: "hide"
                text: qsTr("Hide all collectibles from this community")
                onTriggered: Global.openPopup(confirmHideCommunityCollectiblesPopup, {communityId, communityName, communityImage})
            }
        }
    }

    Component {
        id: communityInfoPopupCmp
        StatusDialog {
            destroyOnClose: true
            title: qsTr("What are community collectibles?")
            standardButtons: Dialog.Ok
            width: 520
            contentItem: StatusBaseText {
                wrapMode: Text.Wrap
                text: qsTr("Community collectibles are collectibles that have been minted by a community. As these collectibles cannot be verified, always double check their origin and validity before interacting with them. If in doubt, ask a trusted member or admin of the relevant community.")
            }
        }
    }

    Component {
        id: confirmHideCommunityCollectiblesPopup
        ConfirmationDialog {
            property string communityId
            property string communityName
            property string communityImage

            width: 520
            destroyOnClose: true
            confirmButtonLabel: qsTr("Hide '%1' collectibles").arg(communityName)
            cancelBtnType: ""
            showCancelButton: true
            headerSettings.title: qsTr("Hide %1 community collectibles").arg(communityName)
            headerSettings.asset.name: communityImage
            confirmationText: qsTr("Are you sure you want to hide all community collectibles minted by %1? You will no longer see or be able to interact with these collectibles anywhere inside Status.").arg(communityName)
            onCancelButtonClicked: close()
            onConfirmButtonClicked: {
                root.controller.showHideGroup(communityId, false)
                close()
                Global.displayToastMessage(
                            qsTr("%1 community collectibles were successfully hidden. You can toggle collectible visibility via %2.").arg(communityName)
                            .arg(`<a style="text-decoration:none" href="#${Constants.appSection.profile}/${Constants.settingsSubsection.wallet}/${Constants.walletSettingsSubsection.manageCollectibles}">` + qsTr("Settings", "Go to Settings") + "</a>"),
                            "",
                            "checkmark-circle",
                            false,
                            Constants.ephemeralNotificationType.success,
                            ""
                            )
            }
        }
    }
}
