import QtQml
import QtQuick

import StatusQ

import utils

import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.Communities.stores
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.adaptors
import mainui.sectionLoaders

Loader {
    id: root

    // Stores
    required property AppStores.RootStore rootStore
    required property AppStores.ContactsStore contactsStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property SharedStores.RootStore sharedRootStore
    required property SharedStores.UtilsStore utilsStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.CurrenciesStore currencyStore
    required property CommunitiesStore communitiesStore
    required property MessagingStores.MessagingRootStore messagingRootStore
    required property MessagingStores.MessagingSettingsStore messagingSettingsStore
    required property ProfileStores.AboutStore aboutStore
    required property ProfileStores.ProfileStore profileStore
    required property ProfileStores.DevicesStore devicesStore
    required property ProfileStores.AdvancedStore advancedStore
    required property ProfileStores.PrivacyStore privacyStore
    required property ProfileStores.NotificationsStore notificationsStore
    required property ProfileStores.LanguageStore languageStore
    required property ProfileStores.KeycardNewStore keycardNewStore
    required property ProfileStores.LogosNetworkStore logosNetworkStore
    required property ProfileStores.WalletStore walletProfileStore
    required property ProfileStores.EnsUsernamesStore ensUsernamesStore
    required property WalletStores.TokensStore tokensStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property WalletStores.CollectiblesStore walletCollectiblesStore
    required property BrowserStores.BrowserPreferencesStore browserPreferencesStore

    required property ContactsModelAdaptor contactsAdaptor
    required property HandlersManagerLoader popupHandler
    required property Loader emojiPopupLoader
    required property Keychain keychain

    // Inputs
    required property string userUID
    required property bool isProduction
    required property bool isPortraitMode
    required property bool systemTrayIconAvailable
    required property int theme
    required property var whitelistedDomainsModel
    required property real nativeWindowDpr // baseline/native DPR of the respective Screen
    required property int syncingBadgeCount

    property int settingsSubsection: isPortraitMode ? -1 : Constants.settingsSubsection.profile // load and select Profile on desktop; nothing on mobile, just the left panel list
    property int settingsSubSubsection: -1
    property real leftPanelWidthOverride: 0

    function forceSubsectionNavigation() {
        if (root.item && root.item.forceSubsectionNavigation) {
            root.item.forceSubsectionNavigation()
        }
    }

    // Signals re-emitted so AppMain can mutate appMainLocalSettings / Theme outside the loader
    signal themeChangeRequested(int theme)
    signal removeWhitelistedDomainRequested(int index)

    asynchronous: false

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.profileUrl))
        loadSection()
    }

    function loadSection() {
        if (!root.active)
            return
        if (!!root.item)
            return
        if (root.source === QmlCompiler.profileUrl)
            return
        setSource(QmlCompiler.profileUrl, {
            visible:                                false,
            isProduction:                           root.isProduction,
            userUID:                                root.userUID,
            sharedRootStore:                        Qt.binding(() => root.sharedRootStore),
            utilsStore:                             Qt.binding(() => root.utilsStore),
            aboutStore:                             Qt.binding(() => root.aboutStore),
            profileStore:                           Qt.binding(() => root.profileStore),
            contactsStore:                          Qt.binding(() => root.contactsStore),
            devicesStore:                           Qt.binding(() => root.devicesStore),
            advancedStore:                          Qt.binding(() => root.advancedStore),
            privacyStore:                           Qt.binding(() => root.privacyStore),
            notificationsStore:                     Qt.binding(() => root.notificationsStore),
            languageStore:                          Qt.binding(() => root.languageStore),
            keycardNewStore:                        Qt.binding(() => root.keycardNewStore),
            logosNetworkStore:                      Qt.binding(() => root.logosNetworkStore),
            walletStore:                            Qt.binding(() => root.walletProfileStore),
            messagingSettingsStore:                 Qt.binding(() => root.messagingSettingsStore),
            ensUsernamesStore:                      Qt.binding(() => root.ensUsernamesStore),
            globalStore:                            Qt.binding(() => root.rootStore),
            communitiesStore:                       Qt.binding(() => root.communitiesStore),
            networkConnectionStore:                 Qt.binding(() => root.networkConnectionStore),
            tokensStore:                            Qt.binding(() => root.tokensStore),
            walletAssetsStore:                      Qt.binding(() => root.walletAssetsStore),
            collectiblesStore:                      Qt.binding(() => root.walletCollectiblesStore),
            browserPreferencesStore:                Qt.binding(() => root.browserPreferencesStore),
            currencyStore:                          Qt.binding(() => root.currencyStore),
            networksStore:                          Qt.binding(() => root.networksStore),
            messagingRootStore:                     Qt.binding(() => root.messagingRootStore),
            keychain:                               root.keychain,
            emojiPopup:                             root.emojiPopupLoader.item,
            mutualContactsModel:                    root.contactsAdaptor.mutualContacts,
            blockedContactsModel:                   root.contactsAdaptor.blockedContacts,
            pendingContactsModel:                   root.contactsAdaptor.pendingContacts,
            pendingReceivedContactsCount:           Qt.binding(() => root.contactsAdaptor.pendingReceivedRequestContacts.count),
            dismissedReceivedRequestContactsModel:  root.contactsAdaptor.dismissedReceivedRequestContacts,
            isKeycardEnabled:                       Qt.binding(() => root.featureFlagsStore.keycardEnabled),
            isBrowserEnabled:                       Qt.binding(() => root.featureFlagsStore.browserEnabled),
            messageLinkSharingFeatureEnabled:       Qt.binding(() => root.featureFlagsStore.messageLinkSharingEnabled),
            privacyModeFeatureEnabled:              Qt.binding(() => root.featureFlagsStore.privacyModeFeatureEnabled),
            minimizeOnCloseOptionVisible:           Qt.binding(() => root.systemTrayIconAvailable),
            theme:                                  Qt.binding(() => root.theme),
            nativeWindowDpr:                        Qt.binding(() => root.nativeWindowDpr),
            syncingBadgeCount:                      Qt.binding(() => root.syncingBadgeCount),
            whitelistedDomainsModel:                Qt.binding(() => root.whitelistedDomainsModel),
            leftPanelWidthOverride:                 Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onActiveChanged: {
        if (active)
            loadSection()
        else {
            // reinit the bindings from scratch when unloading
            root.settingsSubsection = Qt.binding(() => root.isPortraitMode ? -1 : Constants.settingsSubsection.profile)
            root.settingsSubSubsection = -1
        }
    }
    onLoaded: {
        // late bindings in order to re-eval when invoking Settings from outside
        item.settingsSubsection = Qt.binding(() => root.settingsSubsection)
        item.settingsSubSubsection = Qt.binding(() => root.settingsSubSubsection)
        item.visible = true
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onAddressWasShownRequested(address) {
            WalletStores.RootStore.addressWasShown(address)
        }
        function onConnectUsernameRequested(ensName, ownerAddress) {
            root.popupHandler.connectUsername(ensName, ownerAddress)
        }
        function onRegisterUsernameRequested(ensName, chainId) {
            root.popupHandler.registerUsername(ensName, chainId)
        }
        function onReleaseUsernameRequested(ensName, senderAddress, chainId) {
            root.popupHandler.releaseUsername(ensName, senderAddress, chainId)
        }
        function onThemeChangeRequested(theme) { root.themeChangeRequested(theme) }
        function onLeaveCommunityRequest(communityId) {
            root.communitiesStore.leaveCommunity(communityId)
        }
        function onSetCommunityMutedRequest(communityId, mutedType) {
            root.communitiesStore.setCommunityMuted(communityId, mutedType)
        }
        function onInviteFriends(communityData) {
            Global.openInviteFriendsToCommunityByIdPopup(communityData.id, null)
        }
        function onOpenThirdpartyServicesInfoPopupRequested() {
            root.popupHandler.openThirdpartyServicesPopup()
        }
        function onOpenDiscussPageRequested() {
            Global.requestOpenLink(Constants.statusDiscussPageUrl)
        }
        function onRemoveWhitelistedDomain(index) { root.removeWhitelistedDomainRequested(index) }
    }
}
