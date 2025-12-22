import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import QtModelsToolkit
import SortFilterProxyModel

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Layout
import StatusQ.Popups.Dialog

import shared.panels
import shared.popups
import shared.stores
import shared.stores.send
import shared.views.chat
import utils

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels
import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers
import AppLayouts.Communities.views

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores

StatusSectionLayout {
    id: root

    property ChatStores.RootStore rootStore
    property var chatCommunitySectionModule
    required property TokensStore tokensStore
    required property ProfileStores.AdvancedStore advancedStore
    required property var community
    required property TransactionStore transactionStore
    property bool communitySettingsDisabled
    required property var activeNetworks

    required property string enabledChainIds

    required property var walletAccountsModel // name, address, emoji, color

    readonly property bool isOwner: community.memberRole === Constants.memberRole.owner
    readonly property bool isAdmin: community.memberRole === Constants.memberRole.admin
    readonly property bool isTokenMasterOwner: community.memberRole === Constants.memberRole.tokenMaster
    readonly property bool isControlNode: community.isControlNode

    property var permissionsModel // holdings, permissionType, isPrivate, channels

    // Settings related:
    property bool ensCommunityPermissionsEnabled

    // Community transfer ownership related props:
    required property bool isPendingOwnershipRequest
    signal finaliseOwnershipClicked

    signal enableNetwork(int chainId)
    signal loadMembersRequested()

    MembersModelAdaptor {
        id: membersModelAdaptor
        allMembers: community.allMembers

        Component.onCompleted: {
            if (!community.membersLoaded) {
                root.loadMembersRequested()
            }
        }
    }

    // Permissions Related requests:
    signal createPermissionRequested(var holdings, int permissionType, bool isPrivate, var channels)
    signal removePermissionRequested(string key)
    signal editPermissionRequested(string key, var holdings, int permissionType, var channels, bool isPrivate)


    // Community access requests:
    signal acceptRequestToJoinCommunityRequested(string requestId, string communityId)
    signal declineRequestToJoinCommunityRequested(string requestId, string communityId)

    readonly property string filteredSelectedTags: {
        let tagsArray = []
        if (community && community.tags) {
            try {
                const json = JSON.parse(community.tags)

                if (!!json)
                    tagsArray = json.map(tag => tag.name)
            } catch (e) {
                console.warn("Error parsing community tags: ", community.tags,
                             " error: ", e.message)
            }
        }
        return JSON.stringify(tagsArray)
    }

    signal backToCommunityClicked

    backButtonName: {
        if (!stackLayout.children[d.currentIndex].item || !stackLayout.children[d.currentIndex].item.previousPageName) {
            return ""
        }
        return stackLayout.children[d.currentIndex].item.previousPageName
    }

    //navigate to a specific section and subsection
    function goTo(section: int, subSection: int) {
        d.goTo(section, subSection)
    }

    onBackButtonClicked: {
        root.rootStore.communityTokensStore.stopUpdatesForSuggestedRoute()
        stackLayout.children[d.currentIndex].item.navigateBack()
    }

    leftPanel: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors {
                top: parent.top
                bottom: backToCommunityButton.top
                bottomMargin: 12
                topMargin: Theme.smallPadding
                horizontalCenter: parent.horizontalCenter
            }
            width: parent.width
            spacing: 32
            clip: true

            StatusChatInfoButton {
                id: communityHeader

                title: community.name
                subTitle: qsTr("%n member(s)", "", root.community.joinedMembersCount || 0)
                asset.name: community.image
                asset.color: community.color
                asset.isImage: true
                Layout.fillWidth: true
                Layout.leftMargin: Theme.halfPadding
                Layout.rightMargin: Theme.halfPadding
                type: StatusChatInfoButton.Type.OneToOneChat
                hoverEnabled: true
                onClicked: root.backToCommunityClicked()
            }

            StatusListView {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Theme.halfPadding
                Layout.rightMargin: Theme.padding
                model: stackLayout.children
                spacing: Theme.halfPadding
                enabled: !root.communitySettingsDisabled

                delegate: StatusNavigationListItem {
                    objectName: "CommunitySettingsView_NavigationListItem_" + model.sectionName
                    width: ListView.view.width
                    title: model.sectionName
                    asset.name: model.sectionIcon
                    selected: d.currentIndex === index && !root.communitySettingsDisabled
                    visible: model.sectionEnabled
                    height: visible ? implicitHeight : 0

                    onClicked: {
                        d.currentIndex = index
                        root.goToNextPanel()
                    }
                }
            }
        }

        StatusBaseText {
            id: backToCommunityButton
            objectName: "communitySettingsBackToCommunityButton"
            anchors {
                bottom: parent.bottom
                bottomMargin: 16
                horizontalCenter: parent.horizontalCenter
            }
            text: "<- " + qsTr("Back to community")
            color: Theme.palette.baseColor1
            font.pixelSize: Theme.primaryTextFontSize
            font.underline: true

            StatusMouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backToCommunityClicked()
                hoverEnabled: true
            }
        }
    }

    centerPanel: StackLayout {
        id: stackLayout

        anchors.fill: parent

        currentIndex: d.currentIndex

        onCurrentIndexChanged: {
            root.rootStore.communityTokensStore.stopUpdatesForSuggestedRoute()
            children[currentIndex].active = true
        }

        // OVERVIEW
        Loader {
            active: true

            readonly property int sectionKey: Constants.CommunitySettingsSections.Overview
            readonly property string sectionName: qsTr("Overview")
            readonly property string sectionIcon: "show"
            readonly property bool sectionEnabled: true

            sourceComponent: OverviewSettingsPanel {
                preferredContentWidth: d.preferredContentWidth
                internalRightPadding: d.internalRightPadding

                isOwner: root.isOwner
                isAdmin: root.isAdmin
                isTokenMaster: root.isTokenMasterOwner
                communityId: root.community.id
                name: root.community.name
                description: root.community.description
                introMessage: root.community.introMessage
                outroMessage: root.community.outroMessage
                logoImageData: root.community.image
                bannerImageData: root.community.bannerImageData
                color: root.community.color
                tags: root.rootStore.communityTags
                selectedTags: root.filteredSelectedTags
                archiveSupportEnabled: root.community.historyArchiveSupportEnabled
                archiveSupporVisible: root.community.isControlNode
                requestToJoinEnabled: root.community.access === Constants.communityChatOnRequestAccess
                pinMessagesEnabled: root.community.pinMessageAllMembersEnabled
                editable: true
                isControlNode: root.isControlNode
                communitySettingsDisabled: root.communitySettingsDisabled
                overviewChartData: rootStore.overviewChartData

                ownerToken: tokensModelChangesTracker.ownerToken

                isPendingOwnershipRequest: root.isPendingOwnershipRequest

                isMobile: StatusQUtils.Utils.isMobile

                onFinaliseOwnershipClicked: root.finaliseOwnershipClicked()

                onCollectCommunityMetricsMessagesCount: intervals => {
                    rootStore.collectCommunityMetricsMessagesCount(intervals)
                }

                onEdited: {
                    // Step 1: Proceed with community creation
                    const error = root.chatCommunitySectionModule.editCommunity(
                                    StatusQUtils.Utils.filterXSS(item.name),
                                    StatusQUtils.Utils.filterXSS(item.description),
                                    StatusQUtils.Utils.filterXSS(item.introMessage),
                                    StatusQUtils.Utils.filterXSS(item.outroMessage),
                                    item.options.requestToJoinEnabled ? Constants.communityChatOnRequestAccess
                                                                      : Constants.communityChatPublicAccess,
                                    item.color.toString().toUpperCase(),
                                    item.selectedTags,
                                    Utils.getImageAndCropInfoJson(item.logoImagePath, item.logoCropRect),
                                    Utils.getImageAndCropInfoJson(item.bannerPath, item.bannerCropRect),
                                    item.options.archiveSupportEnabled,
                                    item.options.pinMessagesEnabled
                                    )
                    if (error) {
                        errorDialog.text = error.error
                        errorDialog.open()
                    }
                    // Step 2: Automatically set the archive protocol global property if it's been checked as
                    // an option during community creation process. It's a more user friendly process
                    else if(item.options.archiveSupportEnabled) {
                        root.advancedStore.enableArchiveProtocolProperty()
                    }
                    
                }

                onAirdropTokensClicked: root.goTo(Constants.CommunitySettingsSections.Airdrops)
                onExportControlNodeClicked: {
                    if(!root.isControlNode)
                        return

                    Global.openExportControlNodePopup(root.community)
                }

                onImportControlNodeClicked: {
                    if(root.isControlNode)
                        return

                    Global.openImportControlNodePopup(root.community)
                }

                onMintOwnerTokenClicked: {
                    root.goTo(Constants.CommunitySettingsSections.MintTokens)
                    mintPanelLoader.item.openNewTokenForm(false/*Collectible owner token*/)
                }
            }
        }

        // MEMBERS
        Loader {
            active: false

            readonly property int sectionKey: Constants.CommunitySettingsSections.Members
            readonly property string sectionName: qsTr("Members")
            readonly property string sectionIcon: "group-chat"
            readonly property bool sectionEnabled: true

            sourceComponent: MembersSettingsPanel {
                rootStore: root.rootStore

                preferredHeaderContentWidth: d.preferredContentWidth
                preferredContentWidth: d.preferredContentWidth
                internalRightPadding: d.internalRightPadding

                membersModel: membersModelAdaptor.joinedMembers
                bannedMembersModel: membersModelAdaptor.bannedMembers
                pendingMembersModel: membersModelAdaptor.pendingMembers
                declinedMembersModel: membersModelAdaptor.declinedMembers

                editable: root.isAdmin || root.isOwner || root.isTokenMasterOwner
                memberRole: root.community.memberRole
                communityName: root.community.name

                onKickUserClicked: root.rootStore.removeUserFromCommunity(id)
                onBanUserClicked: root.rootStore.banUserFromCommunity(id, deleteAllMessages)
                onUnbanUserClicked: root.rootStore.unbanUserFromCommunity(id)
                onAcceptRequestToJoin: root.acceptRequestToJoinCommunityRequested(id, root.community.id)
                onDeclineRequestToJoin: root.declineRequestToJoinCommunityRequested(id, root.community.id)
                onViewMemberMessagesClicked: {
                    root.rootStore.loadCommunityMemberMessages(root.community.id, pubKey)
                    Global.openCommunityMemberMessagesPopupRequested(root.rootStore, root.chatCommunitySectionModule, pubKey, displayName)
                }
                onInviteNewPeopleClicked: Global.openInviteFriendsToCommunityPopup(root.community, root.chatCommunitySectionModule, null)
            }
        }

        // PERMISISONS
        Loader {
            id: permissionsSettingsPanelLoader
            active: false
            readonly property int sectionKey: Constants.CommunitySettingsSections.Permissions
            readonly property string sectionName: qsTr("Permissions")
            readonly property string sectionIcon: "objects"
            readonly property bool sectionEnabled: true
        
            sourceComponent: PermissionsSettingsPanel {
                permissionsModel: root.permissionsModel

                // by design
                preferredContentWidth: d.preferredContentWidth
                internalRightPadding: d.internalRightPadding

                // temporary solution to provide icons for assets, similar
                // method is used in wallet (constructing filename from asset's
                // symbol) and is intended to be replaced by more robust
                // solution soon.

                assetsModel: rootStore.assetsModel

                collectiblesModel: rootStore.collectiblesModel
                channelsModel: rootStore.chatCommunitySectionModule.model
                
                saveInProgress: rootStore.chatCommunitySectionModule.permissionSaveInProgress
                errorSaving: rootStore.chatCommunitySectionModule.errorSavingPermission

                getTokenByKeyOrGroupKeyFromAllTokens: root.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens

                ensCommunityPermissionsEnabled: root.ensCommunityPermissionsEnabled

                communityDetails: d.communityDetails

                onCreatePermissionRequested: (permissionType, holdings, channels, isPrivate) =>
                    root.createPermissionRequested(holdings, permissionType, isPrivate, channels)

                onUpdatePermissionRequested: (key, permissionType, holdings, channels, isPrivate) =>
                    root.editPermissionRequested(key, holdings, permissionType, channels, isPrivate)

                onRemovePermissionRequested: (key) =>
                    root.removePermissionRequested(key)

                onNavigateToMintTokenSettings: (isAssetType) => {
                    root.goTo(Constants.CommunitySettingsSections.MintTokens)
                    mintPanelLoader.item.openNewTokenForm(isAssetType)
                }
            }
        }

        // TOKEN
        Loader {
            id: mintPanelLoader
            active: false
            readonly property int sectionKey: Constants.CommunitySettingsSections.MintTokens
            readonly property string sectionName: qsTr("Tokens")
            readonly property string sectionIcon: "token"
            readonly property bool sectionEnabled: true

            sourceComponent: MintTokensSettingsPanel {
                id: mintTokensSettingsPanel

                // by design
                preferredContentWidth: d.preferredContentWidth
                internalRightPadding: d.internalRightPadding

                enabledChainIds: root.enabledChainIds

                readonly property CommunityTokensStore communityTokensStore:
                    rootStore.communityTokensStore

                // General community props
                communityId: root.community.id
                communityName: root.community.name
                communityLogo: root.community.image
                communityColor: root.community.color
                tokensLoading: root.community.tokensLoading

                // User profile props
                isOwner: root.isOwner
                isAdmin: root.isAdmin
                isTokenMasterOwner: root.isTokenMasterOwner

                // Owner and TMaster properties
                isOwnerTokenDeployed: tokensModelChangesTracker.isOwnerTokenDeployed
                isTMasterTokenDeployed: tokensModelChangesTracker.isTMasterTokenDeployed
                anyPrivilegedTokenFailed: tokensModelChangesTracker.isOwnerTokenFailed || tokensModelChangesTracker.isTMasterTokenFailed
                ownerOrTMasterTokenItemsExist: tokensModelChangesTracker.ownerOrTMasterTokenItemsExist

                // Models
                tokensModel: root.community.communityTokens
                membersModel: membersModelAdaptor.joinedMembers
                flatNetworks: root.activeNetworks
                accounts: root.walletAccountsModel
                referenceTokenGroupsModel: root.tokensStore.tokenGroupsModel

                onStopUpdatingFees: {
                    communityTokensStore.stopUpdatesForSuggestedRoute()
                }

                onRegisterDeployFeesSubscriber: {
                    d.feesBroker.registerDeployFeesSubscriber(feeSubscriber)
                }

                onRegisterSelfDestructFeesSubscriber: {
                    d.feesBroker.registerSelfDestructFeesSubscriber(feeSubscriber)
                }

                onRegisterBurnTokenFeesSubscriber: {
                    d.feesBroker.registerBurnFeesSubscriber(feeSubscriber)
                }

                onStartTokenHoldersManagement: {
                    communityTokensStore.startTokenHoldersManagement(root.community.id, chainId, address)
                }

                onStopTokenHoldersManagement: {
                    communityTokensStore.stopTokenHoldersManagement()
                }

                onEnableNetwork: root.enableNetwork(chainId)

                onMintCollectible: {
                    communityTokensStore.authenticateAndTransfer()
                }

                onMintAsset: {

                    communityTokensStore.authenticateAndTransfer()
                }

                onMintOwnerToken: {
                    communityTokensStore.authenticateAndTransfer()
                }

                onRemotelyDestructCollectibles: {
                    communityTokensStore.authenticateAndTransfer()
                }

                onRemotelyDestructAndBan: {

                    communityTokensStore.remotelyDestructAndBan(
                        root.community.id, contactId, tokenKey, accountAddress)
                }

                onRemotelyDestructAndKick: {

                    communityTokensStore.remotelyDestructAndKick(
                        root.community.id, contactId, tokenKey, accountAddress)
                }

                onBurnToken: {

                    communityTokensStore.authenticateAndTransfer()
                }

                onDeleteToken: {

                    communityTokensStore.deleteToken(root.community.id, tokenKey)
                }

                onRefreshToken: {

                    communityTokensStore.refreshToken(tokenKey)
                }

                onAirdropToken: {
                    root.goTo(Constants.CommunitySettingsSections.Airdrops)

                    // Force a token selection to be airdroped with given amount
                    airdropPanelLoader.item.selectToken(tokenKey, amount, type)

                    // Set given addresses as recipients
                    airdropPanelLoader.item.addAddresses(addresses)
                }

                onKickUserRequested: {
                    root.rootStore.removeUserFromCommunity(contactId)
                }

                onBanUserRequested: {
                    root.rootStore.banUserFromCommunity(contactId)
                }
            }
        }

        // AIRDROPS
        Loader {
            id: airdropPanelLoader
            active: false

            readonly property int sectionKey: Constants.CommunitySettingsSections.Airdrops
            readonly property string sectionName: qsTr("Airdrops")
            readonly property string sectionIcon: "airdrop"
            readonly property bool sectionEnabled: true

            sourceComponent: AirdropsSettingsPanel {
                id: airdropsSettingsPanel

                // by design
                preferredContentWidth: d.preferredContentWidth
                internalRightPadding: d.internalRightPadding

                communityDetails: d.communityDetails

                // Profile type
                isOwner: root.isOwner
                isTokenMasterOwner: root.isTokenMasterOwner
                isAdmin: root.isAdmin

                // Owner and TMaster properties
                isOwnerTokenDeployed: tokensModelChangesTracker.isOwnerTokenDeployed
                isTMasterTokenDeployed: tokensModelChangesTracker.isTMasterTokenDeployed
                tokensLoading: root.community.tokensLoading

                readonly property CommunityTokensStore communityTokensStore:
                    rootStore.communityTokensStore

                RolesRenamingModel {
                    id: renamedTokensBySymbolModel

                    sourceModel: root.community.communityTokens || null
                    mapping: [
                        RoleRename {
                            from: "symbol"
                            to: "key"
                        },
                        RoleRename {
                            from: "image"
                            to: "iconSource"
                        }
                    ]
                }

                assetsModel: SortFilterProxyModel {
                    sourceModel: renamedTokensBySymbolModel
                    filters: ValueFilter {
                        roleName: "tokenType"
                        value: Constants.TokenType.ERC20
                    }
                    proxyRoles: [
                        ConstantRole {
                            name: "category"
                            value: TokenCategories.Category.Own
                        },
                        ConstantRole {
                            name: "communityId"
                            value: ""
                        }
                    ]
                }
                collectiblesModel: SortFilterProxyModel {
                    sourceModel: renamedTokensBySymbolModel
                    filters: [
                        ValueFilter {
                            roleName: "tokenType"
                            value: Constants.TokenType.ERC721
                        },
                        AnyOf {
                            ValueFilter {
                                roleName: "privilegesLevel"
                                value: Constants.TokenPrivilegesLevel.Community
                            }
                            ValueFilter {
                                roleName: "privilegesLevel"
                                value: Constants.TokenPrivilegesLevel.TMaster
                                enabled: root.isOwner
                            }
                        }
                    ]
                    proxyRoles: [
                        ConstantRole {
                            name: "category"
                            value: TokenCategories.Category.Own
                        },
                        ConstantRole {
                            name: "communityId"
                            value: ""
                        }
                    ]
                }




                membersModel: membersModelAdaptor.joinedMembers
                enabledChainIds: root.enabledChainIds
                onEnableNetwork: root.enableNetwork(chainId)

                accountsModel: root.walletAccountsModel
                onAirdropClicked: {
                    communityTokensStore.authenticateAndTransfer()
                }

                onNavigateToMintTokenSettings: {
                    root.goTo(Constants.CommunitySettingsSections.MintTokens)
                    mintPanelLoader.item.openNewTokenForm(isAssetType)
                }

                onStopUpdatingFees: {
                    communityTokensStore.stopUpdatesForSuggestedRoute()
                }

                onRegisterAirdropFeeSubscriber: {
                    d.feesBroker.registerAirdropFeesSubscriber(feeSubscriber)
                }
            }
        }
    }

    QtObject {
        id: d

        readonly property int preferredContentWidth: 560 // by design
        readonly property int internalRightPadding: Theme.xlPadding * 2

        property int currentIndex: 0

        readonly property QtObject communityDetails: QtObject {
            readonly property string id: root.community.id
            readonly property string name: root.community.name
            readonly property string image: root.community.image
            readonly property string color: root.community.color
            readonly property bool owner: root.community.memberRole === Constants.memberRole.owner
            readonly property bool admin: root.community.memberRole === Constants.memberRole.admin
            readonly property bool tokenMaster: root.community.memberRole === Constants.memberRole.tokenMaster
        }

        readonly property TransactionFeesBroker feesBroker: TransactionFeesBroker {
            communityTokensStore: root.rootStore.communityTokensStore
            active: root.Window.window.active
        }

        function goTo(section: int, subSection: int) {
            const stackContent = stackLayout.children

            for (let i = 0; stackContent.length; i++) {
                const item = stackContent[i]

                if (item.sectionKey === section) {
                    d.currentIndex = i

                    if(item.goTo)
                        item.goTo(subSection)

                    break
                }
            }
        }
    }

    StatusQUtils.ModelChangeTracker {
        id: tokensModelChangesTracker

        Component.onCompleted: {
            updateOwnerAndTMasterProperties()
        }

        // Owner and TMaster token deployment states
        property bool isOwnerTokenDeployed: false
        property bool isTMasterTokenDeployed: false
        property bool isOwnerTokenFailed: false
        property bool isTMasterTokenFailed: false
        property var ownerToken: null

        // It will monitorize if Owner and/or TMaster token items are included in the `model` despite the deployment state
        property bool ownerOrTMasterTokenItemsExist: false

        function checkIfPrivilegedTokenItemsExist() {
           return StatusQUtils.ModelUtils.contains(model, "privilegesLevel", Constants.TokenPrivilegesLevel.Owner) ||
                  StatusQUtils.ModelUtils.contains(model, "privilegesLevel", Constants.TokenPrivilegesLevel.TMaster)
        }

        function updateOwnerAndTMasterProperties() {
            // It will update property to know if Owner and TMaster token items have been added into the tokens list.
            ownerOrTMasterTokenItemsExist = checkIfPrivilegedTokenItemsExist()
            if(!ownerOrTMasterTokenItemsExist)
                return
            // It monitors the deployment:
            if(!isOwnerTokenDeployed) {
                isOwnerTokenDeployed = reviewTokenDeployState(true, Constants.ContractTransactionStatus.Completed)
                isOwnerTokenFailed = reviewTokenDeployState(true, Constants.ContractTransactionStatus.Failed)
            }

            if(!isTMasterTokenDeployed) {
                isTMasterTokenDeployed = reviewTokenDeployState(false, Constants.ContractTransactionStatus.Completed)
                isTMasterTokenFailed = reviewTokenDeployState(false, Constants.ContractTransactionStatus.Failed)
            }

            // Not necessary to track more changes since privileged tokens have been correctly deployed.
            if(isOwnerTokenDeployed && isTMasterTokenDeployed) {
                tokensModelChangesTracker.ownerToken = StatusQUtils.ModelUtils.getByKey(model, "privilegesLevel", Constants.TokenPrivilegesLevel.Owner)
                tokensModelChangesTracker.enabled = false
            }
        }

        function reviewTokenDeployState(isOwner, deployState) {
            const privileges = isOwner ? Constants.TokenPrivilegesLevel.Owner : Constants.TokenPrivilegesLevel.TMaster
            const index = StatusQUtils.ModelUtils.indexOf(model, "privilegesLevel", privileges)
            if(index === -1)
                return false

            const token = StatusQUtils.ModelUtils.get(model, index)
            // Some assertions:
            if(isOwner && token.privilegesLevel !== Constants.TokenPrivilegesLevel.Owner)
                return false
            if(!isOwner && token.privilegesLevel !== Constants.TokenPrivilegesLevel.TMaster)
                return false

            // Deploy state check:
            return token.deployState === deployState
        }

        model: root.community.communityTokens

        onRevisionChanged: {
            updateOwnerAndTMasterProperties()
        }
    }

    StatusMessageDialog {
        id: errorDialog

        title: qsTr("Error editing the community")
        icon: StatusMessageDialog.StandardIcon.Critical
    }

    Component {
        id: noPermissionsPopupCmp

        NoPermissionsToJoinPopup {
            onRejectButtonClicked: {
                root.declineRequestToJoinCommunityRequested(requestId, communityId)
                close()
            }
            onClosed: destroy()
        }
    }

    Connections {
        target: root.chatCommunitySectionModule

        function onOpenNoPermissionsToJoinPopup(communityName: string,
                                                userName: string, communityId:
                                                string, requestId: string) {
            const properties = {
                communityName: communityName,
                userName: userName,
                communityId: communityId,
                requestId: requestId
            }

            Global.openPopup(noPermissionsPopupCmp, properties)
        }

        function onPermissionSavedSuccessfully() {
            if (!permissionsSettingsPanelLoader.active) {
                return 
            }
            permissionsSettingsPanelLoader.item.permissionSavedSuccessfully()
        }
    }
}
