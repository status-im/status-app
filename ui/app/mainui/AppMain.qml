import QtCore
import QtQml
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models

import AppLayouts.Browser
import AppLayouts.Wallet
import AppLayouts.Node
import AppLayouts.Chat
import AppLayouts.Chat.views
import AppLayouts.Profile
import AppLayouts.Communities
import AppLayouts.Market
import AppLayouts.Market.stores
import AppLayouts.Wallet.services.dapps
import AppLayouts.HomePage

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
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Components.private
import StatusQ.Controls
import StatusQ.Layout
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.stores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.popups as WalletPopups
import AppLayouts.Wallet.popups.dapps as DAppsPopups
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores as AppStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.ActivityCenter
import AppLayouts.ActivityCenter.popups

import mainui.adaptors
import mainui.Handlers

import QtModelsToolkit
import SortFilterProxyModel

Item {
    id: appMain
    
    // Primary store container — all additional stores should be initialized under this root
    readonly property AppStores.RootStore rootStore: AppStores.RootStore {
        localBackupEnabled: appMain.featureFlagsStore.localBackupEnabled
        thirdpartyServicesEnabled: appMain.featureFlagsStore.privacyModeFeatureEnabled ?
                                   appMain.privacyStore.thirdpartyServicesEnabled: true
        onOpenUrl: (link) => Global.requestOpenLink(link)
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

    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property ProfileStores.LanguageStore languageStore
    // TODO: Only until the  old send modal transaction store can be replaced with this one
    readonly property WalletStores.TransactionStoreNew transactionStoreNew: WalletStores.TransactionStoreNew {}

    readonly property MarketStore marketStore: MarketStore {}

    required property Keychain keychain

    required property bool isCentralizedMetricsEnabled

    required property bool systemTrayIconAvailable

    function showEnableBiometricsFlow() {
        popupRequestsHandler.enableBiometricsPopupHandler.openPopup()
    }

    AllContactsAdaptor {
        id: allContacsAdaptor

        contactsModel: appMain.contactsStore.contactsModel

        selfPubKey: appMain.profileStore.pubKey
        selfDisplayName : appMain.profileStore.displayName
        selfName: appMain.profileStore.name
        selfPreferredDisplayName: appMain.profileStore.preferredName
        selfAlias: appMain.profileStore.username
        selfUsesDefaultName: appMain.profileStore.usesDefaultName
        selfIcon: appMain.profileStore.icon
        selfColorId: appMain.profileStore.colorId
        selfOnlineStatus: appMain.profileStore.currentUserStatus
        selfThumbnailImage: appMain.profileStore.thumbnailImage
        selfLargeImage: appMain.profileStore.largeImage
        selfBio: appMain.profileStore.bio
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

        onSendRequested: popupRequestsHandler.sendModalHandler.openSend()
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
                case Constants.SendType.Bridge: {
                    toastTitle = qsTr("Bridging %1 from %2 to %3 in %4").arg(sentAmount).arg(senderChainName).arg(recipientChainName).arg(sender)
                    if (approvalTx) {
                        toastTitle = qsTr("Setting spending cap: %1 in %2 for %3").arg(sentAmount).arg(sender).arg(txRecipient)
                    }
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
                case Constants.SendType.Bridge: {
                    toastTitle = qsTr("Bridged %1 from %2 to %3 in %4").arg(sentAmount).arg(senderChainName).arg(recipientChainName).arg(sender)
                    if (approvalTx) {
                        toastTitle = qsTr("Spending spending cap: %1 in %2 for %3").arg(sentAmount).arg(sender).arg(txRecipient)
                    }
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
                case Constants.SendType.Bridge: {
                    toastTitle = qsTr("Bridge failed: %1 from %2 to %3 in %4").arg(sentAmount).arg(senderChainName).arg(recipientChainName).arg(sender)
                    if (approvalTx) {
                        toastTitle = qsTr("Spending spending failed: %1 in %2 for %3").arg(sentAmount).arg(sender).arg(txRecipient)
                    }
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
        readonly property var networkChecker: NetworkChecker {}

        readonly property int activeSectionType: appMain.rootStore.activeSectionType
        readonly property bool isWalletRelatedSectionType: activeSectionType === Constants.appSection.wallet ||
                                                           activeSectionType === Constants.appSection.swap || activeSectionType === Constants.appSection.market ||
                                                           activeSectionType === Constants.appSection.dApp
        readonly property bool isBrowserEnabled: appMain.featureFlagsStore.browserEnabled &&
                                                 localAccountSensitiveSettings.isBrowserEnabled

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

        function openLinkInBrowser(link: string) {
            if (!appMain.rootStore.openLinksInStatus ||
                    !d.isBrowserEnabled ||
                    !appMain.rootStore.thirdpartyServicesEnabled) {
                Qt.openUrlExternally(link)
                return
            }
            globalConns.onAppSectionBySectionTypeChanged(Constants.appSection.browser)
            changeAppSectionBySectionId(Constants.appSection.browser)
            Qt.callLater(() => browserLayoutContainer.item.openUrlInNewTab(link))
        }
    }

    Settings {
        id: appMainLocalSettings
        category: "AppMainLocalSettings_%1".arg(allContacsAdaptor.selfPubKey)
        property var whitelistedUnfurledDomains: []
        property bool introduceYourselfPopupSeen
        property bool enableMessageBackupPopupSeen
        property var recentEmojis
        property string skinColor // NB: must be a string for the twemoji lib to work; we don't want the `#` in the name
        property int theme: ThemeUtils.Style.System
        property int fontSize: {
            if (appMain.width < ThemeUtils.portraitBreakpoint.width) {
                return ThemeUtils.FontSize.FontSizeS
            }
            return ThemeUtils.FontSize.FontSizeM
        }
        property int paddingFactor: {
            if (appMain.width < ThemeUtils.portraitBreakpoint.width) {
                return ThemeUtils.PaddingFactor.PaddingXXS
            }
            return ThemeUtils.PaddingFactor.PaddingM
        }

        Component.onCompleted: {
            ThemeUtils.setTheme(appMain.Window.window, appMainLocalSettings.theme)
            ThemeUtils.setFontSize(appMain.Window.window, appMainLocalSettings.fontSize)
            ThemeUtils.setPaddingFactor(appMain.Window.window, appMainLocalSettings.paddingFactor)
        }
    }

    Popups {
        id: popups

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

        onOpenExternalLink: (link) => d.openLinkInBrowser(link)
        onSaveDomainToUnfurledWhitelist: function(domain) {
            const whitelistedHostnames = appMainLocalSettings.whitelistedUnfurledDomains || []
            if (!whitelistedHostnames.includes(domain)) {
                whitelistedHostnames.push(domain)
                appMainLocalSettings.whitelistedUnfurledDomains = whitelistedHostnames
                Global.displaySuccessToastMessage(qsTr("%1 added to your trusted sites.").arg(domain))
            }
        }
        onTransferOwnershipRequested: (tokenId, senderAddress) => popupRequestsHandler.sendModalHandler.transferOwnership(tokenId, senderAddress)
    }

    HandlersManager {
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
        privacyStore: appMain.privacyStore
        keychain: appMain.keychain
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
                profileLoader.item.forceSubsectionNavigation = true
            } else if (sectionType === Constants.appSection.wallet) {
                appView.children[Constants.appViewStackIndex.wallet].item.openDesiredView(subsection, subSubsection, data)
            } else if (sectionType === Constants.appSection.swap) {
                popupRequestsHandler.swapModalHandler.launchSwap()
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

    function changeAppSectionBySectionId(sectionId) {
        appMain.rootStore.setActiveSectionById(sectionId)
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
            store: appMain.rootChatStore
            isWalletEnabled: appMain.walletProfileStore.isWalletEnabled
            onBuyClicked: popupRequestsHandler.sendModalHandler.buyStickerPack(packId, price)
        }
    }
    
    property Item navBar: StatusAppNavBar {
        visible: !homePageLoader.active
        width: visible ? implicitWidth : 0

        thirdpartyServicesEnabled: appMain.rootStore.thirdpartyServicesEnabled

        topSectionModel: SortFilterProxyModel {
            sourceModel: appMain.rootStore.sectionsModel
            filters: [
                AnyOf {
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.homePage
                    }
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.wallet
                    }
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.swap
                        enabled: !appMain.featureFlagsStore.marketEnabled
                    }
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.market
                        enabled: appMain.featureFlagsStore.marketEnabled
                    }
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.chat
                    }
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.browser
                        enabled: d.isBrowserEnabled
                    }
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.node
                        enabled: localAccountSensitiveSettings.nodeManagementEnabled
                    }
                },
                ValueFilter {
                    roleName: "enabled"
                    value: true
                }
            ]
        }
        topSectionDelegate: navbarButton

        communityItemsModel: SortFilterProxyModel {
            sourceModel: appMain.rootStore.sectionsModel
            filters: [
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.community
                },
                ValueFilter {
                    roleName: "enabled"
                    value: true
                }
            ]
        }
        communityItemDelegate: StatusNavBarTabButton {
            objectName: "CommunityNavBarButton"
            anchors.horizontalCenter: parent.horizontalCenter
            name: model.icon.length > 0? "" : model.name
            icon.name: model.icon
            icon.source: model.image
            identicon.asset.color: (hovered || identicon.highlighted || checked) ? model.color : icon.color
            tooltip.text: model.name
            checked: model.active
            badge.value: model.notificationsCount
            badge.visible: model.hasNotification

            stateIcon.color: Theme.palette.dangerColor1
            stateIcon.border.color: Theme.palette.baseColor2
            stateIcon.border.width: 2
            stateIcon.visible: model.amIBanned
            stateIcon.asset.name: "cancel"
            stateIcon.asset.color: Theme.palette.baseColor2
            stateIcon.asset.width: 14

            thirdpartyServicesEnabled: appMain.rootStore.thirdpartyServicesEnabled

            onClicked: {
                changeAppSectionBySectionId(model.id)
            }

            popupMenu: Component {
                StatusMenu {
                    id: communityContextMenu
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
        }

        regularItemsModel: SortFilterProxyModel {
            sourceModel: appMain.rootStore.sectionsModel
            filters: [
                ValueFilter {
                    roleName: "enabled"
                    value: true
                },
                AnyOf {
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.profile
                    }
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.activityCenter
                    }
                    ValueFilter {
                        roleName: "sectionType"
                        value: Constants.appSection.communitiesPortal
                    }
                }
            ]
        }
        regularItemDelegate: navbarButton

        delegateHeight: 40

        profileComponent: ProfileButton {
            objectName: "statusProfileNavBarTabButton"

            name: appMain.profileStore.name
            usesDefaultName: appMain.profileStore.usesDefaultName
            pubKey: appMain.profileStore.pubKey
            compressedPubKey: appMain.profileStore.compressedPubKey
            iconSource: appMain.profileStore.icon
            colorId: appMain.profileStore.colorId
            currentUserStatus: appMain.profileStore.currentUserStatus

            getEmojiHashFn: appMain.utilsStore.getEmojiHash
            getLinkToProfileFn: appMain.contactsStore.getLinkToProfile
            onSetCurrentUserStatusRequested: (status) => appMain.rootStore.setCurrentUserStatus(status)
            onViewProfileRequested: (pubKey) => Global.openProfilePopup(pubKey)
        }

        Component {
            id: navbarButton
            StatusNavBarTabButton {
                id: navbar
                objectName: model.name + "-navbar"
                anchors.horizontalCenter: parent.horizontalCenter
                name: model.icon.length > 0? "" : model.name
                icon.name: model.icon
                icon.source: model.image
                tooltip.text: Utils.translatedSectionName(model.sectionType, model.name, (sectionType) => {
                    if (sectionType === Constants.appSection.homePage) {
                        return homePageShortcut.nativeText
                    }
                    return ""
                })
                checked: model.active

                readonly property bool displayCreateCommunityBadge: model.sectionType === Constants.appSection.communitiesPortal && !appMain.communitiesStore.createCommunityPopupSeen
                badge.value: model.notificationsCount
                badge.visible: {
                    if (model.sectionType === Constants.appSection.profile) {
                        if (contactsModelAdaptor.pendingReceivedRequestContacts.ModelCount.count > 0) // pending contact request
                            return true
                        if (!appMain.privacyStore.mnemonicBackedUp && !appMain.profileStore.userDeclinedBackupBanner) // seedphrase not backed up (removed)
                            return true
                        if (appMain.devicesStore.devicesModel.count - appMain.devicesStore.devicesModel.pairedCount > 0) // sync entries
                            return true
                        return false
                    }
                    if (displayCreateCommunityBadge) // create new community badge
                        return true
                    return model.hasNotification // Otherwise, use the value coming from the model
                }

                StatusNewItemGradient { id: newGradient }
                badge.gradient: displayCreateCommunityBadge ? newGradient : undefined // gradient has precedence over a simple color

                thirdpartyServicesEnabled: appMain.rootStore.thirdpartyServicesEnabled

                onClicked: {
                    if(model.sectionType === Constants.appSection.swap) {
                        popupRequestsHandler.swapModalHandler.launchSwap()
                    } else {
                        changeAppSectionBySectionId(model.id)
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent

        spacing: 0
        objectName: "mainRightView"

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

                isOnline: appMain.rootStore.isOnline
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
                    default:
                        return ""
                    }
                }
                isOnline: d.networkChecker.isOnline
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
                    default:
                        return ""
                    }
                }
                isOnline: d.networkChecker.isOnline
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
                    default:
                        return ""
                    }
                }
                isOnline: d.networkChecker.isOnline
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

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
                        for (let i = this.children.length - 1; i >= 0; i--) {
                            var obj = this.children[i]
                            if (obj && obj.sectionId && obj.sectionId === appMain.rootStore.activeSectionId) {
                                return i
                            }
                        }
                        // Should never be here, correct index must be returned from the for loop above
                        console.error("Wrong section type:", d.activeSectionType,
                                      "or section id: ", appMain.rootStore.activeSectionId)
                        return Constants.appViewStackIndex.community
                    case Constants.appSection.communitiesPortal:
                        return Constants.appViewStackIndex.communitiesPortal
                    case Constants.appSection.wallet:
                        return Constants.appViewStackIndex.wallet
                    case Constants.appSection.profile:
                        return Constants.appViewStackIndex.profile
                    case Constants.appSection.browser:
                        return Constants.appViewStackIndex.browser
                    case Constants.appSection.node:
                        return Constants.appViewStackIndex.node
                    case Constants.appSection.market:
                        return Constants.appViewStackIndex.market
                    case Constants.appSection.activityCenter:
                        return Constants.appViewStackIndex.activityCenter
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

                Loader {
                    id: homePageLoader
                    focus: active
                    active: appMain.featureFlagsStore.homePageEnabled && appView.currentIndex === Constants.appViewStackIndex.homePage

                    sourceComponent: HomePage {
                        id: homePage

                        objectName: "homeContainer"

                        HomePageAdaptor {
                            id: homePageAdaptor
                            readonly property bool sectionsLoaded: appMain.rootStore.sectionsLoaded

                            sectionsBaseModel: sectionsLoaded ? appMain.rootStore.sectionsModel : null
                            chatsBaseModel: sectionsLoaded ? appMain.rootChatStore.chatSectionModuleModel
                                                           : null
                            chatsSearchBaseModel: sectionsLoaded && !!rootStore.chatSearchModel ? rootStore.chatSearchModel : null
                            walletsBaseModel: sectionsLoaded ? WalletStores.RootStore.accounts : null
                            dappsBaseModel: dAppsServiceLoader.active && dAppsServiceLoader.item ? dAppsServiceLoader.item.dappsModel : null

                            showEnabledSectionsOnly: true
                            marketEnabled: appMain.featureFlagsStore.marketEnabled
                            browserEnabled: d.isBrowserEnabled

                            syncingBadgeCount: appMain.devicesStore.devicesModel.count - appMain.devicesStore.devicesModel.pairedCount
                            messagingBadgeCount: contactsModelAdaptor.pendingReceivedRequestContacts.count
                            showBackUpSeed: !appMain.privacyStore.mnemonicBackedUp
                            backUpSeedBadgeCount: appMain.profileStore.userDeclinedBackupBanner ? 0 : showBackUpSeed
                            keycardEnabled: appMain.featureFlagsStore.keycardEnabled

                            searchPhrase: homePage.searchPhrase

                            profileId: appMain.profileStore.pubKey

                            // no automatic propagation to QtObject, needs to be specified explicitely
                            Theme.style: appMain.Theme.style
                        }

                        homePageEntriesModel: homePageAdaptor.homePageEntriesModel
                        sectionsModel: homePageAdaptor.sectionsModel
                        pinnedModel: homePageAdaptor.pinnedModel

                        profileStore: appMain.profileStore

                        getEmojiHashFn: appMain.utilsStore.getEmojiHash
                        getLinkToProfileFn: appMain.contactsStore.getLinkToProfile

                        useNewDockIcons: false

                        onItemActivated: function(key, sectionType, itemId) {
                            homePageAdaptor.setTimestamp(key, new Date().valueOf())

                            if (sectionType === -1) { // search
                                const [sectionId, chatId] = key.split(";")
                                return rootStore.setActiveSectionChat(sectionId, chatId)
                            } else if (sectionType === Constants.appSection.profile) {
                                if (itemId == Constants.settingsSubsection.backUpSeed) {
                                    return Global.openBackUpSeedPopup()
                                } else if (itemId == Constants.settingsSubsection.signout) {
                                    return Global.quitAppRequested()
                                }
                            }

                            let subsection = itemId
                            let subSubsection = -1
                            let data = {}

                            if (sectionType === Constants.appSection.wallet && !!itemId) {
                                subsection = WalletLayout.LeftPanelSelection.Address
                                subSubsection = WalletLayout.RightPanelSelection.Assets
                                data = { address: itemId }
                            }

                            globalConns.onAppSectionBySectionTypeChanged(sectionType, subsection, subSubsection, data)
                        }
                        onItemPinRequested: function(key, pin) {
                            homePageAdaptor.setPinned(key, pin)
                            if (pin)
                                homePageAdaptor.setTimestamp(key, new Date().valueOf()) // update the timestamp so that the pinned dock items are sorted by their recency
                        }
                        onDappDisconnectRequested: function(dappUrl) {
                            dappMetrics.logNavigationEvent(DAppsMetrics.DAppsNavigationAction.DAppDisconnectInitiated)
                            dAppsServiceLoader.dappDisconnectRequested(dappUrl)
                        }

                        onSetCurrentUserStatusRequested: (status) => appMain.rootStore.setCurrentUserStatus(status)
                        onViewProfileRequested: (pubKey) => Global.openProfilePopup(pubKey)
                    }
                }

                Loader {
                    active: false
                    sourceComponent: {
                        if (appMain.rootChatStore.chatsLoadingFailed) {
                            return errorStateComponent
                        }
                        if (appMain.rootStore.sectionsLoaded) {
                            return personalChatLayoutComponent
                        }
                        return loadingStateComponent
                    }

                    // Do not unload section data from the memory in order not
                    // to reset scroll, not send text input and etc during the
                    // sections switching
                    Binding on active {
                        when: appView.currentIndex === Constants.appViewStackIndex.chat
                        value: true
                        restoreMode: Binding.RestoreNone
                    }

                    Component {
                        id: loadingStateComponent
                        Item {
                            anchors.fill: parent

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                StatusBaseText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("Loading sections...")
                                }
                                LoadingAnimation { anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    Component {
                        id: errorStateComponent
                        Item {
                            anchors.fill: parent
                            StatusBaseText {
                                text: qsTr("Error loading chats, try closing the app and restarting")
                                anchors.centerIn: parent
                            }
                        }
                    }

                    Component {
                        id: personalChatLayoutComponent

                        ChatLayout {
                            id: chatLayoutContainer

                            showUsersList: appMain.accountSettingsStore.showUsersList
                            onShowUsersListRequested:
                                show => appMain.accountSettingsStore.setShowUsersList(show)

                            isChatView: true
                            navBar: appMain.navBar
                            rootStore: ChatStores.RootStore {
                                contactsStore: appMain.contactsStore
                                currencyStore: appMain.currencyStore
                                communityTokensStore: appMain.communityTokensStore
                                openCreateChat: createChatView.opened
                                networkConnectionStore: appMain.networkConnectionStore
                                isChatSectionModule: true
                            }
                            createChatPropertiesStore: appMain.createChatPropertiesStore
                            tokensStore: appMain.tokensStore
                            transactionStore: appMain.transactionStore
                            walletAssetsStore: appMain.walletAssetsStore
                            currencyStore: appMain.currencyStore
                            networksStore: appMain.networksStore
                            advancedStore: appMain.advancedStore
                            emojiPopup: statusEmojiPopup.item
                            stickersPopup: statusStickersPopupLoader.item
                            sendViaPersonalChatEnabled: featureFlagsStore.sendViaPersonalChatEnabled
                            disabledTooltipText: !appMain.networkConnectionStore.sendBuyBridgeEnabled ?
                                                     appMain.networkConnectionStore.sendBuyBridgeToolTipText : ""
                            paymentRequestFeatureEnabled: featureFlagsStore.paymentRequestEnabled

                            mutualContactsModel: contactsModelAdaptor.mutualContacts

                            // Unfurling related data:
                            gifUnfurlingEnabled: appMain.sharedRootStore.gifUnfurlingEnabled
                            neverAskAboutUnfurlingAgain: appMain.sharedRootStore.neverAskAboutUnfurlingAgain

                            // Users related data
                            usersModel: rootStore.usersStore.usersModel

                            // Contacts related data:
                            myPublicKey: appMain.contactsStore.myPublicKey

                            // Navigation: Temporary solution that keeps ui navigation state when in-app links
                            // are triggered and allow messaging details navigation in portrait
                            navToMsgDetails: appMain.rootStore.navToMsgDetails

                            onProfileButtonClicked: {
                                Global.changeAppSectionBySectionType(Constants.appSection.profile);
                            }

                            onOpenAppSearch: {
                                appSearch.openSearchPopup()
                            }

                            onBuyStickerPackRequested: popupRequestsHandler.sendModalHandler.buyStickerPack(packId, price)
                            onTokenPaymentRequested: popupRequestsHandler.sendModalHandler.openTokenPaymentRequest(recipientAddress, tokenKey, rawAmount)

                            // Unfurling related requests:
                            onSetNeverAskAboutUnfurlingAgain: appMain.sharedRootStore.setNeverAskAboutUnfurlingAgain(neverAskAgain)

                            onOpenGifPopupRequest: popupRequestsHandler.statusGifPopupHandler.openGifs(params, cbOnGifSelected, cbOnClose)

                            // Edit group chat members signals:
                            onGroupMembersUpdateRequested: rootStore.usersStore.groupMembersUpdateRequested(membersPubKeysList)

                            // Contacts related requests:
                            onChangeContactNicknameRequest: appMain.contactsStore.changeContactNickname(pubKey, nickname, displayName, isEdit)
                            onRemoveTrustStatusRequest: appMain.contactsStore.removeTrustStatus(pubKey)
                            onDismissContactRequest: appMain.contactsStore.dismissContactRequest(chatId, contactRequestId)
                            onAcceptContactRequest: appMain.contactsStore.acceptContactRequest(chatId, contactRequestId)

                            // Navigation: Temporary solution that keeps ui navigation state when in-app links
                            // are triggered and allow messaging details navigation in portrait
                            onNavToMsgDetailsRequested: navigate => appMain.rootStore.setNavToMsgDetailsFlag(navigate)
                        }
                    }
                }

                Loader {
                    active: appView.currentIndex === Constants.appViewStackIndex.communitiesPortal
                    sourceComponent: CommunitiesPortalLayout {
                        anchors.fill: parent
                        createCommunityEnabled: !SQUtils.Utils.isMobile
                        navBar: appMain.navBar
                        communitiesStore: appMain.communitiesStore
                        assetsModel: appMain.rootStore.globalAssetsModel
                        collectiblesModel: appMain.rootStore.globalCollectiblesModel
                        createCommunityBadgeVisible: !appMain.communitiesStore.createCommunityPopupSeen
                    }
                }

                Loader {
                    active: appView.currentIndex === Constants.appViewStackIndex.wallet
                    sourceComponent: appMain.rootStore.thirdpartyServicesEnabled ? walletLayout: walletPrivacyWall

                    Component {
                        id: walletPrivacyWall

                        WalletPrivacyWall {
                            navBar: appMain.navBar

                            onOpenThirdpartyServicesInfoPopupRequested: popupRequestsHandler.thirdpartyServicesPopupHandler.openPopup()
                            onOpenDiscussPageRequested: Global.requestOpenLink(Constants.statusDiscussPageUrl)
                        }
                    }

                    Component {
                        id: walletLayout

                        WalletLayout {
                            objectName: "walletLayoutReal"
                            navBar: appMain.navBar
                            walletRootStore: WalletStores.RootStore
                            sharedRootStore: appMain.sharedRootStore
                            store: appMain.rootStore
                            contactsStore: appMain.contactsStore
                            communitiesStore: appMain.communitiesStore
                            transactionStore: appMain.transactionStore
                            emojiPopup: statusEmojiPopup.item
                            networkConnectionStore: appMain.networkConnectionStore
                            networksStore: appMain.networksStore
                            appMainVisible: appMain.visible
                            swapEnabled: featureFlagsStore.swapEnabled
                            dAppsVisible: dAppsServiceLoader.item ? dAppsServiceLoader.item.serviceAvailableToCurrentAddress : false
                            dAppsEnabled: dAppsServiceLoader.item ? dAppsServiceLoader.item.isServiceOnline : false
                            dAppsModel: dAppsServiceLoader.item ? dAppsServiceLoader.item.dappsModel : null
                            isKeycardEnabled: featureFlagsStore.keycardEnabled
                            onDappListRequested: dappMetrics.logNavigationEvent(DAppsMetrics.DAppsNavigationAction.DAppListOpened)
                            onDappConnectRequested: {
                                dappMetrics.logNavigationEvent(DAppsMetrics.DAppsNavigationAction.DAppConnectInitiated)
                                dAppsServiceLoader.dappConnectRequested()
                            }
                            onDappDisconnectRequested: function(dappUrl) {
                                dappMetrics.logNavigationEvent(DAppsMetrics.DAppsNavigationAction.DAppDisconnectInitiated)
                                dAppsServiceLoader.dappDisconnectRequested(dappUrl)
                            }
                            onSendTokenRequested: (senderAddress, gorupKey, tokenType) => popupRequestsHandler.sendModalHandler.sendToken(senderAddress, gorupKey, tokenType)
                            onBridgeTokenRequested: (tokenId, tokenType) => popupRequestsHandler.sendModalHandler.bridgeToken(tokenId, tokenType)
                            onOpenSwapModalRequested: (swapFormData) => popupRequestsHandler.swapModalHandler.launchSwapSpecific(swapFormData)
                        }
                    }
                    onLoaded: {
                        item.resetView()
                    }
                }

                Loader {
                    id: browserLayoutContainer

                    Binding on active {
                        when: appView.currentIndex === Constants.appViewStackIndex.browser
                        value: d.isBrowserEnabled && !localAppSettings.testEnvironment
                        restoreMode: Binding.RestoreNone
                    }

                    sourceComponent: appMain.rootStore.thirdpartyServicesEnabled ? browserLayout: browserPrivacyWall

                    Component {
                        id: browserPrivacyWall

                        BrowserPrivacyWall {
                            navBar: appMain.navBar

                            onOpenThirdpartyServicesInfoPopupRequested: popupRequestsHandler.thirdpartyServicesPopupHandler.openPopup()
                            onOpenDiscussPageRequested: Global.openLinkWithConfirmation(
                                                            Constants.statusDiscussPageUrl,
                                                            SQUtils.StringUtils.extractDomainFromLink(Constants.statusDiscussPageUrl))
                        }
                    }

                    Component {
                        id: browserLayout

                        BrowserLayout {
                            isMobile: SQUtils.Utils.isMobile
                            userUID: appMain.profileStore.pubKey
                            thirdpartyServicesEnabled: appMain.rootStore.thirdpartyServicesEnabled
                            navBar: appMain.navBar
                            bookmarksStore: BrowserStores.BookmarksStore {}
                            downloadsStore: BrowserStores.DownloadsStore {}
                            browserRootStore: BrowserStores.BrowserRootStore {}
                            browserWalletStore: BrowserStores.BrowserWalletStore {}
                            browserActivityStore: BrowserStores.BrowserActivityStore {
                                browserWalletStore: browserLayout.browserWalletStore
                            }
                            currencyStore: appMain.currencyStore
                            networksStore: appMain.networksStore
                            connectorController: WalletStores.RootStore.dappsConnectorController
                            isDebugEnabled: appMain.advancedStore.isDebugEnabled

                            transactionStore: appMain.transactionStore
                            onSendToRecipientRequested: (address) => popupRequestsHandler.sendModalHandler.sendToRecipient(address)
                        }
                    }
                }

                Loader {
                    id: profileLoader

                    property int settingsSubsection: Constants.settingsSubsection.profile
                    onSettingsSubsectionChanged: {
                        item.settingsSubsection = settingsSubsection
                    }
                    property int settingsSubSubsection: -1
                    onSettingsSubSubsectionChanged: {
                        item.settingsSubsection = settingsSubsection
                        item.settingsSubSubsection = settingsSubSubsection
                    }

                    active: appView.currentIndex === Constants.appViewStackIndex.profile
                    sourceComponent: ProfileLayout {
                        navBar: appMain.navBar
                        isProduction: appMain.rootStore.isProduction

                        sharedRootStore: appMain.sharedRootStore
                        utilsStore: appMain.utilsStore
                        aboutStore: appMain.aboutStore
                        profileStore: appMain.profileStore
                        contactsStore: appMain.contactsStore
                        devicesStore: appMain.devicesStore
                        advancedStore: appMain.advancedStore
                        privacyStore: appMain.privacyStore
                        notificationsStore: appMain.notificationsStore
                        languageStore: appMain.languageStore
                        keycardStore: appMain.keycardStore
                        walletStore: appMain.walletProfileStore
                        messagingSettingsStore: appMain.messagingSettingsStore
                        ensUsernamesStore: appMain.ensUsernamesStore
                        globalStore: appMain.rootStore
                        communitiesStore: appMain.communitiesStore
                        networkConnectionStore: appMain.networkConnectionStore
                        tokensStore: appMain.tokensStore
                        walletAssetsStore: appMain.walletAssetsStore
                        collectiblesStore: appMain.walletCollectiblesStore
                        currencyStore: appMain.currencyStore
                        networksStore: appMain.networksStore
                        messagingRootStore: appMain.messagingRootStore

                        isCentralizedMetricsEnabled: appMain.isCentralizedMetricsEnabled
                        keychain: appMain.keychain
                        emojiPopup: statusEmojiPopup.item

                        mutualContactsModel: contactsModelAdaptor.mutualContacts
                        blockedContactsModel: contactsModelAdaptor.blockedContacts
                        pendingContactsModel: contactsModelAdaptor.pendingContacts
                        pendingReceivedContactsCount: contactsModelAdaptor.pendingReceivedRequestContacts.count
                        dismissedReceivedRequestContactsModel: contactsModelAdaptor.dimissedReceivedRequestContacts
                        isKeycardEnabled: featureFlagsStore.keycardEnabled
                        isBrowserEnabled: featureFlagsStore.browserEnabled
                        privacyModeFeatureEnabled: featureFlagsStore.privacyModeFeatureEnabled
                        minimizeOnCloseOptionVisible: appMain.systemTrayIconAvailable

                        theme: appMainLocalSettings.theme
                        fontSize: appMainLocalSettings.fontSize
                        paddingFactor: appMainLocalSettings.paddingFactor

                        whitelistedDomainsModel: appMainLocalSettings.whitelistedUnfurledDomains

                        onAddressWasShownRequested: (address) => WalletStores.RootStore.addressWasShown(address)
                        onSettingsSubsectionChanged: profileLoader.settingsSubsection = settingsSubsection
                        onConnectUsernameRequested: (ensName, ownerAddress) => popupRequestsHandler.sendModalHandler.connectUsername(ensName, ownerAddress)
                        onRegisterUsernameRequested: (ensName, chainId) => popupRequestsHandler.sendModalHandler.registerUsername(ensName, chainId)
                        onReleaseUsernameRequested: (ensName, senderAddress, chainId) => popupRequestsHandler.sendModalHandler.releaseUsername(ensName, senderAddress, chainId)

                        onThemeChangeRequested: function(theme) {
                            appMainLocalSettings.theme = theme
                            ThemeUtils.setTheme(appMain.Window.window, theme)
                        }
                        onFontSizeChangeRequested: function(fontSize) {
                            appMainLocalSettings.fontSize = fontSize
                            ThemeUtils.setFontSize(appMain.Window.window, fontSize)
                        }
                        onPaddingFactorChangeRequested: function(paddingFactor) {
                            appMainLocalSettings.paddingFactor = paddingFactor
                            ThemeUtils.setPaddingFactor(appMain.Window.window, paddingFactor)
                        }
                        // Communities related settings view:
                        onLeaveCommunityRequest: appMain.communitiesStore.leaveCommunity(communityId)
                        onSetCommunityMutedRequest: appMain.communitiesStore.setCommunityMuted(communityId, mutedType)
                        onInviteFriends: Global.openInviteFriendsToCommunityPopup(communityData,
                                                                                  appMain.communitiesStore.communitiesProfileModule,
                                                                                  null)
                        onOpenThirdpartyServicesInfoPopupRequested: popupRequestsHandler.thirdpartyServicesPopupHandler.openPopup()
                        onOpenDiscussPageRequested: Global.requestOpenLink(Constants.statusDiscussPageUrl)

                        onRemoveWhitelistedDomain: function(index) {
                            // in order to notify changes in this model, we need to re assign to this model
                            const domainRemoved = appMainLocalSettings.whitelistedUnfurledDomains[index]
                            const whitelistedUnfurledDomainsCpy = appMainLocalSettings.whitelistedUnfurledDomains.slice()
                            whitelistedUnfurledDomainsCpy.splice(index, 1)
                            appMainLocalSettings.whitelistedUnfurledDomains = whitelistedUnfurledDomainsCpy
                            Global.displaySuccessToastMessage(qsTr("%1 was removed from your trusted sites.").arg(domainRemoved))
                        }
                    }
                    onLoaded: {
                        item.settingsSubsection = profileLoader.settingsSubsection
                        item.settingsSubSubsection = profileLoader.settingsSubSubsection
                    }
                }

                Loader {
                    active: appView.currentIndex === Constants.appViewStackIndex.node
                    sourceComponent: NodeLayout {
                        navBar: appMain.navBar
                    }
                }

                Loader {
                    active: appView.currentIndex === Constants.appViewStackIndex.market
                    sourceComponent: appMain.rootStore.thirdpartyServicesEnabled ? marketLayout : marketPrivacyWall

                    Component {
                        id: marketPrivacyWall

                        MarketPrivacyWall {
                            navBar: appMain.navBar

                            onOpenThirdpartyServicesInfoPopupRequested: popupRequestsHandler.thirdpartyServicesPopupHandler.openPopup()
                            onOpenDiscussPageRequested: Global.requestOpenLink(Constants.statusDiscussPageUrl)
                        }
                    }

                    Component {
                        id: marketLayout

                        MarketLayout {
                            objectName: "marketLayout"
                            navBar: appMain.navBar

                            tokensModel: appMain.marketStore.marketLeaderboardModel
                            totalTokensCount: appMain.marketStore.totalLeaderboardCount
                            loading: appMain.marketStore.marketLeaderboardLoading
                            swapEnabled: featureFlagsStore.swapEnabled
                            currencySymbol: {
                                const symbol = SQUtils.ModelUtils.getByKey(
                                                 appMain.currencyStore.currenciesModel,
                                                 "shortName",
                                                 appMain.currencyStore.currentCurrency,
                                                 "symbol")
                                return !!symbol ? symbol: ""
                            }
                            fnFormatCurrencyAmount: function(amount, options) {
                                return appMain.currencyStore.formatCurrencyAmount(amount, appMain.currencyStore.currentCurrency, options)
                            }
                            currentPage: appMain.marketStore.currentPage
                            onRequestLaunchSwap: popupRequestsHandler.swapModalHandler.launchSwap()
                            onFetchMarketTokens: (pageNumber, pageSize) => {
                                                     appMain.marketStore.requestMarketTokenPage(pageNumber, pageSize)
                                                 }
                        }
                    }

                    onActiveChanged: {
                        if(!active && appMain.rootStore.thirdpartyServicesEnabled) {
                            appMain.marketStore.unsubscribeFromUpdates()
                        }
                    }
                    onLoaded: item.resetView()
                }

                Loader {
                    active: appView.currentIndex === Constants.appViewStackIndex.activityCenter
                    sourceComponent: ActivityCenterLayout {
                        id: activityCenterPopup

                        objectName: "activityCenterLayout"
                        navBar: appMain.navBar

                        contactsStore: appMain.contactsStore
                        store: ChatStores.RootStore {
                            contactsStore: appMain.contactsStore
                            currencyStore: appMain.currencyStore
                            communityTokensStore: appMain.communityTokensStore
                            openCreateChat: createChatView.opened
                            walletStore: WalletStores.RootStore
                            isChatSectionModule: true
                        }
                        activityCenterStore: appMain.activityCenterStore
                        privacyStore: appMain.privacyStore
                        notificationsStore: appMain.notificationsStore
                        messagingRootStore: appMain.messagingRootStore

                        onNavToMsgDetailsRequested: navigate => appMain.rootStore.setNavToMsgDetailsFlag(navigate)
                    }
                }

                Repeater {
                    model: SortFilterProxyModel {
                        sourceModel: appMain.rootStore.sectionsModel
                        filters: ValueFilter {
                            roleName: "sectionType"
                            value: Constants.appSection.community
                        }
                    }

                    delegate: Loader {
                        readonly property string sectionId: model.id

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

                        sourceComponent: ChatLayout {
                            id: chatLayoutComponent

                            readonly property bool isManageCommunityEnabledInAdvanced: appMain.advancedStore.isManageCommunityOnTestModeEnabled

                            Connections {
                                target: Global
                                function onSwitchToCommunitySettings(communityId: string) {
                                    if (communityId !== model.id)
                                        return
                                    chatLayoutComponent.currentIndex = 1 // Settings
                                }
                                function onSwitchToCommunityChannelsView(communityId: string) {
                                    if (communityId !== model.id)
                                        return
                                    chatLayoutComponent.currentIndex = 0
                                }
                            }

                            showUsersList: appMain.accountSettingsStore.showUsersList
                            onShowUsersListRequested:
                                show => appMain.accountSettingsStore.setShowUsersList(show)

                            isChatView: false // This will be a community view
                            navBar: appMain.navBar
                            emojiPopup: statusEmojiPopup.item
                            stickersPopup: statusStickersPopupLoader.item
                            sectionItemModel: model
                            createChatPropertiesStore: appMain.createChatPropertiesStore
                            communitiesStore: appMain.communitiesStore
                            communitySettingsDisabled: !chatLayoutComponent.isManageCommunityEnabledInAdvanced &&
                                                       (appMain.rootStore.isProduction && appMain.networksStore.areTestNetworksEnabled)

                            newCommnityStore: appMain.messagingRootStore.createCommunityRootStore(this, model.id)
                            rootStore: ChatStores.RootStore {
                                contactsStore: appMain.contactsStore
                                currencyStore: appMain.currencyStore
                                communityTokensStore: appMain.communityTokensStore
                                openCreateChat: createChatView.opened
                                isChatSectionModule: false
                                communityId: model.id
                            }
                            tokensStore: appMain.tokensStore
                            transactionStore: appMain.transactionStore
                            walletAssetsStore: appMain.walletAssetsStore
                            currencyStore: appMain.currencyStore
                            networksStore: appMain.networksStore
                            advancedStore: appMain.advancedStore
                            paymentRequestFeatureEnabled: featureFlagsStore.paymentRequestEnabled

                            mutualContactsModel: contactsModelAdaptor.mutualContacts

                            // Unfurling related data:
                            gifUnfurlingEnabled: appMain.sharedRootStore.gifUnfurlingEnabled
                            neverAskAboutUnfurlingAgain: appMain.sharedRootStore.neverAskAboutUnfurlingAgain

                            usersModel: rootStore.usersStore.usersModel

                            // Contacts related data:
                            myPublicKey: appMain.contactsStore.myPublicKey

                            // Navigation:
                            navToMsgDetails: appMain.rootStore.navToMsgDetails

                            onProfileButtonClicked: {
                                Global.changeAppSectionBySectionType(Constants.appSection.profile);
                            }

                            onOpenAppSearch: {
                                appSearch.openSearchPopup()
                            }

                            onBuyStickerPackRequested: popupRequestsHandler.sendModalHandler.buyStickerPack(packId, price)
                            onTokenPaymentRequested: popupRequestsHandler.sendModalHandler.openTokenPaymentRequest(recipientAddress, tokenKey, rawAmount)

                            // Unfurling related requests:
                            onSetNeverAskAboutUnfurlingAgain: appMain.sharedRootStore.setNeverAskAboutUnfurlingAgain(neverAskAgain)

                            onOpenGifPopupRequest: popupRequestsHandler.statusGifPopupHandler.openGifs(params, cbOnGifSelected, cbOnClose)

                            // Contacts related requests:
                            onChangeContactNicknameRequest: appMain.contactsStore.changeContactNickname(pubKey, nickname, displayName, isEdit)
                            onRemoveTrustStatusRequest: appMain.contactsStore.removeTrustStatus(pubKey)
                            onDismissContactRequest: appMain.contactsStore.dismissContactRequest(chatId, contactRequestId)
                            onAcceptContactRequest: appMain.contactsStore.acceptContactRequest(chatId, contactRequestId)

                            // Navigation:
                            onNavToMsgDetailsRequested: navigate => appMain.rootStore.setNavToMsgDetailsFlag(navigate)
                        }
                    }
                }
            }

            Loader {
                id: createChatView

                readonly property bool isPortraitMode: appMain.width < ThemeUtils.portraitBreakpoint.width
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
                anchors.left: isPortraitMode ? parent.left : undefined

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

                    emojiPopup: statusEmojiPopup.item
                    stickersPopup: statusStickersPopupLoader.item
                }
            }
        }
    } // ColumnLayout

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
        sequence: StandardKey.Find
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

            onClosed: {
                addEditSavedAddress.close()
            }
        }

        Connections {
            target: WalletStores.RootStore

            function onSavedAddressAddedOrUpdated(added: bool, name: string, address: string, errorMsg: string) {
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
    }

    Loader {
        id: deleteSavedAddress

        active: false

        property var params

        function open(params = {}) {
            deleteSavedAddress.params = params
            deleteSavedAddress.active = true
        }

        function close() {
            deleteSavedAddress.active = false
        }

        onLoaded: {
            deleteSavedAddress.item.address = deleteSavedAddress.params.address?? ""
            deleteSavedAddress.item.ens = deleteSavedAddress.params.ens?? ""
            deleteSavedAddress.item.name = deleteSavedAddress.params.name?? ""
            deleteSavedAddress.item.colorId = deleteSavedAddress.params.colorId?? "blue"

            deleteSavedAddress.item.open()
        }

        sourceComponent: WalletPopups.RemoveSavedAddressPopup {
            onClosed: {
                deleteSavedAddress.close()
            }

            onRemoveSavedAddress: {
                WalletStores.RootStore.deleteSavedAddress(address)
                close()
            }
        }

        Connections {
            target: WalletStores.RootStore

            function onSavedAddressDeleted(name: string, address: string, errorMsg: string) {
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
            contactsStore: appMain.contactsStore
            networksStore: appMain.networksStore

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

    DAppsMetrics {
        id: dappMetrics
        metricsStore: SharedStores.MetricsStore {}
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

                onDisconnectRequested: (connectionId) => dAppsService.disconnectDapp(connectionId)
                onPairingRequested: (uri) => dAppsService.pair(uri)
                onPairingValidationRequested: (uri) => dAppsService.validatePairingUri(uri)
                onConnectionAccepted: (pairingId, chainIds, selectedAccount) => dAppsService.approvePairSession(pairingId, chainIds, selectedAccount)
                onConnectionDeclined: (pairingId) => dAppsService.rejectPairSession(pairingId)
                onSignRequestAccepted: (connectionId, requestId) => dAppsService.sign(connectionId, requestId)
                onSignRequestRejected: (connectionId, requestId) => dAppsService.rejectSign(connectionId, requestId, false /*hasError*/)
                onSignRequestIsLive: (connectionId, requestId) => dAppsService.signRequestIsLive(connectionId, requestId)
                onPairWithConnectorRequested: (connectorId) => {
                    dappMetrics.logNavigationEvent(DAppsMetrics.DAppsNavigationAction.DAppPairInitiated, connectorId)
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
                    dappsMetrics: dappMetrics
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
                    wcSdk: WalletConnectSDK {
                        enabled: featureFlagsStore.dappsEnabled && WalletStores.RootStore.walletSectionInst.walletReady
                        userUID: appMain.profileStore.pubKey
                        projectId: WalletStores.RootStore.appSettings.walletConnectProjectID
                    }
                    bcSdk: DappsConnectorSDK {
                        enabled: featureFlagsStore.connectorEnabled && WalletStores.RootStore.walletSectionInst.walletReady
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
            onConnectDApp: (dappChains, dappUrl, dappName, dappIcon, connectorIcon, pairingId) => {
                dappsWorkflow.connectDApp(dappChains, dappUrl, dappName, dappIcon, connectorIcon, pairingId)
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
