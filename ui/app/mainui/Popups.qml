import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Chat.popups
import AppLayouts.Profile.popups
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.popups
import AppLayouts.Wallet.helpers
import AppLayouts.Communities.stores
import AppLayouts.Profile.helpers
import AppLayouts.Wallet.services.dapps
import mainui.popups

import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores

import shared.popups
import shared.popups.authentication
import shared.popups.authentication.stores 1.0 as AuthStores
import shared.popups.signing
import shared.popups.signing.stores 1.0 as SignStores
import shared.popups.keycard_new
import shared.popups.keycard_new.stores 1.0 as KeycardMgmtStores
import shared.status
import shared.stores
import shared.views
import shared.views.profile

import utils

QtObject {
    id: root

    required property var popupParent
    required property Keychain keychain
    required property SecureStorage secureStorage

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

    readonly property AuthStores.AuthenticationStore authenticationStore: AuthStores.AuthenticationStore {
    }

    readonly property SignStores.SigningStore signingStore: SignStores.SigningStore {
    }

    readonly property KeycardMgmtStores.KeycardManagementStore keycardManagementStore: KeycardMgmtStores.KeycardManagementStore {
        onKeycardMoveProfileKeyPairSuccess: {
            // The profile keypair moved to a keycard — keycard profiles are out of scope
            // for "Stay logged in". The credential was already verifiably removed when
            // the flow started (see openKeycardManagementPopup — a prerequisite, because
            // the rekey=false conversion keeps the same DEK); this re-delete is
            // defense-in-depth, and the preference flips off only on a verified-absent
            // result (delete-first ordering: startup trusts credential presence).
            const status = root.secureStorage.deleteCredential(userProfileKeyUid)
            if (status === SecureStorage.StatusSuccess
                    || status === SecureStorage.StatusNotFound
                    || status === SecureStorage.StatusNotSupported) {
                root.privacyStore.setStayLoggedIn(false)
            }
        }
    }

    // The encryption-migration flow must survive section navigation (the settings view
    // that starts it is unloaded when leaving the Profile section), so it is owned here.
    readonly property ProfileEncryptionMigrationFlow profileEncryptionMigrationFlow: ProfileEncryptionMigrationFlow {
        privacyStore: root.privacyStore
        keychain: root.keychain
        popupParent: root.popupParent
    }

    property string emojiSkinColor
    property bool isWalletEnabled

    property var allContactsModel
    property var mutualContactsModel

    property bool isDevBuild

    signal openExternalLink(string link)
    signal saveDomainToUnfurledWhitelist(string domain)
    signal ownershipDeclined(string communityId, string communityName)
    signal transferOwnershipRequested(string tokenId, string senderAddress, string tokenName, string tokenImage)
    signal wcUriScanned(string uri)
    signal navigationEducationDialogSeenRequested()
    signal restartRequested()
    signal emojiSkinColorSelected(string skinColor)
    signal buyStickerPackRequested(string packId, string price)
    signal enableThirdpartyServicesRequested()

    readonly property Connections imageSaveConnections: Connections {
        target: SystemUtils

        function onImageSavedToGallery(destination) {
            root.notifyImageSaveResult(true, destination)
        }

        function onImageSaveToGalleryFailed() {
            root.notifyImageSaveResult(false)
        }
    }

    property var communityFetchPopup: null

    readonly property SQUtils.DeferredComponent communityFetchPopupComponent: SQUtils.DeferredComponent {
        source: Qt.resolvedUrl("../AppLayouts/Communities/popups/CommunityFetchPopup.qml")
        properties: ({
            parent: root.popupParent,
            state: Qt.binding(() => root.communitiesStore.communityFetchState),
            timeoutSeconds: Qt.binding(() => root.communitiesStore.communityFetchTimeoutSeconds)
        })
        onCreated: popup => {
            popup.cancelRequested.connect(() => root.communitiesStore.cancelPendingCommunityFetch())
            popup.timeoutRequested.connect(() => root.communitiesStore.timeoutPendingCommunityFetch())
            popup.dismissFailedRequested.connect(() => root.communitiesStore.clearCommunityFetchFailure())
            popup.retryRequested.connect(() => root.communitiesStore.retryCommunityFetch())
        }
    }

    readonly property Connections communityFetchConnections: Connections {
        target: root.communitiesStore

        function onCommunityFetchStateChanged() {
            if (root.communitiesStore.communityFetchState === Constants.CommunityFetchState.Idle) {
                root.communityFetchPopup?.close()
                return
            }
            if (!root.communityFetchPopup)
                root.communityFetchPopup = root.communityFetchPopupComponent.createObject(root)
            root.communityFetchPopup?.open()
        }
    }

    property var activePopupComponents: []

    readonly property Component contactModelEntryComponent: ContactModelEntry {
        contactsModel: root.allContactsModel
        onPopulateContactDetailsRequested: root.contactsStore.populateContactDetails(publicKey)
    }

    // Each popup gets its own live ContactModelEntry
    function openContactPopup(popupComponent, publicKey, params = {}, cb = null) {
        const contactEntry = contactModelEntryComponent.createObject(root, { publicKey })
        const popup = openPopup(popupComponent, Object.assign({ publicKey, contactDetails: contactEntry.contactDetails }, params), cb)
        if (!popup) {
            contactEntry.destroy()
            return null
        }
        popup.closed.connect(() => contactEntry.destroy())
        return popup
    }

    function openContactAdaptivePopup(popupComponent, publicKey, params = {}, cb = null) {
        return openContactPopup(popupComponent, publicKey, Object.assign({
            compressedPublicKey: root.utilsStore.getCompressedPk(publicKey),
            emojiHash: root.utilsStore.getEmojiHash(publicKey)
        }, params), cb)
    }

    property var currentPopup
    function openPopup(popupComponent, params = {}, cb = null) {
        if (root.activePopupComponents.includes(popupComponent)) {
            return null
        }

        root.currentPopup = popupComponent.createObject(popupParent, params)
        root.currentPopup.open();
        if (cb)
            cb(root.currentPopup)

        root.activePopupComponents.push(popupComponent)

        root.currentPopup.closed.connect(() => {
            const removeIndex = root.activePopupComponents.indexOf(popupComponent)
            if (removeIndex !== -1) {
                root.activePopupComponents.splice(removeIndex, 1)
            }
        })
        return root.currentPopup
    }

    function closePopup() {
        if (!!root.currentPopup)
            root.currentPopup.close();
    }

    function openDownloadModal(available: bool, version: string, url: string) {
        const popupProperties = {
            newVersionAvailable: available,
            downloadURL: url,
            currentVersion: root.aboutStore.getCurrentVersion(),
            newVersion: version
        }
        openPopup(downloadPageComponent, popupProperties)
    }

    function openEmojiPopup(params, cb) {
        return openAnchoredPopup(emojiPopupComponent, params, cb)
    }

    function openStickersPopup(params, cb) {
        return openAnchoredPopup(stickersPopupComponent, params, cb)
    }

    // A typed property reads null once its object is destroyed; a plain JS
    // reference, like the one in a request's params, does not.
    readonly property QtObject anchorProbe: QtObject {
        property Item item
    }

    // The first open waits for Popups to load, so the requester (the popup's
    // directParent) may already be gone; the callback is then not called.
    function openAnchoredPopup(popupComponent, params, cb) {
        root.anchorProbe.item = params.directParent ?? null
        const anchored = !!root.anchorProbe.item
        root.anchorProbe.item = null
        if (!anchored)
            return null

        const popup = openPopup(popupComponent, params)
        if (popup)
            cb(popup)
        return popup
    }

    function openImagePopup(image, url) {
        openPopup(imagePopupComponent, {image, url})
    }

    function openVideoPopup(url) {
        openPopup(videoPopupComponent, { url })
    }

    function openProfilePopup(publicKey: string, parentPopup, cb) {
        openContactPopup(profilePopupComponent, publicKey, { parentPopup }, cb)
    }

    function openNicknamePopup(publicKey: string, cb) {
        openContactAdaptivePopup(nicknamePopupComponent, publicKey, {}, cb)
    }

    function openMarkAsUntrustedPopup(publicKey: string) {
        openContactAdaptivePopup(markAsUntrustedComponent, publicKey, {})
    }

    function openBlockContactPopup(publicKey: string) {
        openContactAdaptivePopup(blockContactConfirmationComponent, publicKey, {})
    }

    function openUnblockContactPopup(publicKey: string) {
        openContactAdaptivePopup(unblockContactConfirmationComponent, publicKey, {})
    }

    function openChangeProfilePicPopup(cb) {
        var popup = changeProfilePicComponent.createObject(popupParent, {callback: cb});
        popup.chooseImageToCrop()
    }

    function openBackUpSeedPopup() {
        openPopup(backupSeedModalComponent)
    }

    function openAuthenticationPopup(reason, keyUid, exportChatKey) {
        let finalKeyUid = keyUid
        if (!finalKeyUid) {
            finalKeyUid = root.authenticationStore.userProfileKeyUid
        }
        openPopup(authenticationPopupComponent, { reason: reason, keyUid: finalKeyUid, exportChatKey: exportChatKey })
    }

    function openSigningPopup(reason, keyUid, txHash, path, address) {
        let finalKeyUid = keyUid
        if (!finalKeyUid) {
            finalKeyUid = root.signingStore.userProfileKeyUid
        }
        openPopup(signingPopupComponent, { reason: reason, keyUid: finalKeyUid, txHash: txHash, path: path, address: address })
    }

    function openKeycardManagementPopup(flow, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson, keycardInitialized,
                                        useExistingKeycardWhenMigratingProfileToKeycard = false) {
        let finalFlow = flow
        let finalKeyUid = keyUid

        // if keyUid is set validate and adjust the flow, or if not set try to set it based on flow, or if cannot be determined just follow the flow
        if (!!finalKeyUid) {
            switch(flow) {
            case Constants.keycard.flow.moveKeyPair:
                if (finalKeyUid === root.keycardManagementStore.userProfileKeyUid) {
                    finalFlow = Constants.keycard.flow.moveProfileKeyPair
                }
                break
            case Constants.keycard.flow.stopUsingKeycard:
                if (finalKeyUid === root.keycardManagementStore.userProfileKeyUid) {
                    finalFlow = Constants.keycard.flow.stopUsingKeycardForProfile
                }
                break
            case Constants.keycard.flow.moveProfileKeyPair:
                if (finalKeyUid !== root.keycardManagementStore.userProfileKeyUid) {
                    finalFlow = Constants.keycard.flow.moveKeyPair
                }
                break
            case Constants.keycard.flow.stopUsingKeycardForProfile:
                if (finalKeyUid !== root.keycardManagementStore.userProfileKeyUid) {
                    finalFlow = Constants.keycard.flow.stopUsingKeycard
                }
                break
            }
        } else if (flow === Constants.keycard.flow.moveProfileKeyPair ||
                   flow === Constants.keycard.flow.stopUsingKeycardForProfile) {
            finalKeyUid = root.keycardManagementStore.userProfileKeyUid

        }

        if (finalFlow !== flow) {
            console.info("wrong flow for the provided keyUid: ", keyUid, " flow changed from ", flow, " to ", finalFlow)
        }

        if (finalFlow === Constants.keycard.flow.moveProfileKeyPair) {
            // Converting the profile to Keycard must not leave a usable silent DEK
            // behind (the rekey=false conversion rewraps the SAME DEK, so a stored
            // credential would keep decrypting the databases without the card). Verified
            // removal — or verified absence — is a prerequisite for starting the flow,
            // and it must be established by deleteCredential, never by a bare
            // hasCredential probe: on Linux the delete is serialized against the
            // pending-mutation registry, so a credential write that timed out but may
            // still commit blocks the conversion, while a read would race past it and
            // report a stale NotFound. Success and NotFound are verified outcomes; the
            // stub-only NotSupported proves no build could ever have stored anything.
            // Any UNVERIFIED outcome (Unavailable — locked keyring, unsigned dev build,
            // pending mutation — GenericError, Indeterminate) refuses the conversion,
            // because a surviving credential would remain a usable decryption key once
            // the store is reachable again. Keycard logins additionally reconcile
            // leftovers as defense-in-depth, but best-effort cleanup is not a
            // substitute for the prerequisite.
            const deleteStatus = root.secureStorage.deleteCredential(root.keycardManagementStore.userProfileKeyUid)
            const verifiedAbsent = deleteStatus === SecureStorage.StatusSuccess
                                || deleteStatus === SecureStorage.StatusNotFound
                                || deleteStatus === SecureStorage.StatusNotSupported
            if (!verifiedAbsent) {
                Global.displayToastMessage(
                            qsTr("Cannot move the profile key pair to Keycard: failed to remove the saved password, please try again"),
                            "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                return
            }
        }

        console.info("openning keycard popup for flow: ", finalFlow, " keyUid: ", finalKeyUid, " keycardUid: ", keycardUid, " cardMetadataName: ", cardMetadataName, " cardMetadataWalletAccountsJson: ", cardMetadataWalletAccountsJson)

        openPopup(keycardManagementPopupComponent, {
            flow: finalFlow,
            keyUid: finalKeyUid,
            keycardUid: keycardUid,
            keycardInitialized: keycardInitialized,
            cardMetadataName: cardMetadataName,
            cardMetadataWalletAccountsJson: cardMetadataWalletAccountsJson,
            useExistingKeycardWhenMigratingProfileToKeycard: useExistingKeycardWhenMigratingProfileToKeycard
        })
    }

    function openAlignWithPairedDevicePopup(migrateToKeycard) {
        openPopup(alignWithPairedDevicePopupComponent, { migrateToKeycard })
    }

    function openCommunityProfilePopup(store, community, communitySectionModule) {
        openPopup(communityProfilePopup, { store: store, community: community, communitySectionModule: communitySectionModule})
    }

    function openCommunityRulesPopup(name, introMessage, image, color) {
        openPopup(communityRulesPopup, { name, introMessage, image, color })
    }

    function openMarkAsIDVerifiedPopup(publicKey, cb) {
        openContactAdaptivePopup(markAsIDVerifiedPopupComponent, publicKey, {}, cb)
    }

    function openRemoveIDVerificationDialog(publicKey, cb) {
        openContactAdaptivePopup(removeIDVerificationPopupComponent, publicKey, {}, cb)
    }

    function openInviteFriendsToCommunityPopup(community, communitySectionModule, cb) {
        openPopup(inviteFriendsToCommunityPopup, {
            community: community,
            membersModel: communitySectionModule.rosterModel,
            shareCommunityToUsers: (pubkeysStr, inviteMessage) => {
                communitySectionModule.shareCommunityToUsers(pubkeysStr, inviteMessage)
            }
        }, cb)
    }

    function openInviteFriendsToCommunityByIdPopup(communityId, cb) {
        const communitySectionModuleData = root.chatStore.getCommunitySectionModule(communityId)
        const communityData = root.communitiesStore.getCommunityDetails(communityId)

        openPopup(inviteFriendsToCommunityPopup, {
            community: communityData,
            membersModel: communitySectionModuleData.rosterModel,
            shareCommunityToUsers: (pubkeysStr, inviteMessage) => {
                communitySectionModuleData.shareCommunityToUsers(pubkeysStr, inviteMessage)
            }
        }, cb)
    }

    function openContactRequestPopup(publicKey, cb, defaultMessage = "", messageEditable = true) {
        openContactAdaptivePopup(sendContactRequestPopupComponent, publicKey, {
            defaultMessage: defaultMessage || "",
            messageEditable: messageEditable
        }, cb)
    }

    function openReviewContactRequestPopup(publicKey, cb) {
        try {
            const crDetails = root.contactsStore.getLatestContactRequestForContactAsJson(publicKey)
            if (crDetails.from !== publicKey) {
                console.warn("Popups.openReviewContactRequestPopup: not matching publicKey:", publicKey)
                return
            }

            openContactAdaptivePopup(reviewContactRequestPopupComponent, publicKey, { crDetails }, cb)
        } catch (e) {
            console.error("Popups.openReviewContactRequestPopup: error getting or parsing contact request data", e)
        }
    }

    function openPinnedMessagesPopup(store, messageStore, pinnedMessagesModel, messageToPin, chatId) {
        openPopup(pinnedMessagesPopup, {
            store: store,
            messageStore: messageStore,
            pinnedMessagesModel: pinnedMessagesModel,
            messageToPin: messageToPin,
            chatId: chatId,
            isPinActionAvailable: store && store.oneToOneChatContact ? store.oneToOneChatContact.isContact : true
        })
    }

    function openCommunityPopup(store, community, chatCommunitySectionModule) {
        openPopup(communityProfilePopup, {store: store, community: community, chatCommunitySectionModule: chatCommunitySectionModule})
    }

    function openCreateCommunityPopup(isDiscordImport) {
        openPopup(createCommunitiesPopupComponent, {isDiscordImport: isDiscordImport})
    }

    function openImportCommunityPopup() {
        openPopup(importCommunitiesPopupComponent)
    }

    function openCommunityIntroPopup(communityId,
                                    name,
                                    introMessage,
                                    imageSrc,
                                    isInvitationPending
                                    ) {
        openPopup(communityJoinDialogPopup,
                  {communityId: communityId,
                   communityName: name,
                   introMessage: introMessage,
                   communityIcon: imageSrc,
                   isInvitationPending: isInvitationPending
                  })
    }

    function openCommunityShareAddressesPopup(communityId, name, imageSrc) {
        openPopup(communityJoinDialogPopup,
                  {communityId: communityId,
                   stackTitle: qsTr("Share addresses with %1's owner").arg(name),
                   communityName: name,
                   introMessage: qsTr("Share addresses to rejoin %1").arg(name),
                   communityIcon: imageSrc,
                   isInvitationPending: false
                  })
    }

    function openEditSharedAddressesPopup(communityId) {
        openPopup(editSharedAddressesPopupComponent, {communityId: communityId, isEditMode: true})
    }

    function openDiscordImportProgressPopup(importingSingleChannel) {
        openPopup(discordImportProgressDialog, {importingSingleChannel: importingSingleChannel})
    }

    function openRemoveContactConfirmationPopup(publicKey) {
        openContactAdaptivePopup(removeContactConfirmationDialog, publicKey, {})
    }

    function openDeleteMessagePopup(messageId, messageStore) {
        openPopup(deleteMessageConfirmationDialogComponent,
                  {
                      messageId,
                      messageStore
                  })
    }

    function notifyImageSaveResult(success, destination = "") {
        if (success) {
            Global.displayToastMessage(destination ? qsTr("Image saved to %1").arg(UrlUtils.displayPathLabel(destination))
                                                   : qsTr("Image saved to system gallery"),
                                         "",
                                         "checkmark-circle",
                                         false,
                                         Constants.ephemeralNotificationType.success,
                                         "")
        } else {
            Global.displayToastMessage(qsTr("Failed to save image"),
                                         "",
                                         "warning",
                                         false,
                                         Constants.ephemeralNotificationType.danger,
                                         "")
        }
    }

    function openDownloadImageDialog(imageSource) {
        // iOS: the app is sandboxed so FileDialog has limited system access.
        // Android: opening the folder picker sends the app to background, which
        // causes the Status Go image server to become unreachable — the download
        // fails with a connection error by the time the picker returns.
        // In both cases, save directly to the system gallery instead.
        if (SQUtils.Utils.isIOS || SQUtils.Utils.isAndroid) {
            SystemUtils.downloadImageByUrl(imageSource, "")
            return
        }

        // We don't use `openPopup`, because there's no `FileDialog::closed` signal.
        const popup = downloadImageDialogComponent.createObject(popupParent, { imageSource })
        popup.open()
    }

    function openLeaveCommunityPopup(community, communityId, outroMessage) {
        openPopup(leaveCommunityPopupComponent, {community, communityId, outroMessage})
    }

    function openTestnetPopup() {
        openPopup(testnetModal)
    }

    function openExportControlNodePopup(community) {
        openPopup(exportControlNodePopup, { community })
    }

    function openImportControlNodePopup(community) {
        openPopup(importControlNodePopup, { community })
    }

    function openTransferOwnershipPopup(communityId, communityName, communityLogo, token) {
        openPopup(transferOwnershipPopup, { communityId, communityName, communityLogo, token })
    }

    function openConfirmExternalLinkPopup(link, domain) {
        openPopup(confirmExternalLinkPopup, {link, domain})
    }

    function openFinaliseOwnershipPopup(communityId) {
        openPopup(finaliseOwnershipPopup, { communityId: communityId })
    }

    function openDeclineOwnershipPopup(communityId, communityName) {
        openPopup(declineOwnershipPopup, { communityName: communityName, communityId: communityId })
    }

    function openFirstTokenReceivedPopup(communityId, communityName, communityLogo, tokenSymbol, tokenName, tokenAmount, tokenType, tokenImage) {
        openPopup(firstTokenReceivedPopup,
                  {
                      communityId: communityId,
                      communityName: communityName,
                      communityLogo: communityLogo,
                      tokenSymbol: tokenSymbol,
                      tokenName: tokenName,
                      tokenAmount: tokenAmount,
                      tokenType: tokenType,
                      tokenImage: tokenImage
                  })
    }

    function openConfirmHideAssetPopup(assetKey, assetSymbol, assetName, assetImage, isCommunityToken) {
        openPopup(confirmHideAssetPopup, { key: assetKey, symbol: assetSymbol, name: assetName, icon: assetImage, isCommunityToken })
    }

    function openConfirmHideCollectiblePopup(collectibleSymbol, collectibleName, collectibleImage, isCommunityToken) {
        openPopup(confirmHideCollectiblePopup, { collectibleSymbol, collectibleName, collectibleImage, isCommunityToken })
    }

    function openCommunityMemberMessagesPopup(store, chatCommunitySectionModule, memberPubKey, displayName) {
        openPopup(communityMemberMessagesPopup, {
            rootStore: store,
            chatCommunitySectionModule: chatCommunitySectionModule,
            memberPubKey: memberPubKey,
            displayName: displayName
        })
    }

    function openBuyCryptoModal(parameters) {
        openPopup(buyCryptoModal, {
            buyCryptoInputParamsForm: parameters
        })
    }

    function openPaymentRequestModal(onPaymentRequested, callback) {
        openPopup(paymentRequestModalComponent, {}, popup => {
                    popup.paymentRequested.connect(onPaymentRequested)
                    callback(popup)
                  })
    }

    function openNewsMessagePopup(notification, notificationId) {
        openPopup(newsMessageComponent, {notification: notification, notificationId: notificationId})
    }

    function openInfoPopup(title, message) {
        openPopup(infoComponent, {title, message})
    }

    function openShareProfilePopup(publicKey) {
        const contactEntry = contactModelEntryComponent.createObject(root, { publicKey })
        const contactDetails = contactEntry.contactDetails
        const emojiHash = root.utilsStore.getEmojiHash(publicKey)
        const linkToProfile = root.contactsStore.getLinkToProfile(publicKey)

        openPopup(shareProfileCmp, {isCurrentUser: contactDetails.isCurrentUser, publicKey, emojiHash, colorId: contactDetails.colorId,
                      linkToProfile, displayName: contactDetails.displayName, usesDefaultName: contactDetails.usesDefaultName, largeImage: contactDetails.largeImage})
        contactEntry.destroy()
    }

    function openNavigationEducationPopup() {
        openPopup(openNavigationEducationComponent)
    }

    function openLimitReachedPopup(warningType) {
        let title = ""
        let content = ""
        switch (warningType) {
        case Constants.LimitWarning.Accounts:
            title = Constants.walletConstants.maxNumberOfAccountsTitle
            content = Constants.walletConstants.maxNumberOfAccountsContent
            break
        case Constants.LimitWarning.Keypairs:
            title = Constants.walletConstants.maxNumberOfKeypairsTitle
            content = Constants.walletConstants.maxNumberOfKeypairsContent
            break
        case Constants.LimitWarning.WatchOnlyAccounts:
            title = Constants.walletConstants.maxNumberOfWatchOnlyAccountsTitle
            content = Constants.walletConstants.maxNumberOfSavedAddressesContent
            break
        case Constants.LimitWarning.SavedAddresses:
            title = Constants.walletConstants.maxNumberOfSavedAddressesTitle
            content = Constants.walletConstants.maxNumberOfSavedAddressesContent
            break
        default:
            console.error("openLimitReachedPopup: unsupported warning type", warningType)
            return
        }
        openPopup(limitReachedPopupComponent, { title, contentText: content })
    }

    function openPrivacyPolicyPopup() {
        openPopup(privacyPolicyPopupComponent)
    }

    function openTermsOfUsePopup() {
        openPopup(termsOfUsePopupComponent)
    }

    function openQuitConfirmPopup() {
        openPopup(quitConfirmPopupComponent)
    }

    function openQRScannerPopup() {
        openPopup(qrCodeScannerDialogComponent)
    }

    function openDprChangedConfirmationPopup() {
        openPopup(dprChangedConfirmationComponent)
    }

    readonly property list<Component> _components: [

        Component {
            id: deleteMessageConfirmationDialogComponent
            DeleteMessageConfirmationPopup {
                onClosed: destroy()
            }
        },

        Component {
            id: alignWithPairedDevicePopupComponent
            ConfirmationDialog {
                property bool migrateToKeycard
                property bool continueToMigrationFlow: false

                destroyOnClose: true
                headerSettings.title: qsTr("Align with paired device")
                showCancelButton: true
                btnType: ""
                cancelBtnType: ""
                confirmButtonLabel: qsTr("Continue")
                cancelButtonLabel: qsTr("Cancel")
                confirmationText: "<b>%1</b><br/><br/>%2<br/><br/>%3"
                    .arg(migrateToKeycard
                         ? qsTr("Your profile has been migrated to Keycard on paired device")
                         : qsTr("Your profile has been migrated from Keycard to Status"))
                    .arg(qsTr("In order to align on the login/signing method on this device, you need to complete the migration flow, clicking the \"Continue\" button below, or cancel this popup if you want to keep the current login/signing method."))
                    .arg(qsTr("If you don't want to see this message again, go to Settings/Wallet and toggle off \"Automatically apply key pair migrations from paired device\"."))

                onConfirmButtonClicked: {
                    continueToMigrationFlow = true
                    close()
                    root.openKeycardManagementPopup(
                                migrateToKeycard
                                ? Constants.keycard.flow.moveProfileKeyPair
                                : Constants.keycard.flow.stopUsingKeycardForProfile,
                                "",
                                "",
                                "",
                                "[]",
                                false /* keycardInitialized */,
                                true /* useExistingKeycardWhenMigratingProfileToKeycard */)
                }
                onCancelButtonClicked: close()
                onClosed: {
                    if (!continueToMigrationFlow) {
                        root.rootStore.profileMigrationFlowClosed()
                    }
                }
            }
        },

        // Components related to transfer community ownership flow:

        // End of components related to transfer community ownership flow.

        Component {
            id: confirmHideAssetPopup
            ConfirmHideAssetPopup {
                destroyOnClose: true

                required property string key
                required property bool isCommunityToken

                onConfirmButtonClicked: {
                    if (isCommunityToken)
                        root.walletAssetsStore.assetsController.showHideCommunityToken(key, false)
                    else
                        root.walletAssetsStore.assetsController.showHideRegularToken(key, false)
                    close()
                    Global.displayToastMessage(qsTr("%1 (%2) successfully hidden. You can toggle asset visibility via %3.").arg(name).arg(symbol)
                                               .arg(`<a style="text-decoration:none" href="#${Constants.appSection.profile}/${Constants.settingsSubsection.wallet}/${Constants.walletSettingsSubsection.manageHidden}">` + qsTr("Settings", "Go to Settings") + "</a>"),
                                               "",
                                               "checkmark-circle",
                                               false,
                                               Constants.ephemeralNotificationType.success,
                                               "")
                }
            }
        },
        Component {
            id: confirmHideCollectiblePopup
            ConfirmationDialog {

                property string collectibleSymbol
                property string collectibleName
                property string collectibleImage
                property bool isCommunityToken

                width: 520
                destroyOnClose: true
                confirmButtonLabel: qsTr("Hide collectible")
                cancelBtnType: ""
                showCancelButton: true
                headerSettings.title: qsTr("Hide %1").arg(collectibleName)
                headerSettings.asset.name: collectibleImage
                headerSettings.asset.bgRadius: Theme.radius
                confirmationText: qsTr("Are you sure you want to hide %1? You will no longer see or be able to interact with this collectible anywhere inside Status.").arg(collectibleName)
                onCancelButtonClicked: close()
                onConfirmButtonClicked: {
                    if (isCommunityToken)
                        root.walletCollectiblesStore.collectiblesController.showHideCommunityToken(collectibleSymbol, false)
                    else
                        root.walletCollectiblesStore.collectiblesController.showHideRegularToken(collectibleSymbol, false)
                    close()
                    Global.displayToastMessage(qsTr("%1 successfully hidden. You can toggle collectible visibility via %2.").arg(collectibleName)
                                               .arg(`<a style="text-decoration:none" href="#${Constants.appSection.profile}/${Constants.settingsSubsection.wallet}/${Constants.walletSettingsSubsection.manageHidden}">` + qsTr("Settings", "Go to Settings") + "</a>"),
                                               "",
                                               "checkmark-circle",
                                               false,
                                               Constants.ephemeralNotificationType.success,
                                               "")
                }
            }
        },
        Component {
            id: privacyPolicyPopupComponent
            StatusSimpleTextPopup {
                title: qsTr("Status Software Privacy Policy")
                content {
                    textFormat: Text.MarkdownText
                    text: SQUtils.StringUtils.readTextFile(":/imports/assets/docs/privacy.mdwn")
                    onLinkActivated: (link) => Global.requestOpenLink(link)
                }
                destroyOnClose: true
            }
        },
        Component {
            id: termsOfUsePopupComponent
            StatusSimpleTextPopup {
                title: qsTr("Status Software Terms of Use")
                content {
                    textFormat: Text.MarkdownText
                    text: SQUtils.StringUtils.readTextFile(":/imports/assets/docs/terms-of-use.mdwn")
                    onLinkActivated: (link) => Global.requestOpenLink(link)
                }
                destroyOnClose: true
            }
        },

        Component {
            id: infoComponent

            StatusDialog {
                id: infoPopup

                property string message

                StatusBaseText {
                    anchors.fill: parent
                    font.pixelSize: Theme.primaryTextFontSize
                    color: Theme.palette.directColor1
                    text: infoPopup.message
                }

                standardButtons: Dialog.Ok
            }
        },

        Component {
            id: openNavigationEducationComponent
            NavigationEducationDialog {

                destroyOnClose: true
                onClosed: root.navigationEducationDialogSeenRequested()
            }
        },

        Component {
            id: limitReachedPopupComponent

            StatusDialog {
                id: limitDialog

                property string contentText

                width: 480

                StatusBaseText {
                    anchors.fill: parent
                    text: limitDialog.contentText
                    wrapMode: Text.WordWrap
                }

                standardButtons: Dialog.Ok

                onClosed: destroy()
            }
        },

        Component {
            id: dprChangedConfirmationComponent
            ConfirmationDialog {
                title: qsTr("Display zoom changed")
                destroyOnClose: true
                confirmButtonLabel: qsTr("Restart")
                cancelButtonLabel: qsTr("Not Now")
                cancelBtnType: ""
                showCancelButton: true
                confirmationText: qsTr("Restart Status to apply your new display zoom")
                onCancelButtonClicked: close()
                onConfirmButtonClicked: {
                    close()
                    root.restartRequested()
                }
            }
        }
    ]

    readonly property list<QtObject> _deferredComponents: [
        SQUtils.DeferredComponent {
            id: emojiPopupComponent

            module: "shared.status"
            typeName: "StatusEmojiPopup"
            properties: ({
                objectName: "StatusEmojiPopup",
                height: 440,
                emojiModel: SQUtils.Emoji.emojiModel,
                skinColor: Qt.binding(() => root.emojiSkinColor)
            })
            onCreated: popup => {
                popup.skinColorSelected.connect(skinColor => root.emojiSkinColorSelected(skinColor))
                popup.closed.connect(() => popup.destroy())
            }
        },

        SQUtils.DeferredComponent {
            id: imagePopupComponent

            module: "shared.status"
            typeName: "StatusImageModal"
            onCreated: popup => popup.closed.connect(() => popup.destroy())
        },

        SQUtils.DeferredComponent {
            id: importCommunitiesPopupComponent

            source: Qt.resolvedUrl("ImportCommunityPopupInstance.qml")
            properties: ({
                messagingRootStore: root.messagingRootStore,
                store: root.communitiesStore,
                utilsStore: root.utilsStore
            })
            onCreated: popup => {
                popup.joinCommunityRequested.connect((communityId, communityDetails) => {
                    popup.close()
                    popup.communityAccessStore.spectateCommunity(communityId)
                    root.openCommunityIntroPopup(communityId,
                                                 communityDetails.name,
                                                 communityDetails.introMessage,
                                                 communityDetails.image,
                                                 popup.communityAccessStore.isMyCommunityRequestPending)
                })
                popup.closed.connect(() => popup.destroy())
            }
        },

        SQUtils.DeferredComponent {
            id: downloadImageDialogComponent

            source: Qt.resolvedUrl("DownloadImageDialogInstance.qml")
        },

        SQUtils.DeferredComponent {
            id: leaveCommunityPopupComponent

            source: Qt.resolvedUrl("LeaveCommunityPopupInstance.qml")
            onCreated: popup => {
                popup.leaveRequested.connect(communityId => root.communitiesStore.leaveCommunity(communityId))
                popup.closed.connect(() => popup.destroy())
            }
        },

        SQUtils.DeferredComponent {
            id: confirmExternalLinkPopup

            module: "shared.popups"
            typeName: "ConfirmExternalLinkPopup"
            properties: ({ destroyOnClose: true })
            onCreated: popup => {
                popup.openExternalLink.connect(link => root.openExternalLink(link))
                popup.saveDomainToUnfurledWhitelist.connect(domain => root.saveDomainToUnfurledWhitelist(domain))
            }
        },

        SQUtils.DeferredComponent {
            id: declineOwnershipPopup

            module: "AppLayouts.Communities.popups"
            typeName: "FinaliseOwnershipDeclinePopup"
            properties: ({ destroyOnClose: true })
            onCreated: popup => popup.declineClicked.connect(() => root.ownershipDeclined(popup.communityId, popup.communityName))
        },

        SQUtils.DeferredComponent {
            id: quitConfirmPopupComponent

            source: Qt.resolvedUrl("SignOutConfirmationDialog.qml")
            properties: ({
                secureStorage: root.secureStorage,
                privacyStore: root.privacyStore,
                keyUid: root.privacyStore.keyUid
            })
            onCreated: popup => popup.signOutRequested.connect(() => mainModule.signOutAndQuit())
        },

        SQUtils.DeferredComponent {
            id: downloadPageComponent

            module: "shared.popups"
            typeName: "DownloadPage"
            onCreated: popup => popup.closed.connect(() => popup.destroy())
        },

        SQUtils.DeferredComponent {
            id: communityProfilePopup

            module: "AppLayouts.Communities.popups"
            typeName: "CommunityProfilePopup"
            onCreated: popup => popup.closed.connect(() => popup.destroy())
        },

        SQUtils.DeferredComponent {
            id: pinnedMessagesPopup

            module: "AppLayouts.Chat.popups"
            typeName: "PinnedMessagesPopup"
            properties: ({
                utilsStore: root.utilsStore,
                gifUnfurlingEnabled: Qt.binding(() => root.sharedRootStore.gifUnfurlingEnabled),
                neverAskAboutUnfurlingAgain: Qt.binding(() => root.sharedRootStore.neverAskAboutUnfurlingAgain)
            })
            onCreated: popup => {
                popup.closed.connect(() => popup.destroy())
                popup.setNeverAskAboutUnfurlingAgain.connect(neverAskAgain => root.sharedRootStore.setNeverAskAboutUnfurlingAgain(neverAskAgain))
                popup.pinMessageRequested.connect(messageId => popup.messageStore.pinMessage(messageId))
                popup.unpinMessageRequested.connect(messageId => popup.messageStore.unpinMessage(messageId))
                popup.jumpToMessageRequested.connect(messageId => popup.messageStore.messageModule.jumpToMessage(messageId))
            }
        },

        SQUtils.DeferredComponent {
            id: testnetModal

            module: "shared.popups"
            typeName: "TestnetModePopup"
            properties: ({ areTestNetworksEnabled: Qt.binding(() => root.networksStore.areTestNetworksEnabled) })
            onCreated: popup => popup.toggleTestnetRequested.connect(() => root.networksStore.toggleTestNetworksEnabled())
        },

        SQUtils.DeferredComponent {
            id: exportControlNodePopup

            module: "AppLayouts.Communities.popups"
            typeName: "ExportControlNodePopup"
            properties: ({ devicesStore: root.devicesStore })
            onCreated: popup => popup.closed.connect(() => popup.destroy())
        },

        SQUtils.DeferredComponent {
            id: importControlNodePopup

            module: "AppLayouts.Communities.popups"
            typeName: "ImportControlNodePopup"
            onCreated: popup => {
                popup.closed.connect(() => popup.destroy())
                popup.importControlNode.connect(communityId => root.rootStore.promoteSelfToControlNode(communityId))
            }
        },

        SQUtils.DeferredComponent {
            id: transferOwnershipPopup

            module: "AppLayouts.Communities.popups"
            typeName: "TransferOwnershipPopup"
            onCreated: popup => {
                popup.transferOwnershipRequested.connect((tokenId, senderAddress, tokenName, tokenImage) =>
                                                         root.transferOwnershipRequested(tokenId, senderAddress, tokenName, tokenImage))
                popup.closed.connect(() => popup.destroy())
            }
        },

        SQUtils.DeferredComponent {
            id: firstTokenReceivedPopup

            module: "AppLayouts.Communities.popups"
            typeName: "FirstTokenReceivedPopup"
            properties: ({ destroyOnClose: true, communitiesStore: root.communitiesStore })
            // The toast payload carries only a symbol, but the hide popups are keyed
            // by token group key, so resolve it here.
            onCreated: popup => popup.hideClicked.connect((tokenSymbol, tokenName, tokenImage, isAsset) => {
                if (!isAsset) {
                    root.openConfirmHideCollectiblePopup(tokenSymbol, tokenName, tokenImage, true)
                    return
                }
                const token = SQUtils.ModelUtils.getByKey(
                                root.walletAssetsStore.groupedAccountAssetsModel, "symbol", tokenSymbol)
                if (!token)
                    return
                root.openConfirmHideAssetPopup(token.key, tokenSymbol, tokenName, tokenImage, true)
            })
        },

        SQUtils.DeferredComponent {
            id: communityMemberMessagesPopup

            source: Qt.resolvedUrl("CommunityMemberMessagesPopupInstance.qml")
            properties: ({
                sharedRootStore: root.sharedRootStore,
                utilsStore: root.utilsStore,
                communitiesStore: root.communitiesStore
            })
            onCreated: popup => popup.closed.connect(() => popup.destroy())
        },

        SQUtils.DeferredComponent {
            id: shareProfileCmp

            module: "shared.views.profile"
            typeName: "ShareProfileDialog"
            properties: ({ destroyOnClose: true })
            onCreated: popup => popup.qrCode = Qt.binding(() => root.profileStore.getQrCodeSource(popup.linkToProfile))
        },

        SQUtils.DeferredComponent {
            id: stickersPopupComponent

            module: "shared.status"
            typeName: "StatusStickersPopup"
            properties: ({
                objectName: "StatusStickersPopup",
                height: 440,
                store: Qt.binding(() => root.chatStore),
                isWalletEnabled: Qt.binding(() => root.isWalletEnabled),
                thirdpartyServicesEnabled: Qt.binding(() => root.rootStore.thirdpartyServicesEnabled)
            })
            onCreated: popup => {
                popup.buyClicked.connect((packId, price) => root.buyStickerPackRequested(packId, price))
                popup.enableThirdpartyServicesRequested.connect(() => root.enableThirdpartyServicesRequested())
                popup.closed.connect(() => popup.destroy())
            }
        },

        SQUtils.DeferredComponent {
            id: videoPopupComponent

            module: "shared.status"
            typeName: "StatusVideoModal"
            onCreated: popup => popup.closed.connect(() => popup.destroy())
        },

        SQUtils.DeferredComponent {
            id: discordImportProgressDialog

            module: "AppLayouts.Communities.popups"
            typeName: "DiscordImportProgressDialog"
            properties: ({ store: Qt.binding(() => root.communitiesStore) })
        },

        SQUtils.DeferredComponent {
            id: keycardManagementPopupComponent

            module: "shared.popups.keycard_new"
            typeName: "KeycardManagementPopup"
            properties: ({
                store: root.keycardManagementStore,
                passwordStrengthScoreFunction: root.sharedRootStore.getPasswordStrengthScore
            })
            onCreated: popup => {
                popup.metadataResult.connect(keycardInfo => Global.keycardManagementResult(keycardInfo))
                popup.keycardFlowCompleted.connect((flow, keyUid, keycardUid, success) => {
                    Global.keycardFlowDone(flow, keyUid, keycardUid, success)
                })
                popup.closed.connect(() => popup.destroy())
            }
        },

        SQUtils.DeferredComponent {
            id: createCommunitiesPopupComponent

            module: "AppLayouts.Communities.popups"
            typeName: "CreateCommunityPopup"
            properties: ({
                store: root.communitiesStore,
                advancedStore: root.advancedStore,
                isDevBuild: Qt.binding(() => root.isDevBuild)
            })
            onCreated: popup => popup.closed.connect(() => popup.destroy())
        },

        SQUtils.DeferredComponent {
            id: profilePopupComponent

            source: Qt.resolvedUrl("ProfileDialogInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: communityJoinDialogPopup

            source: Qt.resolvedUrl("CommunityJoinDialogInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: editSharedAddressesPopupComponent

            source: Qt.resolvedUrl("EditSharedAddressesDialogInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: paymentRequestModalComponent

            source: Qt.resolvedUrl("PaymentRequestModalInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: buyCryptoModal

            source: Qt.resolvedUrl("BuyCryptoModalInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: qrCodeScannerDialogComponent

            source: Qt.resolvedUrl("QRCodeScannerDialogInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: finaliseOwnershipPopup

            source: Qt.resolvedUrl("FinaliseOwnershipPopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: signingPopupComponent

            source: Qt.resolvedUrl("SignPopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: backupSeedModalComponent

            source: Qt.resolvedUrl("BackupSeedModalInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: authenticationPopupComponent

            source: Qt.resolvedUrl("AuthenticationPopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: newsMessageComponent

            source: Qt.resolvedUrl("NewsMessagePopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: sendContactRequestPopupComponent

            source: Qt.resolvedUrl("SendContactRequestModalInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: nicknamePopupComponent

            source: Qt.resolvedUrl("NicknamePopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: blockContactConfirmationComponent

            source: Qt.resolvedUrl("BlockContactConfirmationDialogInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: removeIDVerificationPopupComponent

            source: Qt.resolvedUrl("RemoveIDVerificationDialogInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: removeContactConfirmationDialog

            source: Qt.resolvedUrl("RemoveContactPopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: markAsUntrustedComponent

            source: Qt.resolvedUrl("MarkAsUntrustedPopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: reviewContactRequestPopupComponent

            source: Qt.resolvedUrl("ReviewContactRequestPopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: unblockContactConfirmationComponent

            source: Qt.resolvedUrl("UnblockContactConfirmationDialogInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: markAsIDVerifiedPopupComponent

            source: Qt.resolvedUrl("MarkAsIDVerifiedDialogInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: communityRulesPopup

            source: Qt.resolvedUrl("CommunityRulesPopupInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: changeProfilePicComponent

            source: Qt.resolvedUrl("ImageCropWorkflowInstance.qml")
            properties: ({ host: root })
        },

        SQUtils.DeferredComponent {
            id: inviteFriendsToCommunityPopup

            source: Qt.resolvedUrl("InviteFriendsToCommunityPopupInstance.qml")
            properties: ({ host: root })
        }
    ]
}
