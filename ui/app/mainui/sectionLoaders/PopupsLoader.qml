import QtQml
import QtQuick

import StatusQ

import shared.stores

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.stores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores.Messaging as MessagingStores

import utils

Loader {
    id: root

    required property Item popupParent
    required property Keychain keychain
    required property RootStore sharedRootStore
    required property AppLayoutStores.RootStore rootStore
    required property CommunityTokensStore communityTokensStore
    required property NetworksStore networksStore

    property AppLayoutStores.ContactsStore contactsStore
    property AppLayoutStores.ActivityCenterStore activityCenterStore
    property ChatStores.RootStore chatStore
    property UtilsStore utilsStore
    property CommunitiesStore communitiesStore
    property ProfileStores.ProfileStore profileStore
    property ProfileStores.DevicesStore devicesStore
    property CurrenciesStore currencyStore
    property WalletStores.WalletAssetsStore walletAssetsStore
    property WalletStores.CollectiblesStore walletCollectiblesStore
    property NetworkConnectionStore networkConnectionStore
    property WalletStores.BuyCryptoStore buyCryptoStore
    property ProfileStores.AdvancedStore advancedStore
    property ProfileStores.AboutStore aboutStore
    property ProfileStores.PrivacyStore privacyStore
    property MessagingStores.MessagingRootStore messagingRootStore

    property var emojiPopup: null
    property var allContactsModel
    property var mutualContactsModel
    property bool isDevBuild

    // Signals re-emitted from the loaded Popups instance (see Popups.qml lines 95–100).
    signal openExternalLink(string link)
    signal saveDomainToUnfurledWhitelist(string domain)
    signal ownershipDeclined(string communityId, string communityName)
    signal transferOwnershipRequested(string tokenId, string senderAddress)
    signal wcUriScanned(string uri)
    signal navigationEducationDialogSeenRequested()

    asynchronous: true
    active: false

    QtObject {
        id: d

        property var pending: []
        property bool sourceSet: false

        function flushPending() {
            const calls = pending
            pending = []
            for (let i = 0; i < calls.length; ++i)
                calls[i]()
        }
    }

    function loadSection() {
        if (!root.active)
            return
        if (d.sourceSet)
            return
        d.sourceSet = true
        setSource(QmlCompiler.popupsUrl, {
            popupParent:            Qt.binding(() => root.popupParent),
            keychain:               Qt.binding(() => root.keychain),
            sharedRootStore:        Qt.binding(() => root.sharedRootStore),
            rootStore:              Qt.binding(() => root.rootStore),
            communityTokensStore:   Qt.binding(() => root.communityTokensStore),
            networksStore:          Qt.binding(() => root.networksStore),
            contactsStore:          Qt.binding(() => root.contactsStore),
            activityCenterStore:    Qt.binding(() => root.activityCenterStore),
            chatStore:              Qt.binding(() => root.chatStore),
            utilsStore:             Qt.binding(() => root.utilsStore),
            communitiesStore:       Qt.binding(() => root.communitiesStore),
            profileStore:           Qt.binding(() => root.profileStore),
            devicesStore:           Qt.binding(() => root.devicesStore),
            currencyStore:          Qt.binding(() => root.currencyStore),
            walletAssetsStore:      Qt.binding(() => root.walletAssetsStore),
            walletCollectiblesStore:Qt.binding(() => root.walletCollectiblesStore),
            networkConnectionStore: Qt.binding(() => root.networkConnectionStore),
            buyCryptoStore:         Qt.binding(() => root.buyCryptoStore),
            advancedStore:          Qt.binding(() => root.advancedStore),
            aboutStore:             Qt.binding(() => root.aboutStore),
            privacyStore:           Qt.binding(() => root.privacyStore),
            messagingRootStore:     Qt.binding(() => root.messagingRootStore),
            emojiPopup:             Qt.binding(() => root.emojiPopup),
            allContactsModel:       Qt.binding(() => root.allContactsModel),
            mutualContactsModel:    Qt.binding(() => root.mutualContactsModel),
            isDevBuild:             Qt.binding(() => root.isDevBuild),
        })
    }

    // Triggers Popups.qml to load , then either runs `callable` immediately
    // (if Popups is already loaded) or queues it to run when async load completes.
    // Callers pass a closure that performs the actual popup invocation, e.g.
    //     invoke(() => root.item.openInfoPopup(title, message))
    // This keeps the popup call refactor-safe (no string method names) and preserves
    // argument types via JS lexical capture.
    function invoke(callable) {
        if (!!root.item) {
            callable()
            return
        }
        if (root.active == false) {
            root.active = true
        }
        d.pending.push(callable)
        loadSection()
    }

    onLoaded: d.flushPending()

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.popupsUrl))
    }

    // Direct entry points used by AppMain.qml. Other popup paths route via Global signals
    // (declared in the Connections block below).
    function openProfilePopup(publicKey, parentPopup, cb) {
        invoke(() => root.item.openProfilePopup(publicKey, parentPopup, cb))
    }
    function openConfirmExternalLinkPopup(link, domain) {
        invoke(() => root.item.openConfirmExternalLinkPopup(link, domain))
    }
    function openBackUpSeedPopup() {
        invoke(() => root.item.openBackUpSeedPopup())
    }
    function openDiscordImportProgressPopup(importingSingleChannel) {
        invoke(() => root.item.openDiscordImportProgressPopup(importingSingleChannel))
    }
    function openInviteFriendsToCommunityPopup(community, communitySectionModule, cb) {
        invoke(() => root.item.openInviteFriendsToCommunityPopup(community, communitySectionModule, cb))
    }
    function openCommunityProfilePopup(store, community, communitySectionModule) {
        invoke(() => root.item.openCommunityProfilePopup(store, community, communitySectionModule))
    }
    function openCommunityRulesPopup(name, introMessage, image, color) {
        invoke(() => root.item.openCommunityRulesPopup(name, introMessage, image, color))
    }
    function openLeaveCommunityPopup(community, communityId, outroMessage) {
        invoke(() => root.item.openLeaveCommunityPopup(community, communityId, outroMessage))
    }

    Connections {
        target: Global

        function onOpenMarkAsIDVerifiedPopup(publicKey, cb) {
            root.invoke(() => root.item.openMarkAsIDVerifiedPopup(publicKey, cb))
        }
        function onOpenRemoveIDVerificationDialog(publicKey, cb) {
            root.invoke(() => root.item.openRemoveIDVerificationDialog(publicKey, cb))
        }
        function onOpenInviteFriendsToCommunityPopup(community, communitySectionModule, cb) {
            root.invoke(() => root.item.openInviteFriendsToCommunityPopup(community, communitySectionModule, cb))
        }
        function onOpenInviteFriendsToCommunityByIdPopup(communityId, cb) {
            root.invoke(() => root.item.openInviteFriendsToCommunityByIdPopup(communityId, cb))
        }
        function onOpenContactRequestPopup(publicKey, cb) {
            root.invoke(() => root.item.openContactRequestPopup(publicKey, cb))
        }
        function onOpenReviewContactRequestPopup(publicKey, cb) {
            root.invoke(() => root.item.openReviewContactRequestPopup(publicKey, cb))
        }
        function onOpenDownloadModalRequested(available, version, url) {
            root.invoke(() => root.item.openDownloadModal(available, version, url))
        }
        function onOpenImagePopup(image, url, plain) {
            root.invoke(() => root.item.openImagePopup(image, url, plain))
        }
        function onOpenVideoPopup(url) {
            root.invoke(() => root.item.openVideoPopup(url))
        }
        function onOpenProfilePopupRequested(publicKey, parentPopup, cb) {
            root.invoke(() => root.item.openProfilePopup(publicKey, parentPopup, cb))
        }
        function onOpenNicknamePopupRequested(publicKey, cb) {
            root.invoke(() => root.item.openNicknamePopup(publicKey, cb))
        }
        function onMarkAsUntrustedRequested(publicKey) {
            root.invoke(() => root.item.openMarkAsUntrustedPopup(publicKey))
        }
        function onBlockContactRequested(publicKey) {
            root.invoke(() => root.item.openBlockContactPopup(publicKey))
        }
        function onUnblockContactRequested(publicKey) {
            root.invoke(() => root.item.openUnblockContactPopup(publicKey))
        }
        function onOpenChangeProfilePicPopup(cb) {
            root.invoke(() => root.item.openChangeProfilePicPopup(cb))
        }
        function onOpenBackUpSeedPopup() {
            root.invoke(() => root.item.openBackUpSeedPopup())
        }
        function onOpenAuthenticationPopup(reason, keyUid, exportChatKey) {
            root.invoke(() => root.item.openAuthenticationPopup(reason, keyUid, exportChatKey))
        }
        function onOpenSigningPopup(reason, keyUid, txHash, path, address) {
            root.invoke(() => root.item.openSigningPopup(reason, keyUid, txHash, path, address))
        }
        function onOpenKeycardManagementPopup(flow, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson) {
            root.invoke(() => root.item.openKeycardManagementPopup(flow, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson))
        }
        function onOpenPinnedMessagesPopupRequested(store, messageStore, pinnedMessagesModel, messageToPin, chatId) {
            root.invoke(() => root.item.openPinnedMessagesPopup(store, messageStore, pinnedMessagesModel, messageToPin, chatId))
        }
        function onOpenCommunityProfilePopupRequested(store, community, communitySectionModule) {
            root.invoke(() => root.item.openCommunityProfilePopup(store, community, communitySectionModule))
        }
        function onCreateCommunityPopupRequested(isDiscordImport) {
            root.invoke(() => root.item.openCreateCommunityPopup(isDiscordImport))
        }
        function onImportCommunityPopupRequested() {
            root.invoke(() => root.item.openImportCommunityPopup())
        }
        function onCommunityShareAddressesPopupRequested(communityId, name, imageSrc) {
            root.invoke(() => root.item.openCommunityShareAddressesPopup(communityId, name, imageSrc))
        }
        function onCommunityIntroPopupRequested(communityId, name, introMessage, imageSrc, isInvitationPending) {
            root.invoke(() => root.item.openCommunityIntroPopup(communityId, name, introMessage, imageSrc, isInvitationPending))
        }
        function onRemoveContactRequested(publicKey) {
            root.invoke(() => root.item.openRemoveContactConfirmationPopup(publicKey))
        }
        function onOpenPopupRequested(popupComponent, params) {
            root.invoke(() => root.item.openPopup(popupComponent, params))
        }
        function onClosePopupRequested() {
            root.invoke(() => root.item.closePopup())
        }
        function onOpenDeleteMessagePopup(messageId, messageStore) {
            root.invoke(() => root.item.openDeleteMessagePopup(messageId, messageStore))
        }
        function onOpenDownloadImageDialog(imageSource) {
            root.invoke(() => root.item.openDownloadImageDialog(imageSource))
        }
        function onLeaveCommunityRequested(community, communityId, outroMessage) {
            root.invoke(() => root.item.openLeaveCommunityPopup(community, communityId, outroMessage))
        }
        function onOpenTestnetPopup() {
            root.invoke(() => root.item.openTestnetPopup())
        }
        function onOpenExportControlNodePopup(community) {
            root.invoke(() => root.item.openExportControlNodePopup(community))
        }
        function onOpenImportControlNodePopup(community) {
            root.invoke(() => root.item.openImportControlNodePopup(community))
        }
        function onOpenEditSharedAddressesFlow(communityId) {
            root.invoke(() => root.item.openEditSharedAddressesPopup(communityId))
        }
        function onOpenTransferOwnershipPopup(communityId, communityName, communityLogo, token) {
            root.invoke(() => root.item.openTransferOwnershipPopup(communityId, communityName, communityLogo, token))
        }
        function onOpenFinaliseOwnershipPopup(communityId) {
            root.invoke(() => root.item.openFinaliseOwnershipPopup(communityId))
        }
        function onOpenDeclineOwnershipPopup(communityId, communityName) {
            root.invoke(() => root.item.openDeclineOwnershipPopup(communityId, communityName))
        }
        function onOpenFirstTokenReceivedPopup(communityId, communityName, communityLogo, tokenSymbol, tokenName, tokenAmount, tokenType, tokenImage) {
            root.invoke(() => root.item.openFirstTokenReceivedPopup(communityId, communityName, communityLogo, tokenSymbol, tokenName, tokenAmount, tokenType, tokenImage))
        }
        function onOpenConfirmHideAssetPopup(assetSymbol, assetName, assetImage, isCommunityToken) {
            root.invoke(() => root.item.openConfirmHideAssetPopup(assetSymbol, assetName, assetImage, isCommunityToken))
        }
        function onOpenConfirmHideCollectiblePopup(collectibleSymbol, collectibleName, collectibleImage, isCommunityToken) {
            root.invoke(() => root.item.openConfirmHideCollectiblePopup(collectibleSymbol, collectibleName, collectibleImage, isCommunityToken))
        }
        function onOpenCommunityMemberMessagesPopupRequested(store, chatCommunitySectionModule, memberPubKey, displayName) {
            root.invoke(() => root.item.openCommunityMemberMessagesPopup(store, chatCommunitySectionModule, memberPubKey, displayName))
        }
        function onOpenBuyCryptoModalRequested(parameters) {
            root.invoke(() => root.item.openBuyCryptoModal(parameters))
        }
        function onPrivacyPolicyRequested() {
            root.invoke(() => root.item.openPrivacyPolicyPopup())
        }
        function onOpenPaymentRequestModalRequested(onPaymentRequested, callback) {
            root.invoke(() => root.item.openPaymentRequestModal(onPaymentRequested, callback))
        }
        function onTermsOfUseRequested() {
            root.invoke(() => root.item.openTermsOfUsePopup())
        }
        function onOpenNewsMessagePopupRequested(notification, notificationId) {
            root.invoke(() => root.item.openNewsMessagePopup(notification, notificationId))
        }
        function onQuitAppRequested() {
            root.invoke(() => root.item.openQuitConfirmPopup())
        }
        function onOpenQRScannerRequested() {
            root.invoke(() => root.item.openQRScannerPopup())
        }
        function onOpenInfoPopup(title, message) {
            root.invoke(() => root.item.openInfoPopup(title, message))
        }
        function onShareProfileDialogRequested(publicKey) {
            root.invoke(() => root.item.openShareProfilePopup(publicKey))
        }
        function onOpenNavigationEducationPopupRequested() {
            root.invoke(() => root.item.openNavigationEducationPopup())
        }
        function onOpenLimitReachedPopupRequested(warningType) {
            root.invoke(() => root.item.openLimitReachedPopup(warningType))
        }
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onOpenExternalLink(link) { root.openExternalLink(link) }
        function onSaveDomainToUnfurledWhitelist(domain) { root.saveDomainToUnfurledWhitelist(domain) }
        function onOwnershipDeclined(communityId, communityName) {
            root.ownershipDeclined(communityId, communityName)
        }
        function onTransferOwnershipRequested(tokenId, senderAddress) {
            root.transferOwnershipRequested(tokenId, senderAddress)
        }
        function onWcUriScanned(uri) { root.wcUriScanned(uri) }
        function onNavigationEducationDialogSeenRequested() { root.navigationEducationDialogSeenRequested() }
    }
}
