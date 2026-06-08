import QtCore
import QtQml
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models

import AppLayouts.Chat
import AppLayouts.Chat.views
import AppLayouts.Wallet
import AppLayouts.Market.stores
import AppLayouts.Wallet.services.dapps
import AppLayouts.ActivityCenter.helpers
import AppLayouts.ActivityCenter.panels
import AppLayouts.ActivityCenter.adaptors

import utils
import shared
import shared.controls
import shared.controls.chat.menuItems
import shared.panels
import shared.popups
import shared.popups.keycard
import shared.status
import shared.stores as SharedStores
import shared.popups.send as SendPopups
import shared.popups.send.views
import shared.stores.send

import StatusQ
import StatusQ.Components
import StatusQ.Components.private
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Layout
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.stores
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Profile.helpers
import AppLayouts.Wallet.popups as WalletPopups
import AppLayouts.Wallet.popups.dapps as DAppsPopups
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores as AppStores
import AppLayouts.stores.Messaging as MessagingStores

import mainui.adaptors
import mainui.Handlers
import mainui.sectionLoaders

import QtModelsToolkit
import SortFilterProxyModel
import MobileUI

Item {
    id: appMain

    // Primary store container — all additional stores should be initialized under this root
    readonly property AppStores.RootStore rootStore: AppStores.RootStore {
        localBackupEnabled: appMain.featureFlagsStore.localBackupEnabled
        thirdpartyServicesEnabled: appMain.featureFlagsStore.privacyModeFeatureEnabled ?
                                   appMain.privacyStore.thirdpartyServicesEnabled: true
        onOpenUrl: (link) => Global.requestOpenLink(link)
        onOpenActivityCenter: () => {
            appMain.activityCenterStore.setActiveNotificationGroup(ActivityCenterTypes.ActivityCenterGroup.All)
            mainLayoutItem.openACCenterPanel = true
        }
        onWcLinkActivated: (link) => {
            const wcUri = Utils.walletConnectUriFromStatusLink(link)
            if (!!wcUri) {
                d.pairWalletConnectUri(wcUri)
            }
        }
        keychain: appMain.keychain
        palette: appMain.Theme.palette
    }

    // Global cross-domain stores (just references from `rootStore`)
    readonly property AppStores.AccountSettingsStore accountSettingsStore: rootStore.accountSettingsStore
    readonly property AppStores.ContactsStore contactsStore: rootStore.contactsStore
    readonly property AppStores.ActivityCenterStore activityCenterStore: rootStore.activityCenterStore

    // Settings (just references from `rootStore`)
    readonly property ProfileStores.AboutStore aboutStore: rootStore.profileSectionStore.aboutStore
    readonly property ProfileStores.ProfileStore profileStore: rootStore.profileSectionStore.profileStore
    readonly property ProfileStores.DevicesStore devicesStore: rootStore.profileSectionStore.devicesStore
    readonly property ProfileStores.AdvancedStore advancedStore: rootStore.profileSectionStore.advancedStore
    readonly property ProfileStores.PrivacyStore privacyStore: rootStore.profileSectionStore.privacyStore
    readonly property ProfileStores.NotificationsStore notificationsStore: rootStore.profileSectionStore.notificationsStore
    readonly property ProfileStores.KeycardStore keycardStore: rootStore.profileSectionStore.keycardStore
    readonly property ProfileStores.KeycardNewStore keycardNewStore: rootStore.profileSectionStore.keycardNewStore
    readonly property ProfileStores.WalletStore walletProfileStore: rootStore.profileSectionStore.walletStore
    readonly property ProfileStores.EnsUsernamesStore ensUsernamesStore: rootStore.profileSectionStore.ensUsernamesStore

    // Messaging (just references from `rootStore`)
    readonly property MessagingStores.MessagingRootStore messagingRootStore: rootStore.messagingRootStore
    readonly property MessagingStores.MessagingSettingsStore messagingSettingsStore: rootStore.messagingRootStore.messagingSettingsStore

    // Note: The following stores have not yet been refactored to follow the entry-point pattern via the main root store
    readonly property SharedStores.RootStore sharedRootStore: SharedStores.RootStore {
        currencyStore: appMain.currencyStore
    }

    property SharedStores.UtilsStore utilsStore

    readonly property SharedStores.NetworksStore networksStore: SharedStores.NetworksStore {}

    property ChatStores.RootStore rootChatStore: ChatStores.RootStore {
        contactsStore: appMain.contactsStore
        currencyStore: appMain.currencyStore
        communityTokensStore: appMain.communityTokensStore
        openCreateChat: createChatView.opened
        networkConnectionStore: appMain.networkConnectionStore
    }
    property ChatStores.CreateChatPropertiesStore createChatPropertiesStore: ChatStores.CreateChatPropertiesStore {}
    property SharedStores.NetworkConnectionStore networkConnectionStore: SharedStores.NetworkConnectionStore {
        networksStore: appMain.networksStore
        isOnline: d.networkChecker.isOnline
    }
    property SharedStores.CommunityTokensStore communityTokensStore: SharedStores.CommunityTokensStore {
        currencyStore: appMain.currencyStore
    }
    property CommunitiesStore communitiesStore: CommunitiesStore {}
    readonly property WalletStores.TokensStore tokensStore: WalletStores.RootStore.tokensStore
    readonly property WalletStores.WalletAssetsStore walletAssetsStore: WalletStores.RootStore.walletAssetsStore
    readonly property WalletStores.CollectiblesStore walletCollectiblesStore: WalletStores.RootStore.collectiblesStore
    readonly property SharedStores.CurrenciesStore currencyStore: SharedStores.CurrenciesStore {}
    readonly property TransactionStore transactionStore: TransactionStore {
        walletAssetStore: appMain.walletAssetsStore
        tokensStore: appMain.tokensStore
        currencyStore: appMain.currencyStore
        networksStore: appMain.networksStore
    }
    readonly property WalletStores.BuyCryptoStore buyCryptoStore: WalletStores.BuyCryptoStore {}
    readonly property BrowserStores.BrowserPreferencesStore browserPreferencesStore: BrowserStores.BrowserPreferencesStore {}

    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property ProfileStores.LanguageStore languageStore
    // TODO: Only until the  old send modal transaction store can be replaced with this one
    readonly property WalletStores.TransactionStoreNew transactionStoreNew: WalletStores.TransactionStoreNew {}

    readonly property MarketStore marketStore: MarketStore {}

    required property Keychain keychain

    required property bool systemTrayIconAvailable

    readonly property bool isPortraitMode: appMain.width < ThemeUtils.portraitBreakpoint.width

    function showEnableBiometricsFlow() {
        popupRequestsHandler.openEnableBiometricsPopup()
    }

    ContactDetails {
        id: ownContactDetails
        isCurrentUser: true
        publicKey: appMain.profileStore.pubKey
        compressedPubKey: appMain.profileStore.compressedPubKey
        displayName: appMain.profileStore.displayName
        ensName: appMain.profileStore.name
        ensVerified: !!ensName && Utils.isValidEns(ensName)
        preferredDisplayName: appMain.profileStore.preferredName
        alias: appMain.profileStore.username
        usesDefaultName: appMain.profileStore.usesDefaultName
        icon: appMain.profileStore.icon
        colorId: appMain.profileStore.colorId
        onlineStatus: appMain.profileStore.currentUserStatus
        thumbnailImage: appMain.profileStore.thumbnailImage
        largeImage: appMain.profileStore.largeImage
        bio: appMain.profileStore.bio
    }

    AllContactsAdaptor {
        id: allContacsAdaptor

        contactsModel: appMain.contactsStore.contactsModel
        selfContactDetails: ownContactDetails
    }

    ContactsModelAdaptor {
        id: contactsModelAdaptor

        allContacts: appMain.contactsStore.contactsModel
    }

    // Central UI point for managing app toasts:
    ToastsManager {
        id: toastsManager

        rootStore: appMain.rootStore
        contactsStore: appMain.contactsStore
        rootChatStore: appMain.rootChatStore
        communityTokensStore: appMain.communityTokensStore
        profileStore: appMain.profileStore
        devicesStore: appMain.devicesStore

        onSendRequested: popupRequestsHandler.openSend()
    }

    Connections {
        target: rootStore

        function onDisplayUserProfile(publicKey: string) {
            popups.openProfilePopup(publicKey)
        }

        function onDisplayKeycardSharedModuleForAuthenticationOrSigning() {
            keycardPopupForAuthenticationOrSigning.active = true
        }

        function onDestroyKeycardSharedModuleForAuthenticationOrSigning() {
            keycardPopupForAuthenticationOrSigning.active = false
        }

        function onDisplayKeycardSharedModuleFlow() {
            keycardPopup.active = true
        }

        function onDestroyKeycardSharedModuleFlow() {
            keycardPopup.active = false
        }

        function onPlayNotificationSound() {
            notificationSound.stop()
            notificationSound.play()
        }

        function onMailserverWorking() {
            mailserverConnectionBanner.hide()
        }

        function onMailserverNotWorking() {
            if (d.activeSectionType === Constants.appSection.chat || d.activeSectionType === Constants.appSection.community)
                mailserverConnectionBanner.show()
        }

        function onActiveSectionChanged() {
            createChatView.opened = false
            profileLoader.settingsSubSubsection = -1
        }

        function onShowToastAccountAdded(name: string) {
            Global.displayToastMessage(
                qsTr("\"%1\" successfully added").arg(name),
                "",
                "checkmark-circle",
                false,
                Constants.ephemeralNotificationType.success,
                ""
            )
        }

        function onShowToastAccountRemoved(name: string) {
            Global.displayToastMessage(
                        qsTr("\"%1\" successfully removed").arg(name),
                        "",
                        "checkmark-circle",
                        false,
                        Constants.ephemeralNotificationType.success,
                        ""
                        )
        }

        function onShowToastKeypairRenamed(oldName: string, newName: string) {
            Global.displayToastMessage(
                qsTr("You successfully renamed your key pair\nfrom \"%1\" to \"%2\"").arg(oldName).arg(newName),
                "",
                "checkmark-circle",
                false,
                Constants.ephemeralNotificationType.success,
                ""
            )
        }

        function onShowNetworkEndpointUpdated(name: string, isTest: bool) {
            let mainText = isTest ? qsTr("Test network settings for %1 updated").arg(name): qsTr("Live network settings for %1 updated").arg(name)
            Global.displayToastMessage(
                mainText,
                "",
                "checkmark-circle",
                false,
                Constants.ephemeralNotificationType.success,
                ""
            )
        }

        function onShowToastKeypairRemoved(keypairName: string) {
            Global.displayToastMessage(
                qsTr("“%1” key pair and its derived accounts were successfully removed from all devices").arg(keypairName),
                "",
                "checkmark-circle",
                false,
                Constants.ephemeralNotificationType.success,
                ""
            )
        }

        function onShowToastKeypairsImported(keypairName: string, keypairsCount: int, error: string) {
            let notification = qsTr("Please re-generate QR code and try importing again")
            if (error !== "") {
                if (error.startsWith("one or more expected keystore files are not found among the sent files")) {
                    notification = qsTr("Make sure you're importing the exported key pair on paired device")
                }
            }
            else {
                notification = qsTr("%1 key pair successfully imported").arg(keypairName)
                if (keypairsCount > 1) {
                    notification = qsTr("%n key pair(s) successfully imported", "", keypairsCount)
                }
            }
            Global.displayToastMessage(
                notification,
                "",
                error!==""? "info" : "checkmark-circle",
                false,
                error!==""? Constants.ephemeralNotificationType.normal : Constants.ephemeralNotificationType.success,
                ""
            )
        }

        function onShowTransactionToast(uuid: string,
                                        txType: int,
                                        fromChainId: int,
                                        toChainId: int,
                                        fromAddr: string,
                                        fromName: string,
                                        toAddr: string,
                                        toName: string,
                                        txToAddr: string,
                                        txToName: string,
                                        txHash: string,
                                        approvalTx: bool,
                                        fromAmount: string,
                                        toAmount: string,
                                        fromAsset: string,
                                        toAsset: string,
                                        username: string,
                                        publicKey: string,
                                        packId: string,
                                        communityId: string,
                                        communityName: string,
                                        communityInvolvedTokens: int,
                                        communityTotalAmount: string,
                                        communityAmount1: string,
                                        communityAmountInfinite1: bool,
                                        communityAssetName1: string,
                                        communityAssetDecimals1: int,
                                        communityAmount2: string,
                                        communityAmountInfinite2: bool,
                                        communityAssetName2: string,
                                        communityAssetDecimals2: int,
                                        communityInvolvedAddress: string,
                                        communityNubmerOfInvolvedAddresses: int,
                                        communityOwnerTokenName: string,
                                        communityMasterTokenName: string,
                                        communityDeployedTokenName: string,
                                        status: string,
                                        error: string) {

            let toastTitle = ""
            let toastSubtitle = ""
            let toastIcon = ""
            let toastLoading = false
            let toastType = Constants.ephemeralNotificationType.normal
            let toastLink = ""
            let blockExplorerUrl = ""

            const sender = !!fromName? fromName : SQUtils.Utils.elideAndFormatWalletAddress(fromAddr)
            let senderChainName = qsTr("unknown")
            let sentAmount = ""

            const recipient = !!toName? toName : SQUtils.Utils.elideAndFormatWalletAddress(toAddr)
            const txRecipient = !!txToName? txToName : SQUtils.Utils.elideAndFormatWalletAddress(txToAddr)
            let recipientChainName = qsTr("unknown")
            let receivedAmount = ""

            let assetName = qsTr("unknown")
            let ensName = d.ensName(username)
            let stickersPackName = qsTr("unknown")

            let sentCommunityAmount1 = ""
            let sentCommunityAmount2 = ""

            const fromChain = SQUtils.ModelUtils.getByKey(appMain.networksStore.activeNetworks, "chainId", fromChainId)
            if (!!fromChain) {
                senderChainName = fromChain.chainName
                blockExplorerUrl = fromChain.blockExplorerURL
            }
            const toChainName = SQUtils.ModelUtils.getByKey(appMain.networksStore.activeNetworks, "chainId", toChainId, "chainName")
            if (!!toChainName) {
                recipientChainName = toChainName
            }

            const fromToken = SQUtils.ModelUtils.getByKey(appMain.tokensStore.tokenGroupsModel, "key", fromAsset)
            if (!!fromToken) {
                sentAmount = currencyStore.formatCurrencyAmountFromBigInt(fromAmount, fromToken.symbol, fromToken.decimals)
            }

            const toToken = SQUtils.ModelUtils.getByKey(appMain.tokensStore.tokenGroupsModel, "key", toAsset)
            if (!!toToken) {
                receivedAmount = currencyStore.formatCurrencyAmountFromBigInt(toAmount, toToken.symbol, toToken.decimals)
            }

            if (!!txHash) {
                toastLink = "%1/tx/%2".arg(blockExplorerUrl).arg(txHash)
                toastSubtitle = qsTr("View on %1").arg(senderChainName)
            }

            if (txType === Constants.SendType.ERC721Transfer || txType === Constants.SendType.ERC1155Transfer) {
                const key = "%1+%2+%3".arg(fromChainId).arg(txToAddr).arg(fromAsset)
                const entry = SQUtils.ModelUtils.getByKey(appMain.walletCollectiblesStore.allCollectiblesModel, "symbol", key)
                if (!!entry) {
                    assetName = entry.name
                }
            }

            if (txType === Constants.SendType.StickersBuy) {
                const idx = appMain.rootChatStore.stickersModuleInst.stickerPacks.findIndexById(packId, false)
                if(idx >= 0) {
                    const entry = SQUtils.ModelUtils.get(appMain.rootChatStore.stickersModuleInst.stickerPacks, idx)
                    if (!!entry) {
                        stickersPackName = entry.name
                    }
                }
            }

            if (!!communityAmount1) {
                let bigIntCommunityAmount1 = SQUtils.AmountsArithmetic.fromString(communityAmount1)
                sentCommunityAmount1 = SQUtils.AmountsArithmetic.toNumber(bigIntCommunityAmount1, communityAssetDecimals1)
            }

            if (!!communityAmount2) {
                let bigIntCommunityAmount2 = SQUtils.AmountsArithmetic.fromString(communityAmount2)
                sentCommunityAmount2 = SQUtils.AmountsArithmetic.toNumber(bigIntCommunityAmount2, communityAssetDecimals2)
            }

            switch(status) {
            case Constants.txStatus.sending: {
                toastTitle = qsTr("Sending %1 from %2 to %3")
                toastLoading = true

                switch(txType) {
                case Constants.SendType.Transfer: {
                    toastTitle = toastTitle.arg(sentAmount).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.ENSRegister: {
                    toastTitle = qsTr("Registering %1 ENS name using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.ENSRelease: {
                    toastTitle = qsTr("Releasing %1 ENS username using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.ENSSetPubKey: {
                    toastTitle = qsTr("Setting public key %1 using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.StickersBuy: {
                    toastTitle = qsTr("Purchasing %1 sticker pack using %2").arg(stickersPackName).arg(sender)
                    break
                }
                case Constants.SendType.ERC721Transfer: {
                    toastTitle = toastTitle.arg(assetName).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.ERC1155Transfer: {
                    toastTitle = qsTr("Sending %1 %2 from %3 to %4").arg(fromAmount).arg(assetName).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.Swap: {
                    toastTitle = qsTr("Swapping %1 to %2 in %3").arg(sentAmount).arg(receivedAmount).arg(sender)
                    if (approvalTx) {
                        toastTitle = qsTr("Setting spending cap: %1 in %2 for %3").arg(sentAmount).arg(sender).arg(txRecipient)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployAssets: {
                    if (communityAmountInfinite1) {
                        toastTitle = qsTr("Minting infinite %1 tokens for %2 using %3").arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    } else {
                        toastTitle = qsTr("Minting %1 %2 tokens for %3 using %4").arg(sentCommunityAmount1).arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployCollectibles: {
                    if (communityAmountInfinite1) {
                        toastTitle = qsTr("Minting infinite %1 tokens for %2 using %3").arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    } else {
                        toastTitle = qsTr("Minting %1 %2 tokens for %3 using %4").arg(sentCommunityAmount1).arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployOwnerToken: {
                    toastTitle = qsTr("Minting %1 and %2 tokens for %3 using %4").arg(communityOwnerTokenName).arg(communityMasterTokenName).arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.CommunityMintTokens: {
                    if (!sentCommunityAmount2) {
                        if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                            toastTitle = qsTr("Airdropping %1x %2 to %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityInvolvedAddress).arg(sender)
                        } else {
                            toastTitle = qsTr("Airdropping %1x %2 to %3 addresses using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                        }
                    } else if(communityInvolvedTokens === 2) {
                        if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                            toastTitle = qsTr("Airdropping %1x %2 and %3x %4 to %5 using %6").arg(sentCommunityAmount1).arg(communityAssetName1).arg(sentCommunityAmount2).arg(communityAssetName2).arg(communityInvolvedAddress).arg(sender)
                        } else {
                            toastTitle = qsTr("Airdropping %1x %2 and %3x %4 to %5 addresses using %6").arg(sentCommunityAmount1).arg(communityAssetName1).arg(sentCommunityAmount2).arg(communityAssetName2).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                        }
                    } else {
                        toastTitle = qsTr("Airdropping %1 tokens to %2 using %3").arg(communityInvolvedTokens).arg(communityInvolvedAddress).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityRemoteBurn: {
                    if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                        toastTitle = qsTr("Destroying %1x %2 at %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityInvolvedAddress).arg(sender)
                    } else {
                        toastTitle = qsTr("Destroying %1x %2 at %3 addresses using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityBurn: {
                    toastTitle = qsTr("Burning %1x %2 for %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.CommunitySetSignerPubKey: {
                    toastTitle = qsTr("Finalizing ownership for %1 using %2").arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.Approve: {
                    console.warn("tx type approve not yet identified as a stand alone path")
                    break
                }
                default:
                    console.warn("status: sending - tx type not supproted")
                    return
                }
                break
            }
            case Constants.txStatus.pending: {
                // So far we don't display notification when it's accepted by the network and its status is pending
                // discussed in wallet group chat, we considered that pending status will be displayed almost at the
                // same time as sending and decided to skip it.
                return
            }
            case Constants.txStatus.success: {
                toastTitle = qsTr("Sent %1 from %2 to %3")
                toastIcon = "checkmark-circle"
                toastType = Constants.ephemeralNotificationType.success

                switch(txType) {
                case Constants.SendType.Transfer: {
                    toastTitle = toastTitle.arg(sentAmount).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.ENSRegister: {
                    toastTitle = qsTr("Registered %1 ENS name using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.ENSRelease: {
                    toastTitle = qsTr("Released %1 ENS username using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.ENSSetPubKey: {
                    toastTitle = qsTr("Set public key %1 using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.StickersBuy: {
                    toastTitle = qsTr("Purchased %1 sticker pack using %2").arg(stickersPackName).arg(sender)
                    break
                }
                case Constants.SendType.ERC721Transfer: {
                    toastTitle = toastTitle.arg(assetName).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.ERC1155Transfer: {
                    toastTitle = qsTr("Sent %1 %2 from %3 to %4").arg(fromAmount).arg(assetName).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.Swap: {
                    toastTitle = qsTr("Swapped %1 to %2 in %3").arg(sentAmount).arg(receivedAmount).arg(sender)
                    if (approvalTx) {
                        toastTitle = qsTr("Spending cap set: %1 in %2 for %3").arg(sentAmount).arg(sender).arg(txRecipient)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployAssets: {
                    if (communityAmountInfinite1){
                        toastTitle = qsTr("Minted infinite %1 tokens for %2 using %3").arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    } else {
                        toastTitle = qsTr("Minted %1 %2 tokens for %3 using %4").arg(sentCommunityAmount1).arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployCollectibles: {
                    if (communityAmountInfinite1){
                        toastTitle = qsTr("Minted infinite %1 tokens for %2 using %3").arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    } else {
                        toastTitle = qsTr("Minted %1 %2 tokens for %3 using %4").arg(sentCommunityAmount1).arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployOwnerToken: {
                    toastTitle = qsTr("Minted %1 and %2 tokens for %3 using %4").arg(communityOwnerTokenName).arg(communityMasterTokenName).arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.CommunityMintTokens: {
                    if (!sentCommunityAmount2) {
                        if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                            toastTitle = qsTr("Airdropped %1x %2 to %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityInvolvedAddress).arg(sender)
                        } else {
                            toastTitle = qsTr("Airdropped %1x %2 to %3 addresses using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                        }
                    } else if(communityInvolvedTokens === 2) {
                        if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                            toastTitle = qsTr("Airdropped %1x %2 and %3x %4 to %5 using %6").arg(sentCommunityAmount1).arg(communityAssetName1).arg(sentCommunityAmount2).arg(communityAssetName2).arg(communityInvolvedAddress).arg(sender)
                        } else {
                            toastTitle = qsTr("Airdropped %1x %2 and %3x %4 to %5 addresses using %6").arg(sentCommunityAmount1).arg(communityAssetName1).arg(sentCommunityAmount2).arg(communityAssetName2).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                        }
                    } else {
                        toastTitle = qsTr("Airdropped %1 tokens to %2 using %3").arg(communityInvolvedTokens).arg(communityInvolvedAddress).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityRemoteBurn: {
                    if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                        toastTitle = qsTr("Destroyed %1x %2 at %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityInvolvedAddress).arg(sender)
                    } else {
                        toastTitle = qsTr("Destroyed %1x %2 at %3 addresses using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityBurn: {
                    toastTitle = qsTr("Burned %1x %2 for %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.CommunitySetSignerPubKey: {
                    toastTitle = qsTr("Finalized ownership for %1 using %2").arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.Approve: {
                    console.warn("tx type approve not yet identified as a stand alone path")
                    break
                }
                default:
                    console.warn("status: success - tx type not supproted")
                    return
                }
                break
            }
            case Constants.txStatus.failed: {
                toastTitle = qsTr("Send failed: %1 from %2 to %3")
                toastIcon = "warning"
                toastType = Constants.ephemeralNotificationType.danger

                if (!toastSubtitle && !!error) {
                    toastSubtitle = error
                }

                switch(txType) {
                case Constants.SendType.Transfer: {
                    toastTitle = toastTitle.arg(sentAmount).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.ENSRegister: {
                    toastTitle = qsTr("ENS username registeration failed: %1 using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.ENSRelease: {
                    toastTitle = qsTr("ENS username release failed: %1 using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.ENSSetPubKey: {
                    toastTitle = qsTr("Set public key failed: %1 using %2").arg(ensName).arg(sender)
                    break
                }
                case Constants.SendType.StickersBuy: {
                    toastTitle = qsTr("Sticker pack purchase failed: %1 using %2").arg(stickersPackName).arg(sender)
                    break
                }
                case Constants.SendType.ERC721Transfer: {
                    toastTitle = toastTitle.arg(assetName).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.ERC1155Transfer: {
                    toastTitle = qsTr("Send failed: %1 %2 from %3 to %4").arg(fromAmount).arg(assetName).arg(sender).arg(recipient)
                    break
                }
                case Constants.SendType.Swap: {
                    toastTitle = qsTr("Swap failed: %1 to %2 in %3").arg(sentAmount).arg(receivedAmount).arg(sender)
                    if (approvalTx) {
                        toastTitle = qsTr("Spending cap failed: %1 in %2 for %3").arg(sentAmount).arg(sender).arg(txRecipient)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployAssets: {
                    if (communityAmountInfinite1){
                        toastTitle = qsTr("Mint failed: infinite %1 tokens for %2 using %3").arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    } else {
                        toastTitle = qsTr("Mint failed: %1 %2 tokens for %3 using %4").arg(sentCommunityAmount1).arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployCollectibles: {
                    if (communityAmountInfinite1){
                        toastTitle = qsTr("Mint failed: infinite %1 tokens for %2 using %3").arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    } else {
                        toastTitle = qsTr("Mint failed: %1 %2 tokens for %3 using %4").arg(sentCommunityAmount1).arg(communityDeployedTokenName).arg(communityName).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityDeployOwnerToken: {
                    toastTitle = qsTr("Mint failed: %1 and %2 tokens for %3 using %4").arg(communityOwnerTokenName).arg(communityMasterTokenName).arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.CommunityMintTokens: {
                    if (!sentCommunityAmount2) {
                        if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                            toastTitle = qsTr("Airdrop failed: %1x %2 to %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityInvolvedAddress).arg(sender)
                        } else {
                            toastTitle = qsTr("Airdrop failed: %1x %2 to %3 addresses using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                        }
                    } else if(communityInvolvedTokens === 2) {
                        if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                            toastTitle = qsTr("Airdrop failed: %1x %2 and %3x %4 to %5 using %6").arg(sentCommunityAmount1).arg(communityAssetName1).arg(sentCommunityAmount2).arg(communityAssetName2).arg(communityInvolvedAddress).arg(sender)
                        } else {
                            toastTitle = qsTr("Airdrop failed: %1x %2 and %3x %4 to %5 addresses using %6").arg(sentCommunityAmount1).arg(communityAssetName1).arg(sentCommunityAmount2).arg(communityAssetName2).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                        }
                    } else {
                        toastTitle = qsTr("Airdrop failed: %1 tokens to %2 using %3").arg(communityInvolvedTokens).arg(communityInvolvedAddress).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityRemoteBurn: {
                    if (communityNubmerOfInvolvedAddresses === 1 && !!communityInvolvedAddress) {
                        toastTitle = qsTr("Destruction failed: %1x %2 at %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityInvolvedAddress).arg(sender)
                    } else {
                        toastTitle = qsTr("Destruction failed: %1x %2 at %3 addresses using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityNubmerOfInvolvedAddresses).arg(sender)
                    }
                    break
                }
                case Constants.SendType.CommunityBurn: {
                    toastTitle = qsTr("Burn failed: %1x %2 for %3 using %4").arg(sentCommunityAmount1).arg(communityAssetName1).arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.CommunitySetSignerPubKey: {
                    toastTitle = qsTr("Finalize ownership failed: %1 using %2").arg(communityName).arg(sender)
                    break
                }
                case Constants.SendType.Approve: {
                    console.warn("tx type approve not yet identified as a stand alone path")
                    break
                }
                default:
                    const err1 = "cannot_resolve_community" // move to Constants
                    if (error === err1) {
                        Global.displayToastMessage(qsTr("Unknown error resolving community"), "", "", false, Constants.ephemeralNotificationType.normal, "")
                        return
                    }
                    console.warn("status: failed - tx type not supproted")
                    return
                }
                break
            }
            default:
                if (!error) {
                    console.warn("not supported status")
                    return
                } else {
                    const err1 = "cannot_resolve_community" // move to Constants
                    if (error === err1) {
                        Global.displayToastMessage(qsTr("Unknown error resolving community"), "", "", false, Constants.ephemeralNotificationType.normal, "")
                        return
                    }
                }
            }

            Global.displayToastMessage(toastTitle, toastSubtitle, toastIcon, toastLoading, toastType, toastLink)
        }

        function onCommunityMemberStatusEphemeralNotification(communityName: string, memberName: string, state: int) {
            var text = ""
            switch (state) {
                case Constants.CommunityMembershipRequestState.Banned:
                case Constants.CommunityMembershipRequestState.BannedWithAllMessagesDelete:
                    text = qsTr("%1 was banned from %2").arg(memberName).arg(communityName)
                    break
                case Constants.CommunityMembershipRequestState.Unbanned:
                    text = qsTr("%1 unbanned from %2").arg(memberName).arg(communityName)
                    break
                case Constants.CommunityMembershipRequestState.Kicked:
                    text = qsTr("%1 was kicked from %2").arg(memberName).arg(communityName)
                    break
                default: return
            }

            Global.displayToastMessage(
                text,
                "",
                "checkmark-circle",
                false,
                Constants.ephemeralNotificationType.success,
                ""
            )
        }

        function onShowToastPairingFallbackCompleted() {
            Global.displayToastMessage(
                qsTr("Device paired"),
                qsTr("Sync in process. Keep device powered and app open."),
                "checkmark-circle",
                false,
                Constants.ephemeralNotificationType.success,
                ""
            )
        }
    }

    QtObject {
        id: d

        // strict online/offline checker, doesn't care about the wallet services
        readonly property var networkChecker: NetworkChecker {
            active: {
                if (!appMain.rootStore.thirdpartyServicesEnabled) // the connectivity checks might leak our IP
                    return false
                return true
            }

            Component.onCompleted: d.connectionChange()
            onIsOnlineChanged: d.connectionChange()
            onConnectionTypeChanged: d.connectionChange()
        }

        readonly property int activeSectionType: appMain.rootStore.activeSectionType
        readonly property bool isWalletRelatedSectionType: activeSectionType === Constants.appSection.wallet ||
                                                           activeSectionType === Constants.appSection.swap || activeSectionType === Constants.appSection.market ||
                                                           activeSectionType === Constants.appSection.dApp
        readonly property bool isBrowserEnabled: appMain.featureFlagsStore.browserEnabled &&
                                                 localAccountSensitiveSettings.isBrowserEnabled
        readonly property int syncingBadgeCount: appMain.devicesStore.totalDevicesCount - appMain.devicesStore.pairedDevicesCount

        function openHomePage() {
            appMain.rootStore.setActiveSectionBySectionType(Constants.appSection.homePage)
            homePageLoader.item.focusSearch()
        }

        function maybeDisplayIntroduceYourselfPopup() {
            if (!appMainLocalSettings.introduceYourselfPopupSeen && allContacsAdaptor.selfDisplayName === "") {
                introduceYourselfPopupComponent.createObject(appMain).open()
                return true
            }
            return false
        }

        function ensName(username) {
            if (!username.endsWith(".stateofus.eth") && !username.endsWith(".eth")) {
                return "%1.%2".arg(username).arg("stateofus.eth")
            }
            return username
        }

        function pairWalletConnectUri(uri: string) {
            if (!dAppsServiceLoader.active || !dAppsServiceLoader.item || !uri) {
                return
            }
            function pairingHandler() {
                dAppsServiceLoader.item.dappsModule.pair(uri)
                dAppsServiceLoader.item.pairingValidated.disconnect(pairingHandler)
            }
            dAppsServiceLoader.item.pairingValidated.connect(pairingHandler)
            dAppsServiceLoader.item.validatePairingUri(uri)
        }

        function connectionChange() {
            appMain.rootStore.connectionChange(d.networkChecker.connectionType, d.networkChecker.isExpensive)
        }

        function openLinkInBrowser(link: string) {
            if (!appMain.rootStore.openLinksInStatus ||
                    !d.isBrowserEnabled ||
                    !appMain.rootStore.thirdpartyServicesEnabled) {
                Qt.openUrlExternally(link)
                return
            }
            globalConns.onAppSectionBySectionTypeChanged(Constants.appSection.browser)
            Qt.callLater(() => browserLayoutContainer.item.openUrlInNewTab(link))
        }

        function tryOpenNavigationEducationPopup() {
            if(!appMainGlobalSettings.newMenuEducationPopupSeen && !sidebar.alwaysVisible) {
                Global.openNavigationEducationPopupRequested()
            }
        }
    }

    Settings {
        id: appMainGlobalSettings
        property bool newMenuEducationPopupSeen
    }

    Settings {
        id: appMainLocalSettings
        category: "AppMainLocalSettings_%1".arg(allContacsAdaptor.selfContactDetails.publicKey)
        property var whitelistedUnfurledDomains: []
        property bool introduceYourselfPopupSeen
        property bool enableMessageBackupPopupSeen
        property bool enablePushNotificationsFreshInstallSeen
        property bool enablePushNotificationsDontAskAgain
        property string enablePushNotificationsLastShownVersion
        property var recentEmojis: []
        property string skinColor // NB: must be a string for the twemoji lib to work; we don't want the `#` in the name
        property int theme: ThemeUtils.Style.System
        property int fontSize: {
            if (appMain.isPortraitMode) {
                return ThemeUtils.FontSize.FontSizeS
            }
            return ThemeUtils.FontSize.FontSizeM
        }
        property int paddingFactor: {
            if (appMain.isPortraitMode) {
                return ThemeUtils.PaddingFactor.PaddingXXS
            }
            return ThemeUtils.PaddingFactor.PaddingM
        }

        Component.onCompleted: {
            ThemeUtils.setTheme(appMain.Window.window, appMainLocalSettings.theme)
            ThemeUtils.setFontSize(appMain.Window.window, appMainLocalSettings.fontSize)
            ThemeUtils.setPaddingFactor(appMain.Window.window, appMainLocalSettings.paddingFactor)

            // Show the navigation education dialog the first time the app
            // is opened after the new menu is introduce, if the nav bar is in collapsed mode
            d.tryOpenNavigationEducationPopup()
        }

        readonly property var _conn: Connections {
            target: appMain
            function onIsPortraitModeChanged() {
                ThemeUtils.setFontSize(appMain.Window.window, appMainLocalSettings.fontSize)
                ThemeUtils.setPaddingFactor(appMain.Window.window, appMainLocalSettings.paddingFactor)
            }
        }
    }

    PopupsLoader {
        id: popups

        keychain: appMain.keychain
        sharedRootStore: appMain.sharedRootStore
        popupParent: appMain
        rootStore: appMain.rootStore
        chatStore: appMain.rootChatStore
        utilsStore: appMain.utilsStore
        communityTokensStore: appMain.communityTokensStore
        communitiesStore: appMain.communitiesStore
        profileStore: appMain.profileStore
        devicesStore: appMain.devicesStore
        currencyStore: appMain.currencyStore
        walletAssetsStore: appMain.walletAssetsStore
        walletCollectiblesStore: appMain.walletCollectiblesStore
        buyCryptoStore: appMain.buyCryptoStore
        networkConnectionStore: appMain.networkConnectionStore
        networksStore: appMain.networksStore
        activityCenterStore: appMain.activityCenterStore
        advancedStore: appMain.advancedStore
        aboutStore: appMain.aboutStore
        contactsStore: appMain.contactsStore
        privacyStore: appMain.privacyStore
        messagingRootStore: appMain.messagingRootStore

        allContactsModel: allContacsAdaptor.allContactsModel
        mutualContactsModel: contactsModelAdaptor.mutualContacts

        isDevBuild: !appMain.rootStore.isProduction
        emojiPopup: statusEmojiPopup.item

        onOpenExternalLink: (link) => d.openLinkInBrowser(link)
        onSaveDomainToUnfurledWhitelist: function(domain) {
            const whitelistedHostnames = appMainLocalSettings.whitelistedUnfurledDomains || []
            if (!whitelistedHostnames.includes(domain)) {
                whitelistedHostnames.push(domain)
                appMainLocalSettings.whitelistedUnfurledDomains = whitelistedHostnames
                Global.displaySuccessToastMessage(qsTr("%1 added to your trusted sites.").arg(domain))
            }
        }
        onTransferOwnershipRequested: (tokenId, senderAddress) => popupRequestsHandler.transferOwnership(tokenId, senderAddress)
        onWcUriScanned: uri => d.pairWalletConnectUri(uri)
        onNavigationEducationDialogSeenRequested: appMainGlobalSettings.newMenuEducationPopupSeen = true
    }

    HandlersManagerLoader {
        id: popupRequestsHandler

        popupParent: appMain

        // Stores:
        rootStore: appMain.rootStore
        contactsStore: appMain.contactsStore
        featureFlagsStore: appMain.featureFlagsStore
        sharedRootStore: appMain.sharedRootStore
        currencyStore: appMain.currencyStore
        networksStore: appMain.networksStore
        networkConnectionStore: appMain.networkConnectionStore
        walletRootStore: WalletStores.RootStore
        walletAssetsStore: appMain.walletAssetsStore
        transactionStore: appMain.transactionStore
        walletCollectiblesStore: appMain.walletCollectiblesStore
        transactionStoreNew: appMain.transactionStoreNew
        tokensStore: appMain.tokensStore
        rootChatStore: appMain.rootChatStore
        ensUsernamesStore: appMain.ensUsernamesStore
        aboutStore: appMain.aboutStore
        privacyStore: appMain.privacyStore
        keychain: appMain.keychain
        notificationsStore: appMain.notificationsStore

        Component.onCompleted: {
            Qt.callLater(() => popupRequestsHandler.maybeDisplayEnablePushNotificationsPopup())
        }
    }

    Connections {
        id: globalConns
        target: Global

        function onOpenCreateChatView() {
            createChatView.opened = true
        }

        function onCloseCreateChatView() {
            createChatView.opened = false
        }

        function onRequestOpenLink(link: string) {
            // Qt sometimes inserts random HTML tags; and this will break on invalid URL inside QDesktopServices::openUrl(link)
            link = SQUtils.StringUtils.plainText(link)
            const domain = SQUtils.StringUtils.extractDomainFromLink(link)

            if (appMainLocalSettings.whitelistedUnfurledDomains.includes(domain) ||
                    link.startsWith("mailto:")) {
                d.openLinkInBrowser(link)
            } else {
                popups.openConfirmExternalLinkPopup(link, domain)
            }
        }

        function onActivateDeepLink(link: string) {
            appMain.rootStore.activateStatusDeepLink(link)
        }

        function onPlaySendMessageSound() {
            sendMessageSound.stop()
            sendMessageSound.play()
        }

        function onPlayNotificationSound() {
            notificationSound.stop()
            notificationSound.play()
        }

        function onPlayErrorSound() {
            errorSound.stop()
            errorSound.play()
        }

        function onSetNthEnabledSectionActive(nthSection: int) {
            appMain.rootStore.setNthEnabledSectionActive(nthSection)
        }

        function onAppSectionBySectionTypeChanged(sectionType, subsection, subSubsection = -1, data = {}) {
            if (sectionType !== Constants.appSection.community) {
                appMain.rootStore.setActiveSectionBySectionType(sectionType)
            }

            if (sectionType === Constants.appSection.profile) {
                profileLoader.settingsSubsection = subsection || Constants.settingsSubsection.profile
                profileLoader.settingsSubSubsection = subSubsection
                profileLoader.forceSubsectionNavigation()
            } else if (sectionType === Constants.appSection.wallet) {
                appView.children[Constants.appViewStackIndex.wallet].item.openDesiredView(subsection, subSubsection, data)
            } else if (sectionType === Constants.appSection.swap) {
                popupRequestsHandler.launchSwap()
            } else if (sectionType === Constants.appSection.chat) {
                appMain.rootStore.setNavToMsgDetailsFlag(true)
                appMain.rootStore.setActiveSectionChat(appMain.profileStore.pubKey, subsection)
            } else if (sectionType === Constants.appSection.community && subsection !== "") {
                appMain.communitiesStore.setActiveCommunity(subsection)
            }
        }

        function onSwitchToCommunity(communityId: string) {
            appMain.communitiesStore.setActiveCommunity(communityId)
        }

        function onOpenAddEditSavedAddressesPopup(params) {
            addEditSavedAddress.open(params)
        }

        function onOpenDeleteSavedAddressesPopup(params) {
            deleteSavedAddress.open(params)
        }

        function onOpenShowQRPopup(params) {
            showQR.open(params)
        }

        function onOpenSavedAddressActivityPopup(params) {
            savedAddressActivity.open(params)
        }

        function onCloseActivityCenterRequested() {
            if (mainLayoutItem.isPortraitMode)
                mainLayoutItem.openACCenterPanel = false
        }
    }

    Connections {
        target: appMain.communitiesStore

        function onImportingCommunityStateChanged(communityId, state, errorMsg) {
            let title = ""
            let subTitle = ""
            let loading = false
            let notificationType = Constants.ephemeralNotificationType.normal
            let icon = ""

            switch (state)
            {
            case Constants.communityImported:
                const community = appMain.communitiesStore.getCommunityDetailsAsJson(communityId)
                if(community.isControlNode) {
                    title = qsTr("This device is now the control node for the %1 Community").arg(community.name)
                    notificationType = Constants.ephemeralNotificationType.success
                    icon = "checkmark-circle"
                } else {
                    title = qsTr("'%1' community imported").arg(community.name)
                }
                break
            case Constants.communityImportingInProgress:
                title = qsTr("Importing community is in progress")
                loading = true
                break
            case Constants.communityImportingError:
                title = qsTr("Failed to import community '%1'").arg(communityId)
                subTitle = errorMsg
                break
            case Constants.communityImportingCanceled:
                title = qsTr("Import community '%1' was canceled").arg(community.name)
                break;
            default:
                console.error("unknown state while importing community: %1").arg(state)
                return
            }

            Global.displayToastMessage(title,
                                       subTitle,
                                       icon,
                                       loading,
                                       notificationType,
                                       "")
        }
    }

    Connections {
        target: appMain.Window.window

        function onActiveChanged() {
            if (appMain.Window.window.active)
                appMain.rootStore.windowActivated()
            else
                appMain.rootStore.windowDeactivated()
        }
    }

    /**
        * iOS Push Notifications flow:
        * - When the app is opened, if the user has already granted permissions, we get the token immediately and set it in the store
        * - If the user hasn't granted permissions yet, we wait for them to change (onStatusChanged). If they grant permissions, we request the token and set it in the store
        * Additionally, when the user enables notifications from our in-app settings, we request the OS permission at that moment
        * (showing the native dialog when it hasn't been decided yet), and request the token in case we don't have it yet
    */
    Connections {
        target: PushNotifications
        enabled: SQUtils.Utils.isIOS

        function onTokenChanged() {
            appMain.notificationsStore.notificationsSettings.deviceToken = PushNotifications.token
        }

        function onStatusChanged() {
            if (PushNotifications.status === PushNotifications.Granted && PushNotifications.token === "") {
                PushNotifications.requestToken()
            }
        }

        // in case PushNotifications has already processed the token
        Component.onCompleted: {
            if (SQUtils.Utils.isIOS && !!PushNotifications.token && !!appMain.notificationsStore.notificationsSettings)
                appMain.notificationsStore.notificationsSettings.deviceToken = PushNotifications.token
        }
    }

    Connections {
        target: appMain.notificationsStore.notificationsSettings
        enabled: SQUtils.Utils.isIOS

        function onRemotePushNotificationsEnabledChanged() {
            if (!appMain.notificationsStore.notificationsSettings.remotePushNotificationsEnabled)
                return
            if (PushNotifications.status !== PushNotifications.Granted)
                PushNotifications.request()
            else if (appMain.notificationsStore.notificationsSettings.deviceToken === "")
                PushNotifications.requestToken()
        }
    }

    Connections {
        target: appMain.notificationsStore
        enabled: SQUtils.Utils.isIOS
        function onNotificationsSettingsChanged() {
            if (!!appMain.notificationsStore.notificationsSettings)
                appMain.notificationsStore.notificationsSettings.deviceToken = PushNotifications.token
        }
    }

    function changeAppSectionBySectionId(sectionId) {
        // Using callLater doesn't leave ebnough time to render the loading state
        Backpressure.setTimeout(this, 1, () => {
            appMain.rootStore.setActiveSectionById(sectionId)
        })
    }

    StatusSoundEffect {
        id: sendMessageSound

        volume: convertVolume(rootStore.volume)
        muted: !rootStore.notificationSoundsEnabled
        source: "qrc:/imports/assets/audio/send_message.wav"

        onIsErrorChanged: {
            if(isError) {
                console.warn("Sound error:",
                             statusString)
            }
        }
    }

    StatusSoundEffect {
        id: notificationSound

        volume: convertVolume(rootStore.volume)
        muted: !rootStore.notificationSoundsEnabled
        source: "qrc:/imports/assets/audio/notification.wav"

        onIsErrorChanged: {
            if(isError) {
                console.warn("Sound error:",
                             statusString)
            }
        }
    }

    StatusSoundEffect {
        id: errorSound

        volume: convertVolume(rootStore.volume)
        muted: !rootStore.notificationSoundsEnabled
        source: "qrc:/imports/assets/audio/error.mp3"

        onIsErrorChanged: {
            if(isError) {
                console.warn("Sound error:",
                             statusString)
            }
        }
    }

    Loader {
        id: appSearch
        active: false

        function openSearchPopup() {
            if (homePageLoader.active)
                return
            if (!active)
                active = true
            item.openSearchPopup()
        }

        function closeSearchPopup() {
            if (item)
                item.closeSearchPopup()

            active = false
        }

        sourceComponent: AppSearch {
            store: appMain.rootStore.appSearchStore
            utilsStore: appMain.utilsStore
            onClosed: appSearch.active = false
        }
    }

    Loader {
        id: statusEmojiPopup
        active: appMain.rootStore.sectionsLoaded
        sourceComponent: StatusEmojiPopup {
            directParent: appMain.Window.window.contentItem
            height: 440
            recentEmojis: appMainLocalSettings.recentEmojis
            skinColor: appMainLocalSettings.skinColor
            emojiModel: SQUtils.Emoji.emojiModel
            onSetSkinColorRequested: color => appMainLocalSettings.skinColor = color
            onSetRecentEmojisRequested: recentEmojis => appMainLocalSettings.recentEmojis = recentEmojis
        }
    }

    Loader {
        id: statusStickersPopupLoader
        active: appMain.rootStore.sectionsLoaded
        sourceComponent: StatusStickersPopup {
            directParent: appMain.Window.contentItem
            height: 440
            store: appMain.rootChatStore
            isWalletEnabled: appMain.walletProfileStore.isWalletEnabled
            thirdpartyServicesEnabled: appMain.rootStore.thirdpartyServicesEnabled

            onBuyClicked: (packId, price) => popupRequestsHandler.buyStickerPack(packId, price)
            onEnableThirdpartyServicesRequested: popupRequestsHandler.openThirdpartyServicesPopup()
        }
    }

    ColumnLayout {
        anchors.fill: parent

        spacing: 0

        ColumnLayout {
            id: bannersLayout

            enabled: !localAppSettings.testEnvironment
                     && (d.activeSectionType !== Constants.appSection.homePage && d.activeSectionType !== Constants.appSection.loadingSection)
            visible: enabled

            Layout.fillWidth: true

            // apply left/right margins when we remove the window titlebar
            Layout.leftMargin: Qt.platform.os === SQUtils.Utils.mac ? appMain.SafeArea.margins.left : 0
            Layout.rightMargin: Qt.platform.os === SQUtils.Utils.mac ? appMain.SafeArea.margins.right : 0

            spacing: 0

            GlobalBanner {
                Layout.fillWidth: true

                isOnline: d.networkChecker.isOnline
                testnetEnabled: appMain.networksStore.areTestNetworksEnabled
                seedphraseBackedUp: appMain.privacyStore.mnemonicBackedUp || appMain.profileStore.userDeclinedBackupBanner

                onOpenTestnetPopupRequested: Global.openTestnetPopup()
                onOpenBackUpSeedPopupRequested: popups.openBackUpSeedPopup()
                onUserDeclinedBackupBannerRequested: appMain.profileStore.setUserDeclinedBackupBanner()
            }

            ModuleWarning {
                Layout.fillWidth: true
                readonly property int progress: appMain.communitiesStore.discordImportProgress
                readonly property bool inProgress: (progress > 0 && progress < 100) || appMain.communitiesStore.discordImportInProgress
                readonly property bool finished: progress >= 100
                readonly property bool cancelled: appMain.communitiesStore.discordImportCancelled
                readonly property bool stopped: appMain.communitiesStore.discordImportProgressStopped
                readonly property int errors: appMain.communitiesStore.discordImportErrorsCount
                readonly property int warnings: appMain.communitiesStore.discordImportWarningsCount
                readonly property string communityId: appMain.communitiesStore.discordImportCommunityId
                readonly property string communityName: appMain.communitiesStore.discordImportCommunityName
                readonly property string channelId: appMain.communitiesStore.discordImportChannelId
                readonly property string channelName: appMain.communitiesStore.discordImportChannelName
                readonly property string channelOrCommunityName: channelName || communityName
                delay: false
                active: !cancelled && (inProgress || finished || stopped)
                type: errors ? ModuleWarning.Type.Danger : ModuleWarning.Type.Success
                text: {
                    if (finished || stopped) {
                        if (errors)
                            return qsTr("The import of ‘%1’ from Discord to Status was stopped: <a href='#'>Critical issues found</a>").arg(channelOrCommunityName)

                        let result = qsTr("‘%1’ was successfully imported from Discord to Status").arg(channelOrCommunityName) + "  <a href='#'>"
                        if (warnings)
                            result += qsTr("Details (%1)").arg(qsTr("%n issue(s)", "", warnings))
                        else
                            result += qsTr("Details")
                        result += "</a>"
                        return result
                    }
                    if (inProgress) {
                        let result = qsTr("Importing ‘%1’ from Discord to Status").arg(channelOrCommunityName) + "  <a href='#'>"
                        if (warnings)
                            result += qsTr("Check progress (%1)").arg(qsTr("%n issue(s)", "", warnings))
                        else
                            result += qsTr("Check progress")
                        result += "</a>"
                        return result
                    }

                    return ""
                }
                onLinkActivated: popups.openDiscordImportProgressPopup(!!channelId)
                progressValue: progress
                closeBtnVisible: finished || stopped
                buttonText: finished && !errors ? !!channelId ? qsTr("Visit your new channel") : qsTr("Visit your Community") : ""
                onClicked: function() {
                    if (!!channelId)
                        rootStore.setActiveSectionChat(communityId, channelId)
                    else
                        appMain.communitiesStore.setActiveCommunity(communityId)
                }
                onCloseClicked: hide()
            }

            ModuleWarning {
                id: mailserverConnectionBanner
                type: ModuleWarning.Warning
                text: qsTr("Can not connect to store node. Retrying automatically")
                onCloseClicked: hide()
                Layout.fillWidth: true
            }

            ConnectionWarnings {
                objectName: "walletBlockchainConnectionBanner"
                Layout.fillWidth: true
                relevantForCurrentSection: d.isWalletRelatedSectionType || d.activeSectionType === Constants.appSection.browser
                websiteDown: Constants.walletConnections.blockchains
                withCache: networkConnectionStore.balanceCache
                networkConnectionStore: appMain.networkConnectionStore
                tooltipMessage: qsTr("Pocket Network (POKT) & Infura are currently both unavailable for %1. Balances for those chains are as of %2.").arg(jointChainIdString).arg(lastCheckedAt)
                toastText: {
                    switch(connectionState) {
                    case Constants.ConnectionStatus.Success:
                        return qsTr("Pocket Network (POKT) connection successful")
                    case Constants.ConnectionStatus.Failure:
                        if(completelyDown) {
                            if(withCache)
                                return qsTr("POKT & Infura down. Token balances are as of %1.").arg(lastCheckedAt)
                            return qsTr("POKT & Infura down. Token balances cannot be retrieved.")
                        }
                        else if(chainIdsDown.length > 0) {
                            if(chainIdsDown.length > 2)
                                return qsTr("POKT & Infura down for <a href='#'>multiple chains</a>. Token balances for those chains cannot be retrieved.")
                            if(chainIdsDown.length === 1 && withCache)
                                return qsTr("POKT & Infura down for %1. %1 token balances are as of %2.").arg(jointChainIdString).arg(lastCheckedAt)
                            return qsTr("POKT & Infura down for %1. %1 token balances cannot be retrieved.").arg(jointChainIdString)
                        }
                        else
                            return ""
                    case Constants.ConnectionStatus.Retrying:
                        return qsTr("Retrying connection to POKT Network (grove.city).")
                    case Constants.ConnectionStatus.Unknown:
                        return ""
                    default:
                        return ""
                    }
                }
            }

            ConnectionWarnings {
                objectName: "walletCollectiblesConnectionBanner"
                Layout.fillWidth: true
                relevantForCurrentSection: d.isWalletRelatedSectionType || d.activeSectionType === Constants.appSection.browser || d.activeSectionType === Constants.appSection.community
                websiteDown: Constants.walletConnections.collectibles
                withCache: lastCheckedAtUnix > 0
                networkConnectionStore: appMain.networkConnectionStore
                tooltipMessage: {
                    if(withCache)
                        return qsTr("Collectibles providers are currently unavailable for %1. Collectibles for those chains are as of %2.").arg(jointChainIdString).arg(lastCheckedAt)
                    return qsTr("Collectibles providers are currently unavailable for %1.").arg(jointChainIdString)
                }
                toastText: {
                    switch(connectionState) {
                    case Constants.ConnectionStatus.Success:
                        return qsTr("Collectibles providers connection successful")
                    case Constants.ConnectionStatus.Failure:
                        if(completelyDown) {
                            if(withCache)
                                return qsTr("Collectibles providers down. Collectibles are as of %1.").arg(lastCheckedAt)
                            return qsTr("Collectibles providers down. Collectibles cannot be retrieved.")
                        }
                        else if(chainIdsDown.length > 0) {
                            if(chainIdsDown.length > 2) {
                                if(withCache)
                                    return qsTr("Collectibles providers down for <a href='#'>multiple chains</a>. Collectibles for these chains are as of %1.".arg(lastCheckedAt))
                                return qsTr("Collectibles providers down for <a href='#'>multiple chains</a>. Collectibles for these chains cannot be retrieved.")
                            }
                            else if(chainIdsDown.length === 1) {
                                if(withCache)
                                    return qsTr("Collectibles providers down for %1. Collectibles for this chain are as of %2.").arg(jointChainIdString).arg(lastCheckedAt)
                                return qsTr("Collectibles providers down for %1. Collectibles for this chain cannot be retrieved.").arg(jointChainIdString)
                            }
                            else {
                                if(withCache)
                                    return qsTr("Collectibles providers down for %1. Collectibles for these chains are as of %2.").arg(jointChainIdString).arg(lastCheckedAt)
                                return qsTr("Collectibles providers down for %1. Collectibles for these chains cannot be retrieved.").arg(jointChainIdString)
                            }
                        }
                        else
                            return ""
                    case Constants.ConnectionStatus.Retrying:
                        return qsTr("Retrying connection to collectibles providers...")
                    case Constants.ConnectionStatus.Unknown:
                        return ""
                    default:
                        return ""
                    }
                }
            }

            ConnectionWarnings {
                objectName: "walletMarketConnectionBanner"
                Layout.fillWidth: true
                relevantForCurrentSection: d.isWalletRelatedSectionType || d.activeSectionType === Constants.appSection.browser
                websiteDown: Constants.walletConnections.market
                withCache: networkConnectionStore.marketValuesCache
                networkConnectionStore: appMain.networkConnectionStore
                toastText: {
                    switch(connectionState) {
                    case Constants.ConnectionStatus.Success:
                        return qsTr("CryptoCompare and CoinGecko connection successful")
                    case Constants.ConnectionStatus.Failure: {
                        if(withCache)
                            return qsTr("CryptoCompare and CoinGecko down. Market values are as of %1.").arg(lastCheckedAt)
                        return qsTr("CryptoCompare and CoinGecko down. Market values cannot be retrieved.")
                    }
                    case Constants.ConnectionStatus.Retrying:
                        return qsTr("Retrying connection to CryptoCompare and CoinGecko...")
                    case Constants.ConnectionStatus.Unknown:
                        return ""
                    default:
                        return ""
                    }
                }
            }
        }

        Item {
            id: mainLayoutItem

            readonly property bool isPortraitMode: appMain.isPortraitMode

            Layout.fillWidth: true
            Layout.fillHeight: true

            objectName: "mainRightView"

            property bool openACCenterPanel: false

            // By design, width of the left panel when expanded while the floating panel is open.
            readonly property int extendedLeftPanelWidth: 344

            readonly property int leftPanelWidthOverride: openACCenterPanel ? extendedLeftPanelWidth : 0

            // Management of open/close AC popup in case of portrait mode
            onOpenACCenterPanelChanged: {
                if(isPortraitMode && openACCenterPanel) {
                    acPortraitPopup.open()
                } else if (isPortraitMode && !openACCenterPanel) {
                    acPortraitPopup.close()
                }
            }

            // Ensure closing the popup when changing from portrait to landscape,
            // and reset panel state when changing from landscape to portrait
            onIsPortraitModeChanged: {
                if(!isPortraitMode) {
                    acPortraitPopup.close()
                } else {
                    openACCenterPanel = false
                }
            }

            // Container for the Activity Center Area in Landscape
            Rectangle {
                readonly property bool openPanel: !mainLayoutItem.isPortraitMode ? mainLayoutItem.openACCenterPanel : false

                // Keep alive while closing animation
                property bool _shown: openPanel

                // Turns true only after the open animation completes
                property bool _fullyOpen: false

                // Layout
                z: sectionLayout.z + 1
                color: _fullyOpen ? Theme.palette.baseColor4 : Theme.palette.transparent
                height: parent.height
                width: parent.extendedLeftPanelWidth
                clip: true
                visible: _shown
                anchors.left: sectionLayout.left

                // For animating it on open and close
                y: openPanel ? 0 : height

                // Open / Close animation
                Behavior on y {
                    NumberAnimation {
                        duration: ThemeUtils.AnimationDuration.VerySlow
                        easing.type: Easing.OutCubic
                    }
                }
                // When close finished, finally hide, no more inputs to capture.
                // Also drives _fullyOpen to ensure when the panel is fully open.
                onYChanged: {
                    if (openPanel && y === 0)
                        _fullyOpen = true
                    if (!openPanel && y >= height)
                        _shown = false
                }
                // Drives animation
                onOpenPanelChanged: {
                    if (openPanel) _shown = true
                    _fullyOpen = false
                }

                LayoutItemProxy {
                    anchors.fill: parent
                    anchors.topMargin: Theme.halfPadding
                    anchors.rightMargin: Theme.halfPadding
                    target: acPanelItem
                }
            }

            // Container for the Activity Center Area in Portrait
            Popup {
                id: acPortraitPopup
                parent: Overlay.overlay
                modal: true
                focus: true
                padding: 0
                closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
                width: parent.width
                height: parent.height * 0.9
                y: parent.height - height

                enter: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0.0; to: 1.0
                            duration: ThemeUtils.AnimationDuration.Slow
                        }
                        NumberAnimation {
                            property: "y"
                            from: acPortraitPopup.parent.height
                            to: acPortraitPopup.parent.height - acPortraitPopup.height
                            duration: ThemeUtils.AnimationDuration.Slow
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                exit: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 1.0; to: 0.0
                            duration: ThemeUtils.AnimationDuration.Slow
                        }
                        NumberAnimation {
                            property: "y"
                            from: acPortraitPopup.parent.height - acPortraitPopup.height
                            to: acPortraitPopup.parent.height
                            duration: ThemeUtils.AnimationDuration.Slow
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Overlay.modal: Rectangle {
                    color: Theme.palette.backdropColor
                }

                background: null

                contentItem: LayoutItemProxy {
                    target: acPanelItem
                    anchors.fill: parent
                }

                // Sync the main property when autoclose
                onClosed: { mainLayoutItem.openACCenterPanel = false }
            }

            ActivityCenterPanel {
                id: acPanelItem

                Loader {
                    id: acPanelLoader
                    sourceComponent: ActivityCenterAdaptor {
                        contactsModel: appMain.contactsStore.contactsModel
                        userProfileName: appMain.profileStore.name
                        notifications: appMain.activityCenterStore.activityCenterNotifications
                        getCommunityDetails: function(communityId) {
                            return appMain.rootChatStore.getCommunityDetailsAsJson(communityId)
                        }
                        getChatDetails: function(chatId) {
                            return appMain.rootChatStore.getChatDetails(chatId)
                        }
                        onPopulateContactDetailsRequested: (contactId) => appMain.contactsStore.populateContactDetails(contactId)
                    }
                }

                readonly property ActivityCenterAdaptor adaptor: acPanelLoader.item

                backgroundColor: Theme.palette.statusAppLayout.backgroundColor

                hasAdmin: appMain.activityCenterStore.adminCount > 0
                hasReplies: appMain.activityCenterStore.repliesCount > 0
                hasMentions: appMain.activityCenterStore.mentionsCount > 0
                hasContactRequests: appMain.activityCenterStore.contactRequestsCount > 0
                hasMembership: appMain.activityCenterStore.membershipCount > 0
                hasSystem: appMain.activityCenterStore.systemCount > 0
                hasNews: appMain.activityCenterStore.newsCount > 0
                activeGroup: appMain.activityCenterStore.activeNotificationGroup

                hasUnreadNotifications: appMain.activityCenterStore.unreadNotificationsCount > 0
                readNotificationsStatus: appMain.activityCenterStore.activityCenterReadType
                notificationsModel: adaptor?.model ?? null
                newsSettingsStatus: appMain.notificationsStore.notificationsSettings.notifSettingStatusNews
                newsEnabledViaRSS: appMain.privacyStore.isStatusNewsViaRSSEnabled

                onCloseRequested: mainLayoutItem.openACCenterPanel = false
                onMarkAllAsReadRequested: appMain.activityCenterStore.markAllActivityCenterNotificationsRead()
                onHideShowReadNotificationsRequested: {
                    appMain.activityCenterStore.setActivityCenterReadType(!hideReadNotifications ?
                                                                              ActivityCenterTypes.ActivityCenterReadType.Unread :
                                                                              ActivityCenterTypes.ActivityCenterReadType.All)
                }
                onSetActiveGroupRequested: (group) => { appMain.activityCenterStore.setActiveNotificationGroup(group) }
                onFetchMoreNotificationsRequested: appMain.activityCenterStore.fetchActivityCenterNotifications()
                onEnableNewsViaRSSRequested: appMain.privacyStore.setNewsRSSEnabled(true)
                onEnableNewsRequested: appMain.notificationsStore.notificationsSettings.notifSettingStatusNews = Constants.settingsSection.notifications.sendAlertsValue

                // Card Interactions
                onMarkNotificationRead: (notificationId) => {
                    appMain.activityCenterStore.markActivityCenterNotificationRead(notificationId)
                    if (hideReadNotifications)
                        appMain.activityCenterStore.setActivityCenterReadType(ActivityCenterTypes.ActivityCenterReadType.Unread)
                }
                onMarkNotificationUnread: (notificationId) => { appMain.activityCenterStore.markActivityCenterNotificationUnread(notificationId) }
                onAvatarClicked: (avatarId) => { Global.openProfilePopup(avatarId) }
                onRedirectToDetails: (sectionId, subsectionId, subsectionItemId) => {
                                         appMain.rootStore.setNavToMsgDetailsFlag(true) // It covers in-app link navigation in portrait mode
                                         appMain.activityCenterStore.switchTo(sectionId, subsectionId, subsectionItemId)

                                         // Guard in case of portrait
                                         acPortraitPopup.close()
                                     }
                onRedirectToSection: (sectionId) => {
                                         appMain.changeAppSectionBySectionId(sectionId)

                                         // Guard in case of portrait
                                         acPortraitPopup.close()
                                     }
                onRedirectToCommunitySettingsSubsection: (communityId, subsection, subsectionItem) => {
                                                             appMain.changeAppSectionBySectionId(communityId)
                                                             Global.switchToCommunitySettingsSubsection(communityId, subsection, subsectionItem)

                                                             // Guard in case of portrait
                                                             acPortraitPopup.close()
                                                         }
                onRedirectToPopup: (notification) => {
                                       // Right now, this is the only popup open, when more, we can add a popup type to determine it
                                       Global.openNewsMessagePopupRequested(notification)

                                       // Guard in case of portrait
                                       acPortraitPopup.close()
                                   }
                onRedirectToWallet: (address, txHash) => {
                                        Global.changeAppSectionBySectionType(Constants.appSection.wallet,
                                                                             WalletLayout.LeftPanelSelection.Address,
                                                                             WalletLayout.RightPanelSelection.Activity,
                                                                             {
                                                                                 address: address,
                                                                                 txHash: txHash
                                                                             })
                                    }

                // Quick actions
                onAcceptRequested: (requestId, actionId, notificationType) => {
                                       // This means, Contact Requests
                                       if (notificationType === ActivityCenterTypes.NotificationType.ContactRequest) {
                                           appMain.contactsStore.acceptContactRequest(requestId, actionId)
                                       }
                                       // This means, Community Membership Requests
                                       else if (notificationType === ActivityCenterTypes.NotificationType.CommunityMembershipRequest) {
                                           const store = appMain.messagingRootStore.createCommunityRootStore(appMain, requestId)
                                           store.communityAccessStore.acceptRequestToJoinCommunityRequested(actionId, requestId)
                                           Qt.callLater(() => store.destroy())
                                       }
                                       // This means, generic accept notification by id
                                       else {
                                           appMain.activityCenterStore.acceptActivityCenterNotification(actionId)
                                       }
                                   }
                onDeclineRequested: (requestId, actionId, notificationType) => {
                                        // This means, Contact Requests
                                        if (notificationType === ActivityCenterTypes.NotificationType.ContactRequest) {
                                            appMain.contactsStore.dismissContactRequest(requestId, actionId)
                                        }
                                        // This means, Community Membership Requests
                                        else if (notificationType === ActivityCenterTypes.NotificationType.CommunityMembershipRequest) {
                                            const store = appMain.messagingRootStore.createCommunityRootStore(appMain, requestId)
                                            store.communityAccessStore.declineRequestToJoinCommunityRequested(actionId, requestId)
                                            Qt.callLater(() => store.destroy())
                                        }
                                        // This means, generic dismiss notification by id
                                        else {
                                            appMain.activityCenterStore.dismissActivityCenterNotification(actionId)
                                        }
                                    }
            }

            Item {
                id: sectionLayout
                anchors.fill: parent
                readonly property bool offsetBySidebar: sidebar.alwaysVisible
                                                      || d.activeSectionType === Constants.appSection.browser
                readonly property real sidebarOffset: offsetBySidebar
                                                    ? sidebar.width * (sidebar.alwaysVisible ? 1.0 : sidebar.position)
                                                    : 0
                anchors.leftMargin: sidebarOffset

                StackLayout {
                    id: appView
                    anchors.fill: parent

                    currentIndex: {
                        switch (d.activeSectionType) {
                        case Constants.appSection.homePage:
                            return Constants.appViewStackIndex.homePage
                        case Constants.appSection.chat:
                            return Constants.appViewStackIndex.chat
                        case Constants.appSection.community:
                            // Track Repeater count so this binding re-evaluates when delegates
                            // are added — Item.children has no QML-observable notifier, so without
                            // this the lookup stays stuck on its first (empty) result if it ran
                            // before the Repeater populated.
                            void communityRepeater.count
                            for (let i = this.children.length - 1; i >= 0; i--) {
                                var obj = this.children[i]
                                if (obj && obj.sectionId && obj.sectionId === appMain.rootStore.activeSectionId) {
                                    return i
                                }
                            }
                            // Repeater hasn't created the matching delegate yet — fall back; the
                            // tracked count above will fire this binding again. If the fallback
                            // sticks (count > 0 and still no match), it means the active section
                            // id doesn't appear in the filtered model — surface that.
                            if (communityRepeater.count > 0) {
                                console.warn("AppMain: active community section",
                                             appMain.rootStore.activeSectionId,
                                             "not present in repeater (count=",
                                             communityRepeater.count, ")")
                            }
                            return Constants.appViewStackIndex.community
                        case Constants.appSection.communitiesPortal:
                            return Constants.appViewStackIndex.communitiesPortal
                        case Constants.appSection.wallet:
                            return Constants.appViewStackIndex.wallet
                        case Constants.appSection.profile:
                            return Constants.appViewStackIndex.profile
                        case Constants.appSection.browser:
                            return Constants.appViewStackIndex.browser
                        case Constants.appSection.market:
                            return Constants.appViewStackIndex.market
                        default:
                            // We should never end up here
                            console.error("AppMain: Unknown section type")
                        }
                    }
                    onCurrentIndexChanged: {
                        if (d.activeSectionType === Constants.appSection.chat || d.activeSectionType === Constants.appSection.community) {
                            if (d.maybeDisplayIntroduceYourselfPopup()) {
                                // we displayed the popup, so we should not display the enable message backup popup
                                return
                            }
                            popupRequestsHandler.maybeDisplayEnableMessageBackupPopup()
                        }
                    }

                    // NOTE:
                    // If we ever change stack layout component order we need to updade
                    // Constants.appViewStackIndex accordingly

                    HomePageLoader {
                        id: homePageLoader
                        focus: active
                        active: appMain.featureFlagsStore.homePageEnabled
                                && appView.currentIndex === Constants.appViewStackIndex.homePage

                        rootStore: appMain.rootStore
                        rootChatStore: appMain.rootChatStore
                        profileStore: appMain.profileStore
                        privacyStore: appMain.privacyStore
                        featureFlagsStore: appMain.featureFlagsStore
                        contactsAdaptor: contactsModelAdaptor
                        dappsServiceLoader: dAppsServiceLoader

                        browserEnabled: d.isBrowserEnabled
                        syncingBadgeCount: d.syncingBadgeCount
                        leftPanelWidthOverride: mainLayoutItem.leftPanelWidthOverride

                        onAppSectionRequested: (sectionType, subsection, subSubsection, data) =>
                            globalConns.onAppSectionBySectionTypeChanged(sectionType, subsection, subSubsection, data)
                    }

                    ChatLoader {
                        id: personalChatLayoutLoader

                        active: false
                        // Do not unload section data from the memory in order not
                        // to reset scroll, not send text input and etc during the
                        // sections switching
                        Binding on active {
                            when: appView.currentIndex === Constants.appViewStackIndex.chat
                            value: true
                            restoreMode: Binding.RestoreNone
                        }

                        rootStore: appMain.rootStore
                        contactsStore: appMain.contactsStore
                        accountSettingsStore: appMain.accountSettingsStore
                        featureFlagsStore: appMain.featureFlagsStore
                        sharedRootStore: appMain.sharedRootStore
                        currencyStore: appMain.currencyStore
                        communityTokensStore: appMain.communityTokensStore
                        networkConnectionStore: appMain.networkConnectionStore
                        networksStore: appMain.networksStore
                        transactionStore: appMain.transactionStore
                        tokensStore: appMain.tokensStore
                        walletAssetsStore: appMain.walletAssetsStore
                        advancedStore: appMain.advancedStore
                        createChatPropertiesStore: appMain.createChatPropertiesStore
                        contactsAdaptor: contactsModelAdaptor
                        popupHandler: popupRequestsHandler
                        emojiPopupLoader: statusEmojiPopup
                        stickersPopupLoader: statusStickersPopupLoader

                        createChatViewOpened: createChatView.opened
                        isPortraitMode: appMain.isPortraitMode
                        leftPanelWidthOverride: mainLayoutItem.leftPanelWidthOverride

                        onOpenAppSearchRequested: appSearch.openSearchPopup()
                    }

                    CommunitiesPortalLoader {
                        active: appView.currentIndex === Constants.appViewStackIndex.communitiesPortal
                        rootStore: appMain.rootStore
                        communitiesStore: appMain.communitiesStore
                        leftPanelWidthOverride: mainLayoutItem.leftPanelWidthOverride
                    }

                    WalletLoader {
                        active: appView.currentIndex === Constants.appViewStackIndex.wallet

                        rootStore: appMain.rootStore
                        contactsStore: appMain.contactsStore
                        featureFlagsStore: appMain.featureFlagsStore
                        sharedRootStore: appMain.sharedRootStore
                        networkConnectionStore: appMain.networkConnectionStore
                        networksStore: appMain.networksStore
                        communitiesStore: appMain.communitiesStore
                        transactionStore: appMain.transactionStore
                        popupHandler: popupRequestsHandler
                        dappsServiceLoader: dAppsServiceLoader
                        emojiPopupLoader: statusEmojiPopup

                        appMainVisible: appMain.visible
                        leftPanelWidthOverride: mainLayoutItem.leftPanelWidthOverride
                    }

                    BrowserLoader {
                        id: browserLayoutContainer

                        // Do not unload section data from the memory once activated
                        active: false
                        Binding on active {
                            when: d.isBrowserEnabled && appView.currentIndex === Constants.appViewStackIndex.browser
                            value: true
                            restoreMode: Binding.RestoreNone
                        }

                        rootStore: appMain.rootStore
                        featureFlagsStore: appMain.featureFlagsStore
                        profileStore: appMain.profileStore
                        advancedStore: appMain.advancedStore
                        networksStore: appMain.networksStore
                        currencyStore: appMain.currencyStore
                        transactionStore: appMain.transactionStore
                        popupHandler: popupRequestsHandler

                        leftPanelWidthOverride: mainLayoutItem.leftPanelWidthOverride
                    }

                    ProfileLoader {
                        id: profileLoader

                        active: appView.currentIndex === Constants.appViewStackIndex.profile

                        rootStore: appMain.rootStore
                        contactsStore: appMain.contactsStore
                        featureFlagsStore: appMain.featureFlagsStore
                        sharedRootStore: appMain.sharedRootStore
                        utilsStore: appMain.utilsStore
                        networkConnectionStore: appMain.networkConnectionStore
                        networksStore: appMain.networksStore
                        currencyStore: appMain.currencyStore
                        communitiesStore: appMain.communitiesStore
                        messagingRootStore: appMain.messagingRootStore
                        messagingSettingsStore: appMain.messagingSettingsStore
                        aboutStore: appMain.aboutStore
                        profileStore: appMain.profileStore
                        devicesStore: appMain.devicesStore
                        advancedStore: appMain.advancedStore
                        privacyStore: appMain.privacyStore
                        notificationsStore: appMain.notificationsStore
                        languageStore: appMain.languageStore
                        keycardStore: appMain.keycardStore
                        keycardNewStore: appMain.keycardNewStore
                        walletProfileStore: appMain.walletProfileStore
                        ensUsernamesStore: appMain.ensUsernamesStore
                        tokensStore: appMain.tokensStore
                        walletAssetsStore: appMain.walletAssetsStore
                        walletCollectiblesStore: appMain.walletCollectiblesStore
                        browserPreferencesStore: appMain.browserPreferencesStore

                        contactsAdaptor: contactsModelAdaptor
                        popupHandler: popupRequestsHandler
                        emojiPopupLoader: statusEmojiPopup
                        keychain: appMain.keychain

                        isProduction: appMain.rootStore.isProduction
                        systemTrayIconAvailable: appMain.systemTrayIconAvailable
                        theme: appMainLocalSettings.theme
                        fontSize: appMainLocalSettings.fontSize
                        paddingFactor: appMainLocalSettings.paddingFactor
                        whitelistedDomainsModel: appMainLocalSettings.whitelistedUnfurledDomains
                        leftPanelWidthOverride: mainLayoutItem.leftPanelWidthOverride

                        onThemeChangeRequested: (theme) => {
                            appMainLocalSettings.theme = theme
                            ThemeUtils.setTheme(appMain.Window.window, theme)
                        }
                        onFontSizeChangeRequested: (fontSize) => {
                            appMainLocalSettings.fontSize = fontSize
                            ThemeUtils.setFontSize(appMain.Window.window, fontSize)
                        }
                        onPaddingFactorChangeRequested: (paddingFactor) => {
                            appMainLocalSettings.paddingFactor = paddingFactor
                            ThemeUtils.setPaddingFactor(appMain.Window.window, paddingFactor)
                        }
                        onRemoveWhitelistedDomainRequested: (index) => {
                            // in order to notify changes in this model, we need to re assign to this model
                            const domainRemoved = appMainLocalSettings.whitelistedUnfurledDomains[index]
                            const cpy = appMainLocalSettings.whitelistedUnfurledDomains.slice()
                            cpy.splice(index, 1)
                            appMainLocalSettings.whitelistedUnfurledDomains = cpy
                            Global.displaySuccessToastMessage(qsTr("%1 was removed from your trusted sites.").arg(domainRemoved))
                        }
                    }

                    MarketLoader {
                        active: appView.currentIndex === Constants.appViewStackIndex.market

                        rootStore: appMain.rootStore
                        featureFlagsStore: appMain.featureFlagsStore
                        currencyStore: appMain.currencyStore
                        marketStore: appMain.marketStore
                        popupHandler: popupRequestsHandler

                        leftPanelWidthOverride: mainLayoutItem.leftPanelWidthOverride
                    }

                    Repeater {
                        id: communityRepeater

                        model: SortFilterProxyModel {
                            sourceModel: appMain.rootStore.sectionsModel
                            filters: ValueFilter {
                                roleName: "sectionType"
                                value: Constants.appSection.community
                            }
                        }

                        delegate: CommunityChatLoader {
                            required property var model

                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                            Layout.fillHeight: true

                            active: false
                            // Do not unload section data from the memory in order not
                            // to reset scroll, not send text input and etc during the
                            // sections switching
                            Binding on active {
                                when: sectionId === appMain.rootStore.activeSectionId
                                value: true
                                restoreMode: Binding.RestoreNone
                            }

                            sectionId: model.id
                            sectionItemModel: model

                            rootStore: appMain.rootStore
                            contactsStore: appMain.contactsStore
                            accountSettingsStore: appMain.accountSettingsStore
                            featureFlagsStore: appMain.featureFlagsStore
                            sharedRootStore: appMain.sharedRootStore
                            currencyStore: appMain.currencyStore
                            communityTokensStore: appMain.communityTokensStore
                            networkConnectionStore: appMain.networkConnectionStore
                            networksStore: appMain.networksStore
                            transactionStore: appMain.transactionStore
                            tokensStore: appMain.tokensStore
                            walletAssetsStore: appMain.walletAssetsStore
                            advancedStore: appMain.advancedStore
                            communitiesStore: appMain.communitiesStore
                            messagingRootStore: appMain.messagingRootStore
                            createChatPropertiesStore: appMain.createChatPropertiesStore
                            contactsAdaptor: contactsModelAdaptor
                            popupHandler: popupRequestsHandler
                            emojiPopupLoader: statusEmojiPopup
                            stickersPopupLoader: statusStickersPopupLoader

                            createChatViewOpened: createChatView.opened
                            isPortraitMode: appMain.isPortraitMode
                            leftPanelWidthOverride: mainLayoutItem.leftPanelWidthOverride

                            onOpenAppSearchRequested: appSearch.openSearchPopup()
                        }
                    }
                }

                Loader {
                    id: createChatView

                    property bool opened: false
                    readonly property real defaultWidth: parent.width - Constants.chatSectionLeftColumnWidth -
                             anchors.rightMargin - anchors.leftMargin
                    active: appMain.rootStore.sectionsLoaded && opened

                    anchors.top: parent.top
                    anchors.topMargin: Theme.halfPadding
                    anchors.rightMargin: Theme.halfPadding
                    anchors.leftMargin: Theme.halfPadding
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.left: appMain.isPortraitMode ? parent.left : undefined

                    sourceComponent: CreateChatView {
                        width: Math.min(Math.max(implicitWidth, createChatView.defaultWidth), createChatView.parent.width)
                        utilsStore: appMain.utilsStore
                        rootStore: ChatStores.RootStore {
                            contactsStore: appMain.contactsStore
                            currencyStore: appMain.currencyStore
                            communityTokensStore: appMain.communityTokensStore
                            openCreateChat: createChatView.opened
                            isChatSectionModule: true
                        }
                        createChatPropertiesStore: appMain.createChatPropertiesStore

                        mutualContactsModel: contactsModelAdaptor.mutualContacts
                        allContactsModel: appMain.contactsStore.contactsModel

                        emojiPopup: statusEmojiPopup.item
                        stickersPopup: statusStickersPopupLoader.item
                    }
                }
            }

            PrimaryNavSidebar {
                id: sidebar
                height: parent.height
                alwaysVisible: !appMain.isPortraitMode

                browserSectionActive: d.activeSectionType === Constants.appSection.browser

                PrimaryNavSidebarAdaptor {
                    id: sidebarAdaptor
                    sectionsModel: appMain.rootStore.sectionsModel

                    showEnabledSectionsOnly: true
                    marketEnabled: appMain.featureFlagsStore.marketEnabled
                    browserEnabled: d.isBrowserEnabled
                }

                regularItemsModel: sidebarAdaptor.regularItemsModel
                communityItemsModel: sidebarAdaptor.communityItemsModel
                bottomItemsModel: sidebarAdaptor.bottomItemsModel


                acVisible: mainLayoutItem.openACCenterPanel
                acHasUnseenNotifications: appMain.activityCenterStore.hasUnseenNotifications
                acUnreadNotificationsCount: appMain.activityCenterStore.unreadNotificationsCount

                selfContactDetails: ownContactDetails
                getEmojiHashFn: appMain.utilsStore.getEmojiHash
                getLinkToProfileFn: appMain.contactsStore.getLinkToProfile

                communityPopupMenu: communityContextMenuComponent

                profileSectionHasNotification: {
                    if (contactsModelAdaptor.pendingReceivedRequestContacts.ModelCount.count > 0) // pending contact request
                        return true
                    if (!appMain.privacyStore.mnemonicBackedUp && !appMain.profileStore.userDeclinedBackupBanner) // seedphrase not backed up (removed)
                        return true
                    if (d.syncingBadgeCount > 0) // sync entries
                        return true
                    return false
                }
                thirdpartyServicesEnabled: appMain.rootStore.thirdpartyServicesEnabled

                onActivityCenterRequested: function(shouldShow) { mainLayoutItem.openACCenterPanel = shouldShow }
                onSetCurrentUserStatusRequested: status => appMain.rootStore.setCurrentUserStatus(status)
                onViewProfileRequested: pubKey => Global.openProfilePopup(pubKey)
                onShareOwnProfileRequested: Global.shareProfileDialogRequested(ownContactDetails.publicKey)

                onItemActivated: function(sectionType, sectionId) {
                    // Ensure Activity Center Panel is closed when manual navigation done
                    mainLayoutItem.openACCenterPanel = false

                    if (sectionType === Constants.appSection.swap) {
                        popupRequestsHandler.launchSwap()
                    } else if (sectionType === Constants.appSection.qrCodeScanner) {
                        Global.openQRScannerRequested()
                    } else {
                        changeAppSectionBySectionId(sectionId)
                    }
                }

                onAlwaysVisibleChanged: {
                    if(!alwaysVisible) {
                        // Show the navigation education dialog, the first time the new collapsed menu bar
                        // is shown after it's been introduced
                        d.tryOpenNavigationEducationPopup()
                    }
                }
            }
        }
    } // ColumnLayout

    Component {
        id: communityContextMenuComponent
        StatusMenu {
            id: communityContextMenu

            required property var model

            property var chatCommunitySectionModule

            readonly property bool isSpectator: model.spectated && !model.joined

            openHandler: function () {
                // we cannot return QVariant if we pass another parameter in a function call
                // that's why we're using it this way
                communityContextMenu.chatCommunitySectionModule = appMain.rootChatStore.getCommunitySectionModule(model.id)
            }

            StatusAction {
                text: qsTr("Invite People")
                icon.name: "share-ios"
                objectName: "invitePeople"
                onTriggered: {
                    popups.openInviteFriendsToCommunityPopup(model,
                                                             communityContextMenu.chatCommunitySectionModule,
                                                             null)
                }
            }

            StatusAction {
                text: qsTr("Community Info")
                icon.name: "info"
                onTriggered: popups.openCommunityProfilePopup(appMain.rootStore, model, communityContextMenu.chatCommunitySectionModule)
            }

            StatusAction {
                text: qsTr("Community Rules")
                icon.name: "text"
                onTriggered: popups.openCommunityRulesPopup(model.name, model.introMessage, model.image, model.color)
            }

            StatusMenuSeparator {}

            MuteChatMenuItem {
                enabled: !model.muted
                title: qsTr("Mute Community")
                onMuteTriggered: {
                    communityContextMenu.chatCommunitySectionModule.setCommunityMuted(interval)
                    communityContextMenu.close()
                }
            }

            StatusAction {
                enabled: model.muted
                text: qsTr("Unmute Community")
                icon.name: "notification"
                onTriggered: communityContextMenu.chatCommunitySectionModule.setCommunityMuted(Constants.MutingVariations.Unmuted)
            }

            StatusAction {
                text: qsTr("Mark as read")
                icon.name: "check-circle"
                onTriggered: communityContextMenu.chatCommunitySectionModule.markAllReadInCommunity()
            }

            StatusAction {
                text: qsTr("Edit Shared Addresses")
                icon.name: "wallet"
                enabled: {
                    if (model.memberRole === Constants.memberRole.owner || communityContextMenu.isSpectator)
                        return false
                    return true
                }
                onTriggered: {
                    communityContextMenu.close()
                    Global.openEditSharedAddressesFlow(model.id)
                }
            }

            StatusMenuSeparator { visible: leaveCommunityMenuItem.enabled }

            StatusAction {
                id: leaveCommunityMenuItem
                objectName: "leaveCommunityMenuItem"
                // allow to leave community for the owner in non-production builds
                enabled: model.memberRole !== Constants.memberRole.owner || !production
                text: {
                    if (communityContextMenu.isSpectator)
                        return qsTr("Close Community")
                    return qsTr("Leave Community")
                }
                icon.name: communityContextMenu.isSpectator ? "close-circle" : "arrow-left"
                type: StatusAction.Type.Danger
                onTriggered: communityContextMenu.isSpectator ? communityContextMenu.chatCommunitySectionModule.leaveCommunity()
                                                              : popups.openLeaveCommunityPopup(model.name, model.id, model.outroMessage)
            }
        }
    }

    Instantiator {
        model: 9
        delegate: Action {
            shortcut: "Ctrl+" + (index + 1)
            onTriggered: index => {
                Global.setNthEnabledSectionActive(index)
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+K"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (homePageLoader.active)
                return
            if (!channelPickerLoader.active)
                channelPickerLoader.active = true

            if (channelPickerLoader.item.opened) {
                channelPickerLoader.item.close()
                channelPickerLoader.active = false
            } else {
                channelPickerLoader.item.open()
            }
        }
    }
    Shortcut {
        sequences: [StandardKey.Find]
        context: Qt.ApplicationShortcut
        enabled: d.activeSectionType !== Constants.appSection.browser // has its own "Search"
        onActivated: {
            if (appSearch.active) {
                appSearch.closeSearchPopup()
            } else {
                appSearch.openSearchPopup()
            }
        }
    }

    Shortcut {
        id: homePageShortcut
        context: Qt.ApplicationShortcut
        sequence: "Ctrl+J"
        onActivated: d.openHomePage()
        enabled: appMain.featureFlagsStore.homePageEnabled
    }

    Shortcut {
        context: Qt.ApplicationShortcut
        sequences: ["Ctrl+,", StandardKey.Preferences]
        onActivated: globalConns.onAppSectionBySectionTypeChanged(Constants.appSection.profile,
                                                                  Utils.getSettingsSubsectionForSection(d.activeSectionType))
    }

    Loader {
        id: channelPickerLoader
        active: false
        sourceComponent: StatusSearchListPopup {
            directParent: appMain
            relativeX: appMain.width/2 - width/2
            relativeY: appMain.height/2 - height/2
            searchBoxPlaceholder: qsTr("Where do you want to go?")
            model: rootStore.chatSearchModel

            onSelected: function (sectionId, chatId) {
                rootStore.setActiveSectionChat(sectionId, chatId)
                close()
            }
        }
    }

    StatusListView {
        id: toastArea
        objectName: "ephemeralNotificationList"
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: 374
        height: Math.min(parent.height - 120, toastArea.contentHeight)
        spacing: 8
        verticalLayoutDirection: ListView.BottomToTop
        model: appMain.rootStore.ephemeralNotificationModel
        clip: false

        delegate: StatusToastMessage {
            readonly property bool isSquare : isSquareShape(model.actionData)

            // Specific method to calculate image radius depending on if the toast represents some info about a collectible or an asset
            function isSquareShape(data) {
                // It expects the data is a JSON file containing `tokenType`
                if(data) {
                    var parsedData = JSON.parse(data)
                    var tokenType = parsedData.tokenType
                    return tokenType === Constants.TokenType.ERC721
                }
                return false
            }

            objectName: "statusToastMessage"
            width: ListView.view.width
            primaryText: model.title
            secondaryText: model.subTitle
            image: model.image
            imageRadius: model.image && isSquare ? 8 : imageSize / 2
            icon.name: model.icon
            iconColor: model.iconColor
            loading: model.loading
            type: model.ephNotifType
            linkUrl: model.url
            actionRequired: model.actionType !== ToastsManager.ActionType.None
            duration: model.durationInMs
            onClicked: {
                appMain.rootStore.ephemeralNotificationClicked(model.timestamp)
                this.open = false
            }
            onLinkActivated: {
                this.open = false
                if(actionRequired) {
                    toastsManager.doAction(model.actionType, model.actionData)
                    return
                }

                if (link.startsWith("#") && link !== "#") { // internal link to section
                    const sectionArgs = link.substring(1).split("/")
                    const section = sectionArgs[0]
                    let subsection = sectionArgs.length > 1 ? sectionArgs[1] : 0
                    let subsubsection = sectionArgs.length > 2 ? sectionArgs[2] : -1
                    Global.changeAppSectionBySectionType(section, subsection, subsubsection)
                }
                else
                    Global.requestOpenLink(link)
            }
            onClose: {
                appMain.rootStore.removeEphemeralNotification(model.timestamp)
            }
        }
    }

    Loader {
        id: keycardPopupForAuthenticationOrSigning
        active: false
        sourceComponent: KeycardPopup {
            myKeyUid: appMain.profileStore.keyUid
            sharedKeycardModule: appMain.rootStore.keycardSharedModuleForAuthenticationOrSigning
        }

        onLoaded: {
            keycardPopupForAuthenticationOrSigning.item.open()
        }
    }

    Loader {
        id: keycardPopup
        active: false
        sourceComponent: KeycardPopup {
            myKeyUid: appMain.profileStore.keyUid
            sharedKeycardModule: appMain.rootStore.keycardSharedModule
        }

        onLoaded: {
            keycardPopup.item.open()
        }
    }

    Loader {
        id: addEditSavedAddress

        active: false

        property var params

        function open(params = {}) {
            addEditSavedAddress.params = params
            addEditSavedAddress.active = true
        }

        function close() {
            addEditSavedAddress.active = false
        }

        onLoaded: {
            addEditSavedAddress.item.initWithParams(addEditSavedAddress.params)
            addEditSavedAddress.item.open()
        }

        sourceComponent: WalletPopups.AddEditSavedAddressPopup {
            store: WalletStores.RootStore
            sharedRootStore: appMain.sharedRootStore
            contactsModel: appMain.contactsStore.contactsModel

            onPopulateContactDetails: (publicKey) => appMain.contactsStore.populateContactDetails(publicKey)
            onClosed: {
                addEditSavedAddress.close()
            }
        }
    }

    Connections {
        target: WalletStores.RootStore

        function onSavedAddressAddedOrUpdated(added: bool, name: string, address: string, errorMsg: string) {
            console.warn("[saved-address] onSavedAddressAddedOrUpdated added=", added, "name=", name, "address=", address, "errorMsg=", errorMsg)
            WalletStores.RootStore.addingSavedAddress = false
            WalletStores.RootStore.lastCreatedSavedAddress = { address: address, error: errorMsg }

            if (!!errorMsg) {
                let mode = qsTr("adding")
                if (!added) {
                    mode = qsTr("editing")
                }

                Global.displayToastMessage(qsTr("An error occurred while %1 %2 address").arg(mode).arg(name),
                                           "",
                                           "warning",
                                           false,
                                           Constants.ephemeralNotificationType.danger,
                                           ""
                                           )
                return
            }

            let msg = qsTr("%1 successfully added to your saved addresses")
            if (!added) {
                msg = qsTr("%1 saved address successfully edited")
            }
            Global.displayToastMessage(msg.arg(name),
                                       "",
                                       "checkmark-circle",
                                       false,
                                       Constants.ephemeralNotificationType.success,
                                       ""
                                       )
        }
    }

    Loader {
        id: deleteSavedAddress

        active: false

        property var params: ({})

        function open(params = {}) {
            deleteSavedAddress.params = params
            deleteSavedAddress.active = true
        }

        function close() {
            deleteSavedAddress.active = false
        }

        onLoaded: {
            deleteSavedAddress.item.open()
        }

        sourceComponent: WalletPopups.RemoveSavedAddressPopup {
            name: deleteSavedAddress.params.name ?? ""
            address: deleteSavedAddress.params.address ?? ""
            ens: deleteSavedAddress.params.ens ?? ""
            colorId: deleteSavedAddress.params.colorId ?? "blue"

            onClosed: {
                deleteSavedAddress.close()
            }

            onRemoveSavedAddress: {
                WalletStores.RootStore.deleteSavedAddress(address)
                close()
            }
        }
    }

    Connections {
        target: WalletStores.RootStore

        function onSavedAddressDeleted(name: string, address: string, errorMsg: string) {
            console.warn("[saved-address] onSavedAddressDeleted name=", name, "address=", address, "errorMsg=", errorMsg)
            WalletStores.RootStore.deletingSavedAddress = false

            if (!!errorMsg) {

                Global.displayToastMessage(qsTr("An error occurred while removing %1 address").arg(name),
                                           "",
                                           "warning",
                                           false,
                                           Constants.ephemeralNotificationType.danger,
                                           ""
                                           )
                return
            }

            Global.displayToastMessage(qsTr("%1 was successfully removed from your saved addresses").arg(name),
                                       "",
                                       "checkmark-circle",
                                       false,
                                       Constants.ephemeralNotificationType.success,
                                       ""
                                       )
        }
    }

    Loader {
        id: showQR

        active: false

        property bool showSingleAccount: false
        property bool showForSavedAddress: false
        property var params
        property var selectedAccount: ({
                                           name: "",
                                           address: "",
                                           colorId: "",
                                           emoji: ""
                                       })

        function open(params = {}) {
            showQR.showSingleAccount = params.showSingleAccount?? false
            showQR.showForSavedAddress = params.showForSavedAddress?? false
            showQR.params = params

            if (showQR.showSingleAccount || showQR.showForSavedAddress) {
                showQR.selectedAccount.name = params.name?? ""
                showQR.selectedAccount.address = params.address?? ""
                showQR.selectedAccount.mixedcaseAddress = params.mixedcaseAddress?? ""
                showQR.selectedAccount.colorId = params.colorId?? ""
                showQR.selectedAccount.emoji = params.emoji?? ""
            }

            showQR.active = true
        }

        function close() {
            showQR.active = false
        }

        onLoaded: {
            showQR.item.switchingAccounsEnabled = showQR.params.switchingAccounsEnabled?? true
            showQR.item.hasFloatingButtons = showQR.params.hasFloatingButtons?? true

            showQR.item.open()
        }

        sourceComponent: WalletPopups.ReceiveModal {

            ModelEntry {
                id: selectedReceiverAccount
                key: "address"
                sourceModel: appMain.transactionStore.accounts
                value: appMain.transactionStore.selectedReceiverAccountAddress
            }

            accounts: {
                if (showQR.showSingleAccount || showQR.showForSavedAddress) {
                    return null
                }
                return WalletStores.RootStore.accounts
            }

            selectedAccount: {
                if (showQR.showSingleAccount || showQR.showForSavedAddress) {
                    return showQR.selectedAccount
                }
                return selectedReceiverAccount.item ?? SQUtils.ModelUtils.get(appMain.transactionStore.accounts, 0)
            }

            onUpdateSelectedAddress: (address) => {
                if (showQR.showSingleAccount || showQR.showForSavedAddress) {
                    return
                }
                appMain.transactionStore.setReceiverAccount(address)
            }

            onClosed: {
                showQR.close()
            }
        }
    }


    Loader {
        id: savedAddressActivity

        active: false

        property var params

        function open(params = {}) {
            savedAddressActivity.params = params
            savedAddressActivity.active = true
        }

        function close() {
            savedAddressActivity.active = false
        }

        onLoaded: {
            savedAddressActivity.item.initWithParams(savedAddressActivity.params)
            savedAddressActivity.item.open()
        }

        sourceComponent: WalletPopups.SavedAddressActivityPopup {
            networkConnectionStore: appMain.networkConnectionStore
            networksStore: appMain.networksStore
            walletRootStore: WalletStores.RootStore

            onSendToAddressRequested: {
                Global.sendToRecipientRequested(address)
            }
            onClosed: {
                savedAddressActivity.close()
            }
        }
    }

    Component {
        id: introduceYourselfPopupComponent
        IntroduceYourselfPopup {
            visible: true
            destroyOnClose: true
            pubKey: appMain.profileStore.compressedPubKey
            colorId: appMain.profileStore.colorId
            onClosed: appMainLocalSettings.introduceYourselfPopupSeen = true
            onAccepted: Global.changeAppSectionBySectionType(Constants.appSection.profile)
        }
    }

    Loader {
        id: dAppsServiceLoader

        signal dappDisconnectRequested(string dappUrl)
        signal dappConnectRequested()

        // It seems some of the functionality of the dapp connector depends on the DAppsService
        active: {
            return (featureFlagsStore.dappsEnabled || featureFlagsStore.connectorEnabled) && appMain.visible
        }

        sourceComponent: DAppsService {
            id: dAppsService

            DAppsPopups.DAppsWorkflow {
                id: dappsWorkflow

                enabled: dAppsService.isServiceOnline
                visualParent: appMain
                loginType: appMain.rootStore.getLoginType()
                selectedAccountAddress: WalletStores.RootStore.selectedAddress
                dAppsModel: dAppsService.dappsModel
                accountsModel: WalletStores.RootStore.nonWatchAccounts
                networksModel: appMain.networksStore.activeNetworks
                sessionRequestsModel: dAppsService.sessionRequestsModel
                walletConnectEnabled: featureFlagsStore.dappsEnabled
                connectorEnabled: featureFlagsStore.connectorEnabled

                formatBigNumber: (number, symbol, noSymbolOption) => appMain.currencyStore.formatBigNumber(number, symbol, noSymbolOption)

                onDisconnectRequested: (topic, url, connectorId, clientId) => dAppsService.disconnect(topic, url, connectorId, clientId || "")
                onPairingRequested: (uri) => dAppsService.pair(uri)
                onPairingValidationRequested: (uri) => dAppsService.validatePairingUri(uri)
                onConnectionAccepted: (pairingId, chainIds, selectedAccount) => dAppsService.approvePairSession(pairingId, chainIds, selectedAccount)
                onConnectionDeclined: (pairingId) => dAppsService.rejectPairSession(pairingId)
                onSignRequestAccepted: (connectionId, requestId) => dAppsService.sign(connectionId, requestId)
                onSignRequestRejected: (connectionId, requestId) => dAppsService.rejectSign(connectionId, requestId, false /*hasError*/)
                onSignRequestIsLive: (connectionId, requestId) => dAppsService.signRequestIsLive(connectionId, requestId)
                onPairWithConnectorRequested: (connectorId) => {
                    if (connectorId == Constants.DAppConnectors.WalletConnect) {
                        dappsWorkflow.openPairing()
                    } else if (connectorId == Constants.DAppConnectors.StatusConnect) {
                        Global.requestOpenLink("https://chromewebstore.google.com/detail/a-wallet-connector-by-sta/kahehnbpamjplefhpkhafinaodkkenpg")
                    }
                }

                Connections {
                    target: dAppsServiceLoader

                    function onDappConnectRequested() {
                        dappsWorkflow.chooseConnector()
                    }

                    function onDappDisconnectRequested(dappUrl) {
                        dappsWorkflow.disconnectDapp(dappUrl)
                    }
                }
            }

            // DAppsModule provides the middleware for the dapps
            dappsModule: dappsModuleLoader.item
            // when active, this instantiates a DAppsModule; when inactive, item is null
            Loader {
                id: dappsModuleLoader
                active: appMain.rootStore.thirdpartyServicesEnabled

                sourceComponent: DAppsModule {
                    currenciesStore: appMain.currencyStore
                    groupedAccountAssetsModel: appMain.walletAssetsStore.groupedAccountAssetsModel
                    accountsModel: WalletStores.RootStore.nonWatchAccounts
                    networksModel: SortFilterProxyModel {
                        sourceModel: appMain.networksStore.activeNetworks
                        proxyRoles: [
                            FastExpressionRole {
                                name: "isOnline"
                                expression: !appMain.networkConnectionStore.blockchainNetworksDown.map(Number).includes(model.chainId)
                                expectedRoles: "chainId"
                            }
                        ]
                    }
                    wcSdk: ConnectorWCSDK {
                        enabled: featureFlagsStore.dappsEnabled && WalletStores.RootStore.walletSectionInst.walletReady
                        connectorController: WalletStores.RootStore.dappsConnectorController
                        networksModel: appMain.networksStore.activeNetworks
                        accountsModel: WalletStores.RootStore.nonWatchAccounts
                    }
                    bcSdk: DappsConnectorSDK {
                        enabled: featureFlagsStore.dappsEnabled && WalletStores.RootStore.walletSectionInst.walletReady
                        excludeClientIds: ["walletconnect"]
                        store: SharedStores.BrowserConnectStore {
                            controller: WalletStores.RootStore.dappsConnectorController
                        }
                        networksModel: appMain.networksStore.activeNetworks
                        accountsModel: WalletStores.RootStore.nonWatchAccounts
                    }
                    store: SharedStores.DAppsStore {
                        controller: WalletStores.RootStore.walletConnectController
                    }
                }
            }
            selectedAddress: WalletStores.RootStore.selectedAddress
            accountsModel: WalletStores.RootStore.nonWatchAccounts
            connectorFeatureEnabled: featureFlagsStore.connectorEnabled
            walletConnectFeatureEnabled: featureFlagsStore.dappsEnabled

            onDisplayToastMessage: (message, type) => {
                const icon = type === Constants.ephemeralNotificationType.danger ? "warning" :
                            type === Constants.ephemeralNotificationType.success ? "checkmark-circle" : "info"
                Global.displayToastMessage(message, "", icon, false, type, "")
            }
            onPairingValidated: (validationState) => {
                dappsWorkflow.pairingValidated(validationState)
            }
            onApproveSessionResult: (pairingId, err, newConnectionId) => {
                if (err) {
                    dappsWorkflow.connectionFailed(pairingId)
                    return
                }

                dappsWorkflow.connectionSuccessful(pairingId, newConnectionId)
            }
            onConnectDApp: (dappChains, dappUrl, dappName, dappIcon, connectorId, pairingId) => {
                dappsWorkflow.connectDApp(dappChains, dappUrl, dappName, dappIcon, connectorId, pairingId)
            }
        }
    }

    Connections {
        target: ClipboardUtils

        function onContentChanged() {
            if (!ClipboardUtils.hasText)
                return

            const text = ClipboardUtils.text

            if (text.length === 0 || text.length > 100)
                return

            const isAddress = SQUtils.ModelUtils.contains(
                              WalletStores.RootStore.accounts, "address",
                              text, Qt.CaseInsensitive)
            if (isAddress)
                WalletStores.RootStore.addressWasShown(text)
        }
    }

    Binding {
        target: WalletStores.RootStore
        property: "palette"
        value: appMain.Theme.palette
    }
}
