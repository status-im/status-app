import QtQml
import QtQuick

import mainui.sectionLoaders

import utils

import shared.stores as SharedStores
import shared.stores.send as SendStores

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStore
import AppLayouts.stores.Messaging.Community as CommunityStores

StatusSectionLoader {
    id: root

    required property ChatStores.RootStore rootStore
    required property CommunitiesStores.CommunitiesStore communitiesStore
    required property SharedStores.NetworksStore networksStore
    required property WalletStore.TokensStore tokensStore
    required property SendStores.TransactionStore transactionStore
    required property ProfileStores.AdvancedStore advancedStore
    required property CommunityStores.CommunityAccessStore communityAccessStore
    required property CommunityStores.PermissionsStore communityPermissionsStore

    required property bool isPendingOwnershipRequest
    required property var sectionItemModel
    required property bool communitySettingsDisabled
    // The admin members (requests to join, bans) are held only while settings show
    required property bool settingsShown

    // Re-emitted because ChatLayout owns its StackLayout's currentIndex.
    signal backToCommunityClicked()

    asynchronous: false

    QtObject {
        id: d
        readonly property url url: Qt.resolvedUrl("../Communities/views/CommunitySettingsView.qml")

        // token details and revealed accounts are fetched on the first show only
        property bool membersLoaded: false

        function updateAdminMembers() {
            if (!root.sectionItemModel)
                return
            const sectionId = root.sectionItemModel.id
            if (!root.active || !root.settingsShown) {
                root.rootStore.releaseAdminMembersForSectionId(sectionId)
            } else if (membersLoaded) {
                root.rootStore.loadAdminMembersForSectionId(sectionId)
            } else {
                membersLoaded = true
                root.rootStore.loadMembersForSectionId(sectionId)
            }
        }
    }

    function loadSection() {
        if (!active)
            return
        if (root.source === d.url)
            return
        setSource(d.url, {
            visible:                        false,
            userUID:                        root.userUID,
            sectionName:                    root.sectionName,
            rootStore:                      Qt.binding(() => root.rootStore),
            communitiesStore:               Qt.binding(() => root.communitiesStore),
            walletAccountsModel:            Qt.binding(() => WalletStore.RootStore.nonWatchAccounts),
            enabledChainIds:                Qt.binding(() => root.networksStore.networkFilters),
            activeNetworks:                 Qt.binding(() => root.networksStore.activeNetworks),
            tokensStore:                    Qt.binding(() => root.tokensStore),
            transactionStore:               Qt.binding(() => root.transactionStore),
            advancedStore:                  Qt.binding(() => root.advancedStore),
            isPendingOwnershipRequest:      Qt.binding(() => root.isPendingOwnershipRequest),
            ensCommunityPermissionsEnabled: Qt.binding(() => root.advancedStore.ensCommunityPermissionsEnabled),
            chatCommunitySectionModule:     Qt.binding(() => root.rootStore.chatCommunitySectionModule),
            community:                      Qt.binding(() => root.sectionItemModel),
            communitySettingsDisabled:      Qt.binding(() => root.communitySettingsDisabled),
            permissionsModel:               Qt.binding(() => root.communityPermissionsStore.permissionsModel),
            leftPanelWidthOverride:         Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onActiveChanged: {
        loadSection()
        d.updateAdminMembers()
    }
    onSettingsShownChanged: d.updateAdminMembers()
    Component.onCompleted: {
        loadSection()
        if (root.active && root.settingsShown)
            d.updateAdminMembers()
    }
    onLoaded: item.visible = true

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onBackToCommunityClicked() { root.backToCommunityClicked() }

        function onEnableNetwork(chainId) {
            root.networksStore.enableNetwork(chainId)
        }
        function onCreatePermissionRequested(holdings, permissionType, isPrivate, channels) {
            root.communityPermissionsStore.createPermission(holdings, permissionType, isPrivate, channels)
        }
        function onRemovePermissionRequested(key) {
            root.communityPermissionsStore.removePermission(key)
        }
        function onEditPermissionRequested(key, holdings, permissionType, channels, isPrivate) {
            root.communityPermissionsStore.editPermission(key, holdings, permissionType, channels, isPrivate)
        }
        function onAcceptRequestToJoinCommunityRequested(requestId, communityId) {
            root.communityAccessStore.acceptRequestToJoinCommunityRequested(requestId, communityId)
        }
        function onDeclineRequestToJoinCommunityRequested(requestId, communityId) {
            root.communityAccessStore.declineRequestToJoinCommunityRequested(requestId, communityId)
        }
        function onFinaliseOwnershipClicked() {
            Global.openFinaliseOwnershipPopup(root.sectionItemModel.id)
        }
        function onCommunitySettingsDisabledChanged() {
            if (root.item.communitySettingsDisabled)
                root.item.goTo(Constants.CommunitySettingsSections.Overview)
        }
    }
}
