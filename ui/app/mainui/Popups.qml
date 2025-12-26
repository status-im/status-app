import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models
import QtQml

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
import AppLayouts.Communities.stores
import AppLayouts.Profile.helpers

import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores

import shared.popups
import shared.status
import shared.stores
import shared.views

import utils

QtObject {
    id: root

    required property var popupParent

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

    property var allContactsModel
    property var mutualContactsModel

    property bool isDevBuild

    signal openExternalLink(string link)
    signal saveDomainToUnfurledWhitelist(string domain)
    signal ownershipDeclined(string communityId, string communityName)
    signal transferOwnershipRequested(string tokenId, string senderAddress)

    property var activePopupComponents: []

    Component.onCompleted: {
        Global.openMarkAsIDVerifiedPopup.connect(openMarkAsIDVerifiedPopup)
        Global.openRemoveIDVerificationDialog.connect(openRemoveIDVerificationDialog)
        Global.openInviteFriendsToCommunityPopup.connect(openInviteFriendsToCommunityPopup)
        Global.openInviteFriendsToCommunityByIdPopup.connect(openInviteFriendsToCommunityByIdPopup)
        Global.openContactRequestPopup.connect(openContactRequestPopup)
        Global.openReviewContactRequestPopup.connect(openReviewContactRequestPopup)
        Global.openDownloadModalRequested.connect(openDownloadModal)
        Global.openImagePopup.connect(openImagePopup)
        Global.openVideoPopup.connect(openVideoPopup)
        Global.openProfilePopupRequested.connect(openProfilePopup)
        Global.openNicknamePopupRequested.connect(openNicknamePopup)
        Global.markAsUntrustedRequested.connect(openMarkAsUntrustedPopup)
        Global.blockContactRequested.connect(openBlockContactPopup)
        Global.unblockContactRequested.connect(openUnblockContactPopup)
        Global.openChangeProfilePicPopup.connect(openChangeProfilePicPopup)
        Global.openBackUpSeedPopup.connect(openBackUpSeedPopup)
        Global.openPinnedMessagesPopupRequested.connect(openPinnedMessagesPopup)
        Global.openCommunityProfilePopupRequested.connect(openCommunityProfilePopup)
        Global.createCommunityPopupRequested.connect(openCreateCommunityPopup)
        Global.importCommunityPopupRequested.connect(openImportCommunityPopup)
        Global.communityShareAddressesPopupRequested.connect(openCommunityShareAddressesPopup)
        Global.communityIntroPopupRequested.connect(openCommunityIntroPopup)
        Global.removeContactRequested.connect(openRemoveContactConfirmationPopup)
        Global.openPopupRequested.connect(openPopup)
        Global.closePopupRequested.connect(closePopup)
        Global.openDeleteMessagePopup.connect(openDeleteMessagePopup)
        Global.openDownloadImageDialog.connect(openDownloadImageDialog)
        Global.leaveCommunityRequested.connect(openLeaveCommunityPopup)
        Global.openTestnetPopup.connect(openTestnetPopup)
        Global.openExportControlNodePopup.connect(openExportControlNodePopup)
        Global.openImportControlNodePopup.connect(openImportControlNodePopup)
        Global.openEditSharedAddressesFlow.connect(openEditSharedAddressesPopup)
        Global.openTransferOwnershipPopup.connect(openTransferOwnershipPopup)
        Global.openFinaliseOwnershipPopup.connect(openFinaliseOwnershipPopup)
        Global.openDeclineOwnershipPopup.connect(openDeclineOwnershipPopup)
        Global.openFirstTokenReceivedPopup.connect(openFirstTokenReceivedPopup)
        Global.openConfirmHideAssetPopup.connect(openConfirmHideAssetPopup)
        Global.openConfirmHideCollectiblePopup.connect(openConfirmHideCollectiblePopup)
        Global.openCommunityMemberMessagesPopupRequested.connect(openCommunityMemberMessagesPopup)
        Global.openBuyCryptoModalRequested.connect(openBuyCryptoModal)
        Global.privacyPolicyRequested.connect(() => openPopup(privacyPolicyPopupComponent))
        Global.openPaymentRequestModalRequested.connect(openPaymentRequestModal)
        Global.termsOfUseRequested.connect(() => openPopup(termsOfUsePopupComponent))
        Global.openNewsMessagePopupRequested.connect(openNewsMessagePopup)
        Global.quitAppRequested.connect(() => openPopup(quitConfirmPopupComponent))
        Global.openInfoPopup.connect(openInfoPopup)
    }

    property var currentPopup
    function openPopup(popupComponent, params = {}, cb = null) {
        if (root.activePopupComponents.includes(popupComponent)) {
            return
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

    function openImagePopup(image, url, plain) {
        openPopup(imagePopupComponent, {image: image, url: url, plain: plain})
    }

    function openVideoPopup(url) {
        openPopup(videoPopupComponent, { url: url })
    }

    function openProfilePopup(publicKey: string, parentPopup, cb) {
        openPopup(profilePopupComponent, {publicKey: publicKey, parentPopup: parentPopup}, cb)
    }

    function openNicknamePopup(publicKey: string, cb) {
        const contactDetails = Utils.getContactDetailsAsJson(
                                 publicKey, false, true, true)
        const properties = { publicKey, contactDetails }

        openPopup(nicknamePopupComponent, properties, cb)
    }

    function openMarkAsUntrustedPopup(publicKey: string) {
        const contactDetails = Utils.getContactDetailsAsJson(
                                 publicKey, false, true, true)
        const properties = { publicKey, contactDetails }

        openPopup(markAsUntrustedComponent, properties)
    }

    function openBlockContactPopup(publicKey: string) {
        const contactDetails = Utils.getContactDetailsAsJson(
                                 publicKey, false, true, true)
        const properties = { publicKey, contactDetails }

        openPopup(blockContactConfirmationComponent, properties)
    }

    function openUnblockContactPopup(publicKey: string) {
        const contactDetails = Utils.getContactDetailsAsJson(
                                 publicKey, false, true, true)
        const properties = { publicKey, contactDetails }

        openPopup(unblockContactConfirmationComponent, properties)
    }

    function openChangeProfilePicPopup(cb) {
        var popup = changeProfilePicComponent.createObject(popupParent, {callback: cb});
        popup.chooseImageToCrop()
    }

    function openBackUpSeedPopup() {
        openPopup(backupSeedModalComponent)
    }

    function openCommunityProfilePopup(store, community, communitySectionModule) {
        openPopup(communityProfilePopup, { store: store, community: community, communitySectionModule: communitySectionModule})
    }

    function openCommunityRulesPopup(name, introMessage, image, color) {
        openPopup(communityRulesPopup, { name, introMessage, image, color })
    }

    function openMarkAsIDVerifiedPopup(publicKey, cb) {
        const contactDetails = Utils.getContactDetailsAsJson(
                                 publicKey, true, true, true)
        const properties = { publicKey, contactDetails }

        openPopup(markAsIDVerifiedPopupComponent, properties, cb)
    }

    function openRemoveIDVerificationDialog(publicKey, cb) {
        const contactDetails = Utils.getContactDetailsAsJson(
                                 publicKey, true, true, true)
        const properties = { publicKey, contactDetails }

        openPopup(removeIDVerificationPopupComponent, properties, cb)
    }

    function openInviteFriendsToCommunityPopup(community, communitySectionModule, cb) {
        openPopup(inviteFriendsToCommunityPopup, { community: community, communitySectionModule: communitySectionModule }, cb)
    }

    function openInviteFriendsToCommunityByIdPopup(communityId, cb) {
        const communitySectionModuleData = root.chatStore.getCommunitySectionModule(communityId)
        const communityData = root.communitiesStore.getCommunityDetails(communityId)

        openPopup(inviteFriendsToCommunityPopup, { community: communityData, communitySectionModule: communitySectionModuleData }, cb)
    }

    function openContactRequestPopup(publicKey, cb) {
        const contactDetails = Utils.getContactDetailsAsJson(
                                 publicKey, false, true, true)
        const properties = { publicKey, contactDetails }

        openPopup(sendContactRequestPopupComponent, properties, cb)
    }

    function openReviewContactRequestPopup(publicKey, cb) {
        try {
            const crDetails = root.contactsStore.getLatestContactRequestForContactAsJson(publicKey)
            if (crDetails.from !== publicKey) {
                console.warn("Popups.openReviewContactRequestPopup: not matching publicKey:", publicKey)
                return
            }

            const contactDetails = Utils.getContactDetailsAsJson(
                                     publicKey, false, true, true)
            const properties = { publicKey, contactDetails, crDetails }

            openPopup(reviewContactRequestPopupComponent, properties, cb)
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
            chatId: chatId
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
        const contactDetails = Utils.getContactDetailsAsJson(
                                 publicKey, false, true, true)
        const properties = { publicKey, contactDetails }

        openPopup(removeContactConfirmationDialog, properties)
    }

    function openDeleteMessagePopup(messageId, messageStore) {
        openPopup(deleteMessageConfirmationDialogComponent,
                  {
                      messageId,
                      messageStore
                  })
    }

    function openDownloadImageDialog(imageSource) {
        // On IOS the app is sandboxed and the FileDialog has limited access to the system.
        // We'll save the image to the default location - currenty the Photos album.
        if (SQUtils.Utils.isIOS) {
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

    function openConfirmHideAssetPopup(assetSymbol, assetName, assetImage, isCommunityToken) {
        openPopup(confirmHideAssetPopup, { symbol: assetSymbol, name: assetName, icon: assetImage, isCommunityToken })
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

    function openPaymentRequestModal(callback) {
        openPopup(paymentRequestModalComponent, {callback: callback})
    }

    function openNewsMessagePopup(notification, notificationId) {
        openPopup(newsMessageComponent, {notification: notification, notificationId: notificationId})
    }

    function openInfoPopup(title, message) {
        openPopup(infoComponent, {title: title, message, message})
    }

    readonly property list<Component> _components: [
        Component {
            id: removeContactConfirmationDialog

            RemoveContactPopup {
                utilsStore: root.utilsStore

                onAccepted: {
                    root.contactsStore.removeContact(publicKey)
                    if (removeIDVerification)
                        root.contactsStore.removeTrustStatus(publicKey)
                    if (markAsUntrusted) {
                        root.contactsStore.markUntrustworthy(publicKey)
                        Global.displaySuccessToastMessage(qsTr("%1 removed from contacts and marked as untrusted").arg(mainDisplayName))
                    } else {
                        Global.displaySuccessToastMessage(qsTr("%1 removed from contacts").arg(mainDisplayName))
                    }
                    close()
                }
                onClosed: destroy()
            }
        },

        Component {
            id: markAsIDVerifiedPopupComponent
            MarkAsIDVerifiedDialog {
                utilsStore: root.utilsStore

                onAccepted: {
                    root.contactsStore.markAsTrusted(publicKey)
                    Global.displaySuccessToastMessage(qsTr("%1 marked as trusted").arg(mainDisplayName))
                    close()
                }
                onClosed: destroy()
            }
        },

        Component {
            id: removeIDVerificationPopupComponent
            RemoveIDVerificationDialog {
                utilsStore: root.utilsStore

                onAccepted: {
                    if (markAsUntrusted && removeContact) {
                        root.contactsStore.markUntrustworthy(publicKey)
                        root.contactsStore.removeContact(publicKey)
                        Global.displaySuccessToastMessage(qsTr("%1 trust mark removed, removed from contacts and marked as untrusted").arg(mainDisplayName))
                    } else if (markAsUntrusted) {
                        root.contactsStore.markUntrustworthy(publicKey)
                        Global.displaySuccessToastMessage(qsTr("%1 trust mark removed and marked as untrusted").arg(mainDisplayName))
                    } else if (removeContact) {
                        root.contactsStore.removeContact(publicKey)
                        Global.displaySuccessToastMessage(qsTr("%1 trust mark removed and removed from contacts").arg(mainDisplayName))
                    } else {
                        root.contactsStore.removeTrustStatus(publicKey)
                    }
                    close()
                }
                onClosed: destroy()
            }
        },

        Component {
            id: inviteFriendsToCommunityPopup

            InviteFriendsToCommunityPopup {
                contactsModel: root.mutualContactsModel

                onClosed: destroy()
            }
        },
        Component {
            id: sendContactRequestPopupComponent

            SendContactRequestModal {
                contactsStore: root.contactsStore
                utilsStore: root.utilsStore

                onAccepted: root.contactsStore.sendContactRequest(publicKey, message)
                onClosed: destroy()
            }
        },

        Component {
            id: reviewContactRequestPopupComponent
            ReviewContactRequestPopup {
                utilsStore: root.utilsStore

                onAccepted: {
                    root.contactsStore.acceptContactRequest(publicKey, contactRequestId)
                    Global.displaySuccessToastMessage(qsTr("Contact request accepted"))
                    close()
                }
                onDiscarded: {
                    root.contactsStore.dismissContactRequest(publicKey, contactRequestId)
                    Global.displaySuccessToastMessage(qsTr("Contact request ignored"))
                    close()
                }
                onClosed: destroy()
            }
        },

        Component {
            id: backupSeedModalComponent
            BackupSeedModal {
                mnemonic: root.privacyStore.getMnemonic()
                onBackupSeedphraseFinished: function(removeSeedphrase) {
                    if (removeSeedphrase)
                        root.privacyStore.removeMnemonic()
                    root.profileStore.setUserDeclinedBackupBanner() // remove the banner
                    Global.displaySuccessToastMessage(removeSeedphrase ? qsTr("Recovery phrase permanently removed from Status application storage")
                                                                       : qsTr("You backed up your recovery phrase. Access it in Settings"))
                }
                onClosed: destroy()
            }
        },

        Component {
            id: downloadPageComponent
            DownloadPage {
                onClosed: destroy()
            }
        },

        Component {
            id: imagePopupComponent
            StatusImageModal {
                id: imagePopup
                onClosed: destroy()
            }
        },

        Component {
            id: videoPopupComponent
            StatusVideoModal {
                id: videoPopup
                onClosed: destroy()
            }
        },

        Component {
            id: profilePopupComponent
            ProfileDialog {
                id: profilePopup

                property string publicKey
                readonly property bool isCurrentUser: contactDetails.isCurrentUser

                ContactModelEntry {
                    id: contactModelEntry
                    publicKey: profilePopup.publicKey
                    contactsModel: root.allContactsModel
                    onPopulateContactDetailsRequested: {
                        root.contactsStore.populateContactDetails(profilePopup.publicKey)
                    }
                }

                contactDetails: contactModelEntry.contactDetails

                profileStore: root.profileStore
                contactsStore: root.contactsStore
                walletStore: WalletStores.RootStore
                utilsStore: root.utilsStore
                networksStore: root.networksStore

                sendToAccountEnabled: root.networkConnectionStore.sendBuyBridgeEnabled

                showcaseCommunitiesModel: isCurrentUser ? root.profileStore.ownShowcaseCommunitiesModel
                                                        : root.contactsStore.contactShowcaseCommunitiesModel
                showcaseAccountsModel: isCurrentUser ? root.profileStore.ownShowcaseAccountsModel
                                                     : root.contactsStore.contactShowcaseAccountsModel
                showcaseCollectiblesModel: isCurrentUser ? root.profileStore.ownShowcaseCollectiblesModel
                                                         : root.contactsStore.contactShowcaseCollectiblesModel
                showcaseSocialLinksModel: isCurrentUser ? root.profileStore.ownShowcaseSocialLinksModel
                                                        : root.contactsStore.contactShowcaseSocialLinksModel
                
                assetsModel: rootStore.globalAssetsModel
                collectiblesModel: rootStore.globalCollectiblesModel

                onOpened: {
                    isCurrentUser ? root.profileStore.requestProfileShowcasePreferences()
                                  : root.contactsStore.requestContactShowcase(publicKey)
                }
                onClosed: {
                    if (profilePopup.parentPopup) {
                        profilePopup.parentPopup.close()
                    }
                    destroy()
                }
            }
        },

        Component {
            id: changeProfilePicComponent
            ImageCropWorkflow {
                title: qsTr("Profile Picture")
                acceptButtonText: qsTr("Make this my Profile Pic")
                onImageCropped: (image, cropRect) => {
                    if (!callback) {
                        console.error("ImageCropWorkflow: no callback provided")
                        return
                    }
                    callback(image,
                             cropRect.x.toFixed(),
                             cropRect.y.toFixed(),
                             (cropRect.x + cropRect.width).toFixed(),
                             (cropRect.y + cropRect.height).toFixed())
                }
                onDone: destroy()
            }
        },

        Component {
            id: communityProfilePopup

            CommunityProfilePopup {
                onClosed: destroy()
            }
        },

        Component {
            id: communityRulesPopup

            CommunityRulesPopup {
                onClosed: destroy()
            }
        },

        Component {
            id: pinnedMessagesPopup

            PinnedMessagesPopup {
                utilsStore: root.utilsStore

                // Unfurling related data:
                gifUnfurlingEnabled: root.sharedRootStore.gifUnfurlingEnabled
                neverAskAboutUnfurlingAgain: root.sharedRootStore.neverAskAboutUnfurlingAgain

                onClosed: destroy()

                // Unfurling related requests:
                onSetNeverAskAboutUnfurlingAgain: root.sharedRootStore.setNeverAskAboutUnfurlingAgain(neverAskAgain)
            }
        },

        Component {
            id: nicknamePopupComponent

            NicknamePopup {
                utilsStore: root.utilsStore

                onEditDone: {
                    if (nickname !== newNickname) {
                        root.contactsStore.changeContactNickname(publicKey, newNickname, optionalDisplayName, !!nickname)
                    }
                    close()
                }
                onRemoveNicknameRequested: {
                    root.contactsStore.changeContactNickname(publicKey, "", optionalDisplayName, true)
                    close()
                }
                onClosed: destroy()
            }
        },

        Component {
            id: markAsUntrustedComponent
            MarkAsUntrustedPopup {
                utilsStore: root.utilsStore

                onAccepted: {
                    root.contactsStore.markUntrustworthy(publicKey)
                    if (removeContact) {
                        root.contactsStore.removeContact(publicKey)
                        Global.displaySuccessToastMessage(qsTr("%1 removed from contacts and marked as untrusted").arg(mainDisplayName))
                    } else {
                        Global.displaySuccessToastMessage(qsTr("%1 marked as untrusted").arg(mainDisplayName))
                    }
                    close()
                }
                onClosed: destroy()
            }
        },

        Component {
            id: unblockContactConfirmationComponent
            UnblockContactConfirmationDialog {
                utilsStore: root.utilsStore

                onAccepted: {
                    root.contactsStore.unblockContact(publicKey)
                    Global.displaySuccessToastMessage(qsTr("%1 unblocked").arg(mainDisplayName))
                    close()
                }
                onClosed: destroy()
            }
        },

        Component {
            id: blockContactConfirmationComponent
            BlockContactConfirmationDialog {
                utilsStore: root.utilsStore

                onAccepted: {
                    root.contactsStore.blockContact(publicKey)
                    if (removeIDVerification)
                        root.contactsStore.removeTrustStatus(publicKey)
                    if (removeContact)
                        root.contactsStore.removeContact(publicKey)
                    Global.displaySuccessToastMessage(qsTr("%1 blocked").arg(mainDisplayName))
                    close()
                }
                onClosed: destroy()
            }
        },

        Component {
            id: importCommunitiesPopupComponent
            ImportCommunityPopup {
                id: importPopup

                property CommunityStores.CommunityRootStore communityRootStore: root.messagingRootStore.createCommunityRootStore(this, importPopup.communityId)
                readonly property CommunityStores.CommunityAccessStore communityAccessStore: communityRootStore ?
                                                                                                 communityRootStore.communityAccessStore : null

                store: root.communitiesStore
                utilsStore: root.utilsStore
                onJoinCommunityRequested: function(communityId, communityDetails) {
                    close()
                    communityAccessStore.spectateCommunity(communityId)
                    openCommunityIntroPopup(communityId,
                                            communityDetails.name,
                                            communityDetails.introMessage,
                                            communityDetails.image,
                                            communityAccessStore.isMyCommunityRequestPending(communityId))
                }
                onClosed: destroy()
            }
        },

        Component {
            id: communityJoinDialogPopup

            CommunityMembershipSetupDialog {
                id: dialogRoot

                property CommunityStores.CommunityRootStore communityRootStore: root.messagingRootStore.createCommunityRootStore(this, dialogRoot.communityId)
                readonly property CommunityStores.CommunityAccessStore communityAccessStore: communityRootStore ?
                                                                                                 communityRootStore.communityAccessStore : null

                requirementsCheckPending: communityAccessStore ? communityAccessStore.spectatedPermissionsCheckOngoing : false
                checkingPermissionToJoinInProgress: root.rootStore.checkingPermissionToJoinInProgress
                joinPermissionsCheckCompletedWithoutErrors: root.rootStore.joinPermissionsCheckCompletedWithoutErrors

                walletAccountsModel: root.rootStore.walletAccountsModel
                walletCollectiblesModel: WalletStores.RootStore.collectiblesStore.allCollectiblesModel

                canProfileProveOwnershipOfProvidedAddressesFn: WalletStores.RootStore.canProfileProveOwnershipOfProvidedAddresses

                walletAssetsModel: walletAssetsStore.groupedAccountAssetsModel
                permissionsModel: {
                    if(communityAccessStore) {
                        communityAccessStore.prepareTokenModelForCommunity(dialogRoot.communityId)
                        return communityAccessStore.spectatedPermissionsModel
                    }
                    return null
                }
                assetsModel: root.rootStore.assetsModel
                collectiblesModel: root.rootStore.collectiblesModel

                getCurrencyAmount: (balance, key) => {
                    return currencyStore.getCurrencyAmount(balance, key)
                }

                onPrepareForSigning: {
                    if(communityAccessStore) {
                        communityAccessStore.prepareKeypairsForSigning(dialogRoot.communityId, dialogRoot.name, sharedAddresses, airdropAddress, false)
                        dialogRoot.keypairSigningModel = root.rootStore.communitiesModuleInst.keypairsSigningModel
                    }
                }

                onSignProfileKeypairAndAllNonKeycardKeypairs: {
                    if(communityAccessStore) {
                        communityAccessStore.signProfileKeypairAndAllNonKeycardKeypairs()
                    }
                }

                onSignSharedAddressesForKeypair: {
                    if(communityAccessStore) {
                        communityAccessStore.signSharedAddressesForKeypair(keyUid)
                    }
                }

                onJoinCommunity: {
                    if(communityAccessStore) {
                        communityAccessStore.joinCommunityOrEditSharedAddresses()
                    }
                }

                onCancelMembershipRequest: {
                    if(communityAccessStore) {
                        communityAccessStore.cancelPendingRequest(dialogRoot.communityId)
                    }
                }

                onSharedAddressesUpdated: {
                    if(communityAccessStore) {
                        communityAccessStore.updatePermissionsModel(dialogRoot.communityId, sharedAddresses)
                    }
                }

                onAboutToShow: { root.rootStore.communityKeyToImport = dialogRoot.communityId; }

                onClosed: {
                    root.rootStore.communityKeyToImport = "";
                    if(communityAccessStore) {
                        communityAccessStore.cleanJoinEditCommunityData()
                    }
                }

                Connections {
                    target: dialogRoot.communityAccessStore

                    function onCommunityAccessFailed(communityId: string, error: string) {
                        if (communityId !== dialogRoot.communityId)
                            return
                        dialogRoot.close();
                    }

                    function onAllSharedAddressesSigned() {

                        if (dialogRoot.profileProvesOwnershipOfSelectedAddresses) {
                            dialogRoot.joinCommunity()
                            dialogRoot.close()
                            return
                        }

                        if (dialogRoot.allAddressesToRevealBelongToSingleNonProfileKeypair) {
                            dialogRoot.joinCommunity()
                            dialogRoot.close()
                            return
                        }

                        if (!!dialogRoot.replaceItem) {
                            dialogRoot.replaceLoader.item.allSigned()
                        }
                    }
                }
            }
        },

        Component {
            id: createCommunitiesPopupComponent
            CreateCommunityPopup {
                store: root.communitiesStore
                advancedStore: root.advancedStore
                isDevBuild: root.isDevBuild
                onClosed: {
                    destroy()
                }
            }
        },

        Component {
            id: discordImportProgressDialog
            DiscordImportProgressDialog {
                store: root.communitiesStore
            }
        },

        Component {
            id: deleteMessageConfirmationDialogComponent
            DeleteMessageConfirmationPopup {
                onClosed: destroy()
            }
        },

        Component {
            id: downloadImageDialogComponent

            StatusFolderDialog {
                property string imageSource

                title: qsTr("Please choose a directory")
                modality: Qt.NonModal
                currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)

                onAccepted: {
                    SystemUtils.downloadImageByUrl(imageSource, selectedFolder)
                    destroy()
                }
                onRejected: {
                    destroy()
                }
            }
        },

        Component {
            id: leaveCommunityPopupComponent
            StatusModal {
                id: leavePopup

                property string community
                property string communityId
                property string outroMessage

                headerSettings.title: qsTr("Are you sure want to leave '%1'?").arg(community)
                padding: 16
                width: 640
                contentItem: ColumnLayout {
                    spacing: 16
                    StatusBaseText {
                        id: outroMessage
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        text: leavePopup.outroMessage
                        visible: !!text
                    }
                    StatusMenuSeparator {
                        Layout.fillWidth: true
                        visible: outroMessage.visible
                    }
                    StatusBaseText {
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        font.pixelSize: Theme.additionalTextSize
                        text: qsTr("You will need to request to join if you want to become a member again in the future. If you joined the Community via public key ensure you have a copy of it before you go.")
                    }
                }

                rightButtons: [
                    StatusFlatButton {
                        text: qsTr("Cancel")
                        onClicked: leavePopup.close()
                    },
                    StatusButton {
                        objectName: "CommunitiesListPanel_leaveCommunityButtonInPopup"
                        type: StatusBaseButton.Type.Danger
                        text: qsTr("Leave %1").arg(leavePopup.community)
                        onClicked: {
                            leavePopup.close()
                            root.communitiesStore.leaveCommunity(leavePopup.communityId)
                        }
                    }
                ]

                onClosed: destroy()
            }
        },

        Component {
            id: testnetModal
            AlertPopup {
                width: 521
                readonly property string mainTitle: root.networksStore.areTestNetworksEnabled ? qsTr("Turn off testnet mode") : qsTr("Turn on testnet mode")
                title: mainTitle
                alertLabel.textFormat: Text.RichText
                alertText: root.networksStore.areTestNetworksEnabled ?
                               qsTr("Are you sure you want to turn off %1? All future transactions will be performed on live networks with real funds").arg("<html><span style='font-weight: 500;'>testnet mode</span></html>") :
                               qsTr("Are you sure you want to turn on %1? In this mode, all blockchain data displayed will come from testnets and all blockchain interactions will be with testnets. Testnet mode switches the entire app to using testnets only. Please switch this mode on only if you know exactly why you need to use it.").arg("<html><span style='font-weight: 500;'>testnet mode</span></html>")
                acceptBtnText: mainTitle
                acceptBtnType: root.networksStore.areTestNetworksEnabled ? StatusBaseButton.Type.Normal : StatusBaseButton.Type.Warning
                asset.name: "settings"
                asset.color: Theme.palette.warningColor1
                asset.bgColor: Theme.palette.warningColor3
                onAcceptClicked: {
                    root.networksStore.toggleTestNetworksEnabled()
                    Global.displayToastMessage(root.networksStore.areTestNetworksEnabled ? qsTr("Testnet mode turned on") : qsTr("Testnet mode turned off") , "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
                }
                onCancelClicked: close()
            }
        },

        Component {
            id: exportControlNodePopup
            ExportControlNodePopup {
                devicesStore: root.devicesStore
                onClosed: destroy()
            }
        },

        Component {
            id: importControlNodePopup
            ImportControlNodePopup {
                onClosed: destroy()
                onImportControlNode: root.rootStore.promoteSelfToControlNode(communityId)
            }
        },

        Component {
            id: editSharedAddressesPopupComponent

            CommunityMembershipSetupDialog {
                id: editSharedAddressesPopup

                // TODO: This will be replaced at some point to some combination of `CommunityStores` objects
                readonly property ChatStores.RootStore chatStore: ChatStores.RootStore {
                    contactsStore: root.contactsStore
                    isChatSectionModule: false
                    communityId: editSharedAddressesPopup.communityId
                }

                property CommunityStores.CommunityRootStore communityRootStore:  root.messagingRootStore.createCommunityRootStore(this, editSharedAddressesPopup.communityId)
                readonly property CommunityStores.CommunityAccessStore communityAccessStore: communityRootStore ?
                                                                                                 communityRootStore.communityAccessStore : null

                isEditMode: true

                currentSharedAddresses: root.rootStore.myRevealedAddressesForCurrentCommunity
                currentAirdropAddress: root.rootStore.myRevealedAirdropAddressForCurrentCommunity

                communityName: chatStore.sectionDetails.name
                communityIcon: chatStore.sectionDetails.image

                requirementsCheckPending: communityAccessStore ? communityAccessStore.spectatedPermissionsCheckOngoing : false
                checkingPermissionToJoinInProgress: root.rootStore.checkingPermissionToJoinInProgress
                joinPermissionsCheckCompletedWithoutErrors: root.rootStore.joinPermissionsCheckCompletedWithoutErrors

                introMessage: chatStore.sectionDetails.introMessage

                canProfileProveOwnershipOfProvidedAddressesFn: WalletStores.RootStore.canProfileProveOwnershipOfProvidedAddresses

                walletAccountsModel: root.rootStore.walletAccountsModel

                walletAssetsModel: walletAssetsStore.groupedAccountAssetsModel
                walletCollectiblesModel: WalletStores.RootStore.collectiblesStore.allCollectiblesModel

                permissionsModel: {
                    if(communityAccessStore) {
                        communityAccessStore.prepareTokenModelForCommunity(editSharedAddressesPopup.communityId)
                        return communityAccessStore.spectatedPermissionsModel
                    }
                    return null
                }
                assetsModel: chatStore.assetsModel
                collectiblesModel: chatStore.collectiblesModel

                getCurrencyAmount: (balance, key) => {
                    return root.currencyStore.getCurrencyAmount(balance, key)
                }

                onSharedAddressesUpdated: {
                    if(communityAccessStore) {
                        communityAccessStore.updatePermissionsModel(editSharedAddressesPopup.communityId, sharedAddresses)
                    }
                }

                onPrepareForSigning: {
                    if(communityAccessStore) {
                        communityAccessStore.prepareKeypairsForSigning(editSharedAddressesPopup.communityId, "", sharedAddresses, airdropAddress, true)
                        editSharedAddressesPopup.keypairSigningModel = root.rootStore.communitiesModuleInst.keypairsSigningModel
                    }
                }

                onSignProfileKeypairAndAllNonKeycardKeypairs: {
                    if(communityAccessStore) {
                        communityAccessStore.signProfileKeypairAndAllNonKeycardKeypairs()
                    }
                }

                onSignSharedAddressesForKeypair: {
                    if(communityAccessStore) {
                        communityAccessStore.signSharedAddressesForKeypair(keyUid)
                    }
                }

                onEditRevealedAddresses: {
                    communityAccessStore.joinCommunityOrEditSharedAddresses()
                }

                onClosed: {
                    communityAccessStore.cleanJoinEditCommunityData()
                }

                Connections {
                    target: editSharedAddressesPopup.communityAccessStore

                    function onAllSharedAddressesSigned() {
                        if (editSharedAddressesPopup.profileProvesOwnershipOfSelectedAddresses) {
                            editSharedAddressesPopup.editRevealedAddresses()
                            editSharedAddressesPopup.close()
                            return
                        }

                        if (editSharedAddressesPopup.allAddressesToRevealBelongToSingleNonProfileKeypair) {
                            editSharedAddressesPopup.editRevealedAddresses()
                            editSharedAddressesPopup.close()
                            return
                        }

                        if (!!editSharedAddressesPopup.replaceItem) {
                            editSharedAddressesPopup.replaceLoader.item.allSigned()
                        }
                    }
                }
            }
        },

        Component {
            id: transferOwnershipPopup
            TransferOwnershipPopup {
                onTransferOwnershipRequested: root.transferOwnershipRequested(
                                                  tokenId, senderAddress)
                onClosed: destroy()
            }
        },

        Component {
            id: confirmExternalLinkPopup
            ConfirmExternalLinkPopup {
                destroyOnClose: true
                onOpenExternalLink: (link) => root.openExternalLink(link)
                onSaveDomainToUnfurledWhitelist: (domain) => root.saveDomainToUnfurledWhitelist(domain)
            }
        },

        // Components related to transfer community ownership flow:
        Component {
            id: finaliseOwnershipPopup
            FinaliseOwnershipPopup {
                id: finalisePopup

                property string communityId
                readonly property var ownerTokenDetails: root.communityTokensStore.ownerTokenDetails
                readonly property var communityData : root.communitiesStore.getCommunityDetailsAsJson(communityId)

                readonly property TransactionFeesBroker feesBroker: TransactionFeesBroker {
                    communityTokensStore: root.communityTokensStore
                    active: finalisePopup.contentItem.Window.window.active
                }

                Component.onCompleted: root.communityTokensStore.asyncGetOwnerTokenDetails(communityId)

                communityName: communityData.name
                communityLogo: communityData.image
                communityColor: communityData.color

                tokenSymbol: ownerTokenDetails.symbol
                tokenChainName: ownerTokenDetails.chainName

                feeText: feeSubscriber.feeText
                feeErrorText: feeSubscriber.feeErrorText
                isFeeLoading: !feeSubscriber.feesResponse

                accounts: WalletStores.RootStore.nonWatchAccounts

                destroyOnClose: true

                onRejectClicked: Global.openDeclineOwnershipPopup(finalisePopup.communityId, communityData.name)
                onFinaliseOwnershipClicked: signPopup.open()

                onVisitCommunityClicked: communitiesStore.navigateToCommunity(finalisePopup.communityId)
                onOpenControlNodeDocClicked:(link) => Global.requestOpenLink(link)

                onCalculateFees: {
                    feesBroker.registerSetSignerFeesSubscriber(feeSubscriber)
                }

                onStopUpdatingFees: {
                    communityTokensStore.stopUpdatesForSuggestedRoute()
                }

                onClosed: {
                    communityTokensStore.stopUpdatesForSuggestedRoute()
                }

                SetSignerFeesSubscriber {
                    id: feeSubscriber
                    communityId: finalisePopup.communityId
                    chainId: finalisePopup.ownerTokenDetails.chainId
                    contractAddress: finalisePopup.ownerTokenDetails.contractAddress
                    accountAddress: finalisePopup.selectedAccountAddress
                    enabled: finalisePopup.visible || signPopup.visible
                }

                SignTransactionsPopup {
                    id: signPopup

                    title: qsTr("Sign transaction - update %1 smart contract").arg(finalisePopup.communityName)
                    totalFeeText: finalisePopup.isFeeLoading ? "" : finalisePopup.feeText
                    errorText: finalisePopup.feeErrorText
                    accountName: finalisePopup.ownerTokenDetails.accountName

                    model: QtObject {
                        readonly property string title: finalisePopup.feeLabel
                        readonly property string feeText: signPopup.totalFeeText
                        readonly property bool error: finalisePopup.feeErrorText !== ""
                    }

                    onSignTransactionClicked: {
                        finalisePopup.close()
                        root.communityTokensStore.authenticateAndTransfer()
                    }
                }

                Connections {
                    target: root
                    function onOwnershipDeclined(communityId: string, communityName: string) {
                        finalisePopup.close()
                        root.communityTokensStore.ownershipDeclined(communityId, communityName)
                    }
                }
            }
        },

        Component {
            id: declineOwnershipPopup
            FinaliseOwnershipDeclinePopup {
                destroyOnClose: true

                onDeclineClicked: root.ownershipDeclined(communityId, communityName)
            }
        },
        // End of components related to transfer community ownership flow.

        Component {
            id: firstTokenReceivedPopup

            FirstTokenReceivedPopup {
                destroyOnClose: true
                communitiesStore: root.communitiesStore

                onHideClicked: (tokenSymbol, tokenName, tokenImage, isAsset) => isAsset ? root.openConfirmHideAssetPopup(tokenSymbol, tokenName, tokenImage, true)
                                                                                        : root.openConfirmHideCollectiblePopup(tokenSymbol, tokenName, tokenImage, true)
            }
        },
        Component {
            id: confirmHideAssetPopup
            ConfirmHideAssetPopup {
                destroyOnClose: true

                required property bool isCommunityToken

                onConfirmButtonClicked: {
                    if (isCommunityToken)
                        root.walletAssetsStore.assetsController.showHideCommunityToken(symbol, false)
                    else
                        root.walletAssetsStore.assetsController.showHideRegularToken(symbol, false)
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
            id: communityMemberMessagesPopup
            CommunityMemberMessagesPopup {
                sharedRootStore: root.sharedRootStore
                utilsStore: root.utilsStore
                onClosed: destroy()
            }
        },
        Component {
            id: buyCryptoModal
            BuyCryptoModal {
                buyProvidersModel: root.buyCryptoStore.providersModel
                isBuyProvidersModelLoading: root.buyCryptoStore.areProvidersLoading
                currentCurrency: root.currencyStore.currentCurrency
                walletAccountsModel: root.rootStore.accounts
                tokenGroupsModel: root.walletAssetsStore.walletTokensStore.tokenGroupsModel
                groupedAccountAssetsModel: root.walletAssetsStore.groupedAccountAssetsModel
                networksModel: root.networksStore.activeNetworks
                Component.onCompleted: {
                    fetchProviders.connect(root.buyCryptoStore.fetchProviders)
                    fetchProviderUrl.connect(root.buyCryptoStore.fetchProviderUrl)
                    root.buyCryptoStore.providerUrlReady.connect(providerUrlReady)
                }
                onClosed: destroy()
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
            id: paymentRequestModalComponent
            PaymentRequestModal {
                id: paymentRequestModal

                property var callback: null
                currentCurrency: root.currencyStore.currentCurrency
                formatCurrencyAmount: root.currencyStore.formatCurrencyAmount
                flatNetworksModel: root.networksStore.activeNetworks
                accountsModel: WalletStores.RootStore.nonWatchAccounts

                tokenGroupsForChainModel: WalletStores.RootStore.tokensStore.tokenGroupsForChainModel
                searchResultModel: WalletStores.RootStore.tokensStore.searchResultModel

                onBuildGroupsForChain: {
                    WalletStores.RootStore.tokensStore.buildGroupsForChain(selectedNetworkChainId, "")
                }

                onAccepted: {
                    if (!callback) {
                        console.error("No callback set for Payment Request")
                        return
                    }
                    callback(selectedAccountAddress, amount, selectedTokenKey, selectedSymbol, selectedTokenLogoUri)
                }
                destroyOnClose: true
            }
        },
        Component {
            id: newsMessageComponent

            NewsMessagePopup {
                activityCenterNotifications: root.activityCenterStore.activityCenterNotifications
                onLinkClicked: (link) => Global.requestOpenLink(link)
            }
        },
        Component {
            id: quitConfirmPopupComponent

            ConfirmationDialog {
                id: confirmDialog
                confirmButtonObjectName: "signOutConfirmation"
                headerSettings.title: qsTr("Sign out")
                confirmationText: qsTr("Make sure you have your account password and recovery phrase stored. Without them you can lock yourself out of your account and lose funds.")
                confirmButtonLabel: qsTr("Sign out & Quit")
                onConfirmButtonClicked: Qt.exit(0)
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
        }
    ]
}
