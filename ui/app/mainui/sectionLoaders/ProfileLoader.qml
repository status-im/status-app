import QtQml
import QtQuick

import StatusQ

import utils

import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.Communities.stores
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
    required property ProfileStores.KeycardStore keycardStore
    required property ProfileStores.KeycardNewStore keycardNewStore
    required property ProfileStores.WalletStore walletProfileStore
    required property ProfileStores.EnsUsernamesStore ensUsernamesStore
    required property WalletStores.TokensStore tokensStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property WalletStores.CollectiblesStore walletCollectiblesStore

    required property ContactsModelAdaptor contactsAdaptor
    required property HandlersManagerLoader popupHandler
    required property Loader emojiPopupLoader
    required property Keychain keychain

    // Inputs
    required property bool isProduction
    required property bool systemTrayIconAvailable
    required property int theme
    required property int fontSize
    required property int paddingFactor
    required property var whitelistedDomainsModel

    property int settingsSubsection: -1
    property int settingsSubSubsection: -1
    property real leftPanelWidthOverride: 0
    property bool forceSubsectionNavigation: false

    onSettingsSubsectionChanged: {
        if (root.item && root.item.settingsSubsection !== root.settingsSubsection) {
            root.item.settingsSubsection = root.settingsSubsection
        }
    }

    onSettingsSubSubsectionChanged: {
        if (root.item && root.item.settingsSubSubsection !== root.settingsSubSubsection) {
            root.item.settingsSubSubsection = root.settingsSubSubsection
        }
    }

    onForceSubsectionNavigationChanged: {
        if (root.item && root.item.forceSubsectionNavigation !== root.forceSubsectionNavigation) {
            root.item.forceSubsectionNavigation = root.forceSubsectionNavigation
        }
    }

    Binding {
        when: !!root.item
        root.settingsSubsection: root.item.settingsSubsection
        root.settingsSubSubsection: root.item.settingsSubSubsection
        root.forceSubsectionNavigation: root.item.forceSubsectionNavigation
    }

    // Signals re-emitted so AppMain can mutate appMainLocalSettings / Theme outside the loader
    signal themeChangeRequested(int theme)
    signal fontSizeChangeRequested(int fontSize)
    signal paddingFactorChangeRequested(int paddingFactor)
    signal removeWhitelistedDomainRequested(int index)

    asynchronous: false

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.profileUrl))
        loadSection()
    }

    function loadSection() {
        if (!root.active)
            return
        if (root.source === QmlCompiler.profileUrl)
            return
        setSource(QmlCompiler.profileUrl, {
            visible:                                false,
            isProduction:                           Qt.binding(() => root.isProduction),
            userUID:                                Qt.binding(() => root.profileStore.pubKey),
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
            keycardStore:                           Qt.binding(() => root.keycardStore),
            keycardNewStore:                        Qt.binding(() => root.keycardNewStore),
            walletStore:                            Qt.binding(() => root.walletProfileStore),
            messagingSettingsStore:                 Qt.binding(() => root.messagingSettingsStore),
            ensUsernamesStore:                      Qt.binding(() => root.ensUsernamesStore),
            globalStore:                            Qt.binding(() => root.rootStore),
            communitiesStore:                       Qt.binding(() => root.communitiesStore),
            networkConnectionStore:                 Qt.binding(() => root.networkConnectionStore),
            tokensStore:                            Qt.binding(() => root.tokensStore),
            walletAssetsStore:                      Qt.binding(() => root.walletAssetsStore),
            collectiblesStore:                      Qt.binding(() => root.walletCollectiblesStore),
            currencyStore:                          Qt.binding(() => root.currencyStore),
            networksStore:                          Qt.binding(() => root.networksStore),
            messagingRootStore:                     Qt.binding(() => root.messagingRootStore),
            keychain:                               Qt.binding(() => root.keychain),
            emojiPopup:                             Qt.binding(() => root.emojiPopupLoader.item),
            mutualContactsModel:                    Qt.binding(() => root.contactsAdaptor.mutualContacts),
            blockedContactsModel:                   Qt.binding(() => root.contactsAdaptor.blockedContacts),
            pendingContactsModel:                   Qt.binding(() => root.contactsAdaptor.pendingContacts),
            pendingReceivedContactsCount:           Qt.binding(() => root.contactsAdaptor.pendingReceivedRequestContacts.count),
            dismissedReceivedRequestContactsModel:  Qt.binding(() => root.contactsAdaptor.dimissedReceivedRequestContacts),
            isKeycardEnabled:                       Qt.binding(() => root.featureFlagsStore.keycardEnabled),
            isBrowserEnabled:                       Qt.binding(() => root.featureFlagsStore.browserEnabled),
            privacyModeFeatureEnabled:              Qt.binding(() => root.featureFlagsStore.privacyModeFeatureEnabled),
            minimizeOnCloseOptionVisible:           Qt.binding(() => root.systemTrayIconAvailable),
            theme:                                  Qt.binding(() => root.theme),
            fontSize:                               Qt.binding(() => root.fontSize),
            paddingFactor:                          Qt.binding(() => root.paddingFactor),
            whitelistedDomainsModel:                Qt.binding(() => root.whitelistedDomainsModel),
            leftPanelWidthOverride:                 Qt.binding(() => root.leftPanelWidthOverride),
            settingsSubsection:                     Qt.binding(() => root.settingsSubsection),
            settingsSubSubsection:                  Qt.binding(() => root.settingsSubSubsection),
            forceSubsectionNavigation:              Qt.binding(() => root.forceSubsectionNavigation)
        })
    }

    onActiveChanged: loadSection()
    onLoaded: {
        item.visible = true
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onSettingsSubsectionChanged() {
            root.settingsSubsection = root.item.settingsSubsection
        }
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
        function onFontSizeChangeRequested(fontSize) { root.fontSizeChangeRequested(fontSize) }
        function onPaddingFactorChangeRequested(paddingFactor) { root.paddingFactorChangeRequested(paddingFactor) }
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
