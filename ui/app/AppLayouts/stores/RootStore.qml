import QtQuick

import utils

import StatusQ
import StatusQ.Core.Theme

import SortFilterProxyModel
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStore
import AppLayouts.stores.Messaging as MessagingStores

// WIP: Previous reorganization step before refactoring `RootStore`
QtObject {
    id: root

    required property Keychain keychain
    required property ThemePalette palette

    // Global properties that have to remain on `RootStore` (the module instances must be private properties and just used to initialize the
    // rest and specific stores
    readonly property bool isProduction: production
    readonly property bool isOnline: internal.mainModuleInst.isOnline
    readonly property var sectionsModel: internal.mainModuleInst.sectionsModel
    readonly property bool sectionsLoaded: internal.mainModuleInst && internal.mainModuleInst.sectionsLoaded
    readonly property string activeSectionId: internal.mainModuleInst.activeSection.id
    readonly property int activeSectionType: internal.mainModuleInst.activeSection.sectionType
    property bool localBackupEnabled: false

    // TODO: Once RootStore initializes all stores, initialize this property here instead.
    // For now, it's set during initialization in AppMain.qml.
    property bool thirdpartyServicesEnabled

    // TEMPORARY: Workaround to persist UI state whenever the user navigates to
    // chat/channel detail sections from in-links (i.e. not directly via the nav bar).
    // This parameter is used to store the navigation intent so that the target component
    // can react and move to the corresponding detail view.
    //
    // This workaround is required due to the current Nim-based navigation architecture,
    // where UI-driven actions are intertwined in a call chain qml → nim → qml, instead of
    // being handled locally in the UI layer.
    readonly property bool navToMsgDetails: internal.forceNavToMsgDetails
    function setNavToMsgDetailsFlag(navigate) {
        internal.forceNavToMsgDetails = navigate
    }

    // Here define the needed properties that access to `Context Properties`:
    readonly property QtObject _internal: QtObject{
        id: internal // Rename to `d` when cleanup done

        readonly property var mainModuleInst: mainModule
        readonly property var appSearchModuleInst: internal.mainModuleInst.appSearchModule

        // TEMPORARY: Internal flag used to trigger navigation into messaging details.
        property bool forceNavToMsgDetails: false
    }

    // Here there should be all the ContextSpecificRootStore objects creation
    readonly property MessagingStores.MessagingRootStore messagingRootStore: MessagingStores.MessagingRootStore {}
    readonly property ProfileStores.ProfileSectionStore profileSectionStore: ProfileStores.ProfileSectionStore {
        localBackupEnabled: root.localBackupEnabled
        palette: root.palette
    }

    readonly property AccountSettingsStore accountSettingsStore: AccountSettingsStore {}
    readonly property ContactsStore contactsStore: ContactsStore {}
    readonly property ActivityCenterStore activityCenterStore: ActivityCenterStore {}

    // readonly property ChatStores.RootStore rootChatStore: ChatStores.RootStore { ... }
    // readonly property SharedStores.NetworkConnectionStore networkConnectionStore: SharedStores.NetworkConnectionStore { ... }
    // + all the rest of stores now created on `AppMain`

    signal activeSectionChanged()

    // Here the definition of global functions and connections
    function windowActivated() {
        internal.mainModuleInst.windowActivated()
    }

    function windowDeactivated() {
        internal.mainModuleInst.windowDeactivated()
    }

    function setActiveSectionBySectionType(sectionType) {
        if(!internal.mainModuleInst)
            return
        internal.mainModuleInst.setActiveSectionBySectionType(sectionType)
    }

    function setActiveSectionById(sectionId) {
        if(!internal.mainModuleInst)
            return
        internal.mainModuleInst.setActiveSectionById(sectionId)
    }

    function activateStatusDeepLink(link) {
        if(!internal.mainModuleInst)
            return
        internal.mainModuleInst.activateStatusDeepLink(link)
    }

    function setNthEnabledSectionActive(nthSection) {
        if(!internal.mainModuleInst)
            return
        internal.mainModuleInst.setNthEnabledSectionActive(nthSection)
    }

    readonly property Connections _mainModuleConnections: Connections {
        target: internal.mainModuleInst

        function onActiveSectionChanged() {
            root.activeSectionChanged()
        }
    }
    // End of RootStore related stuff (Just the above code should be part of `RootStore`)

    // Notifications related properties and functions that shall be moved to `NotificationsRootStore`
    readonly property var ephemeralNotificationModel: internal.mainModuleInst.ephemeralNotificationModel

    signal showEphemeralNewsNotification(string newsTitle, string notificationId)
    signal playNotificationSound()
    signal mailserverWorking()
    signal mailserverNotWorking()

    function displayEphemeralNotification(title: string, subTitle: string,
                                          image: string, icon: string,
                                          iconColor: string, loading: bool,
                                          ephNotifType: int, actionType: int,
                                          actionData: string, url: string) {
        internal.mainModuleInst.displayEphemeralNotification(title, subTitle,
                                                             image, icon,
                                                             iconColor, loading,
                                                             ephNotifType, actionType,
                                                             actionData, url)
    }

    function ephemeralNotificationClicked(timestamp) {
        internal.mainModuleInst.ephemeralNotificationClicked(timestamp)
    }

    function removeEphemeralNotification(timestamp) {
        internal.mainModuleInst.removeEphemeralNotification(timestamp)
    }

    readonly property Connections _notificationsRelatedMainModuleConnections: Connections {
        target: internal.mainModuleInst

        function onNewsFeedEphemeralNotification(newsTitle: string, notificationId: string) {
            root.showEphemeralNewsNotification(newsTitle, notificationId)
        }

        function onPlayNotificationSound() {
            root.playNotificationSound()
        }

        function onMailserverWorking() {
            root.mailserverWorking()
        }

        function onMailserverNotWorking() {
            root.mailserverNotWorking()
        }
    }
    // End of Notifications related stuff

    // Settings related properties and functions that shall be moved to `SettingsRootStore`
    property real volume: !!appSettings ? appSettings.volume * 0.01 : 0.5
    property bool notificationSoundsEnabled: !!appSettings ? appSettings.notificationSoundsEnabled : true

    readonly property bool openLinksInStatus: localAccountSensitiveSettings.openLinksInStatus

    readonly property QtObject _d: QtObject {
        id: d

        readonly property var userProfileInst: userProfile
        readonly property Connections _settingRelatedMainModuleConnections: Connections {
            target: internal.mainModuleInst

            function onResolvedENS(resolvedPubKey, resolvedAddress, uuid) {
                root.ensNameResolved(resolvedPubKey, resolvedAddress, uuid)
            }

            function onOpenUrl(url) {
                root.openUrl(url)
            }

            function onWcLinkActivated(url) {
                root.wcLinkActivated(url)
            }

            function onDisplayUserProfile(publicKey: string) {
                root.displayUserProfile(publicKey)
            }

            function onShowToastPairingFallbackCompleted() {
                root.showToastPairingFallbackCompleted()
            }
        }
    }

    function setCurrentUserStatus(newStatus) {
        if (d.userProfileInst && d.userProfileInst.currentUserStatus !== newStatus) {
            internal.mainModuleInst.setCurrentUserStatus(newStatus)
        }
    }

    function resolveENS(value, uuid = "") {
        internal.mainModuleInst.resolveENS(value, uuid)
    }

    signal ensNameResolved(string resolvedPubKey, string resolvedAddress, string uuid)
    signal openUrl(string link)
    signal wcLinkActivated(string link)
    signal displayUserProfile(string publicKey)
    signal showToastPairingFallbackCompleted()
    // End of Settings related stuff

    // Onboarding related properties and functions that shall be moved to `OnboardingRootStore`
    readonly property int loginType: getLoginType()
    function getLoginType() {
        if(!d.userProfileInst)
            return Constants.LoginType.Password

        if(d.userProfileInst.usingBiometricLogin)
            return Constants.LoginType.Biometrics
        if(d.userProfileInst.isKeycardUser)
            return Constants.LoginType.Keycard
        return Constants.LoginType.Password
    }
    // End of Onboarding related stuff

    // Chat related properties and functions that shall be moved to `ChatRootStore`
    property AppSearchStore appSearchStore: AppSearchStore {
        appSearchModule: internal.appSearchModuleInst
    }
    readonly property var chatSearchModel: internal.appSearchModuleInst.chatSearchModel

    function setActiveSectionChat(sectionId, chatId) {
        internal.mainModuleInst.switchTo(sectionId, chatId)
    }
    // End of Chat related stuff

    // Communities related properties and functions that shall be moved to `CommunitiesRootStore`
    property var communitiesModuleInst: communitiesModule // Should be removed and used only inside `CommunitiesRootStore` AND private, not accessible from outside components
    readonly property bool checkingPermissionToJoinInProgress: communitiesModuleInst.checkingPermissionToJoinInProgress
    readonly property bool joinPermissionsCheckCompletedWithoutErrors: communitiesModuleInst.joinPermissionsCheckCompletedWithoutErrors
    readonly property bool channelsPermissionsCheckSuccessful: communitiesModuleInst.channelsPermissionsCheckSuccessful

    property string communityKeyToImport

    readonly property var myRevealedAddressesForCurrentCommunity: {
        try {
            let revealedAddresses = root.communitiesModuleInst.myRevealedAddressesStringForCurrentCommunity
            let revealedAddressArray = JSON.parse(revealedAddresses)
            return revealedAddressArray.map(addr => addr.toLowerCase())
        } catch (e) {
            console.error("Error parsing my revealed addresses", e)
        }
        return []
    }
    readonly property string myRevealedAirdropAddressForCurrentCommunity:
        root.communitiesModuleInst.myRevealedAirdropAddressForCurrentCommunity.toLowerCase()

    function createCommunity(communityName, communityDescription, checkedMembership, communityColor, communityTags,
                             communityImage, imageCropperModalaX, imageCropperModalaY, imageCropperModalbX, imageCropperModalbY,
                             historyArchiveSupportEnabled, pinMessagesAllowedForMembers, bannerJsonStr, encrypted) {
        communitiesModuleInst.createCommunity(communityName, communityDescription, checkedMembership, communityColor,
                                              communityTags, communityImage, imageCropperModalaX, imageCropperModalaY,
                                              imageCropperModalbX, imageCropperModalbY,
                                              historyArchiveSupportEnabled, pinMessagesAllowedForMembers,
                                              bannerJsonStr, encrypted);
    }

    function isMyCommunityRequestPending(id: string) {
        return communitiesModuleInst.isMyCommunityRequestPending(id)
    }

    function cancelPendingRequest(id: string) {
        communitiesModuleInst.cancelRequestToJoinCommunity(id)
    }
    
    function communityHasMember(communityId, pubKey)
    {
        return communitiesModuleInst.isMemberOfCommunity(communityId, pubKey)
    }

    function setActiveCommunity(communityId) {
        internal.mainModuleInst.setActiveSectionById(communityId);
    }

    function promoteSelfToControlNode(communityId) {
        communitiesModuleInst.promoteSelfToControlNode(communityId)
    }

    signal communityMemberStatusEphemeralNotification(string communityName, string memberName, int state)

    readonly property Connections _communityRelatedMainModuleConnections: Connections {
        target: internal.mainModuleInst

        function onCommunityMemberStatusEphemeralNotification(communityName: string, memberName: string, state: int) {
            root.communityMemberStatusEphemeralNotification(communityName, memberName, state)
        }
    }

    // End of Community related stuff

    // Wallet related properties and functions that shall be moved to `WalletRootStore`
    property var walletSectionSendInst: walletSectionSend
    property var savedAddressesModel: walletSectionSavedAddresses.model
    readonly property var followingAddressesModel: walletSectionFollowingAddresses.model
    readonly property var accounts: walletSectionAccounts.accounts
    property var walletAccountsModel: WalletStore.RootStore.nonWatchAccounts

    readonly property var globalAssetsModel: SortFilterProxyModel {
        sourceModel: communitiesModuleInst.tokenList

        proxyRoles: FastExpressionRole {
            function tokenIcon(symbol) {
                return Constants.tokenIcon(symbol)
            }
            name: "iconSource"
            expression: !!model.icon ? model.icon : tokenIcon(model.symbol)
            expectedRoles: ["icon", "symbol"]
        }
    }

    readonly property var globalCollectiblesModel: SortFilterProxyModel {
        sourceModel: communitiesModuleInst.collectiblesModel

        proxyRoles: FastExpressionRole {
            function collectibleIcon(icon) {
                return !!icon ? icon : Assets.png(Constants.defaultTokenIcon)
            }
            name: "iconSource"
            expression: collectibleIcon(model.icon)
            expectedRoles: ["icon"]
        }
    }

    property var assetsModel: SortFilterProxyModel {
        sourceModel: globalAssetsModel
        filters: [
            AnyOf {
                // We accept tokens from this community or general (empty community ID)
                ValueFilter {
                    roleName: "communityId"
                    value: ""
                }

                ValueFilter {
                    roleName: "communityId"
                    value: root.communityKeyToImport
                }
            }
        ]
    }
    property var collectiblesModel: SortFilterProxyModel {
        sourceModel: globalCollectiblesModel
        filters: [
            AnyOf {
                // We accept tokens from this community or general (empty community ID)
                ValueFilter {
                    roleName: "communityId"
                    value: ""
                }

                ValueFilter {
                    roleName: "communityId"
                    value: root.communityKeyToImport
                }
            }
        ]
    }

    function getEtherscanTxLink(chainID) {
        return networksModule.getBlockExplorerTxURL(chainID)
    }


    property string currentCurrency: walletSection.currentCurrency

    function getFiatValue(balance, cryptoSymbol, fiatSymbol) {
        return profileSectionStore.ensUsernamesStore.getFiatValue(balance, cryptoSymbol, fiatSymbol)
    }

    signal showToastAccountAdded(string name)
    signal showToastAccountRemoved(string name)
    signal showToastKeypairRenamed(string oldName, string newName)
    signal showNetworkEndpointUpdated(string name, bool isTest)
    signal showToastKeypairRemoved(string keypairName)
    signal showToastKeypairsImported(string keypairName, int keypairsCount, string error)
    signal showTransactionToast(string uuid,
                                int txType,
                                int fromChainId,
                                int toChainId,
                                string fromAddr,
                                string fromName,
                                string toAddr,
                                string toName,
                                string txToAddr,
                                string txToName,
                                string txHash,
                                bool approvalTx,
                                string fromAmount,
                                string toAmount,
                                string fromAsset,
                                string toAsset,
                                string username,
                                string publicKey,
                                string packId,
                                string communityId,
                                string communityName,
                                int communityInvolvedTokens,
                                string communityTotalAmount,
                                string communityAmount1,
                                bool communityAmountInfinite1,
                                string communityAssetName1,
                                int communityAssetDecimals1,
                                string communityAmount2,
                                bool communityAmountInfinite2,
                                string communityAssetName2,
                                int communityAssetDecimals2,
                                string communityInvolvedAddress,
                                int communityNubmerOfInvolvedAddresses,
                                string communityOwnerTokenName,
                                string communityMasterTokenName,
                                string communityDeployedTokenName,
                                string status,
                                string error)

    readonly property Connections _walletRelatedMainModuleConnections: Connections {
        target: internal.mainModuleInst

        function onShowToastAccountAdded(name: string) {
            root.showToastAccountAdded(name)
        }

        function onShowToastAccountRemoved(name: string) {
            root.showToastAccountRemoved(name)
        }

        function onShowToastKeypairRenamed(oldName: string, newName: string) {
            root.showToastKeypairRenamed(oldName, newName)
        }

        function onShowNetworkEndpointUpdated(name: string, isTest: bool) {
            root.showNetworkEndpointUpdated(name, isTest)
        }

        function onShowToastKeypairRemoved(keypairName: string) {
            root.showToastKeypairRemoved(keypairName)
        }

        function onShowToastKeypairsImported(keypairName: string, keypairsCount: int, error: string) {
            root.showToastKeypairsImported(keypairName, keypairsCount, error)
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
            root.showTransactionToast(uuid,
                                      txType,
                                      fromChainId,
                                      toChainId,
                                      fromAddr,
                                      fromName,
                                      toAddr,
                                      toName,
                                      txToAddr,
                                      txToName,
                                      txHash,
                                      approvalTx,
                                      fromAmount,
                                      toAmount,
                                      fromAsset,
                                      toAsset,
                                      username,
                                      publicKey,
                                      packId,
                                      communityId,
                                      communityName,
                                      communityInvolvedTokens,
                                      communityTotalAmount,
                                      communityAmount1,
                                      communityAmountInfinite1,
                                      communityAssetName1,
                                      communityAssetDecimals1,
                                      communityAmount2,
                                      communityAmountInfinite2,
                                      communityAssetName2,
                                      communityAssetDecimals2,
                                      communityInvolvedAddress,
                                      communityNubmerOfInvolvedAddresses,
                                      communityOwnerTokenName,
                                      communityMasterTokenName,
                                      communityDeployedTokenName,
                                      status,
                                      error)
        }
    }
    // End of Wallet related stuff

    // Keycard related properties and functions that shall be moved to `KeycardStore`
    // (and should be reviewed the usage since modules should not be directly exposed
    property var keycardSharedModuleForAuthenticationOrSigning: null
    property var keycardSharedModule: null

    signal displayKeycardSharedModuleForAuthenticationOrSigning()
    signal destroyKeycardSharedModuleForAuthenticationOrSigning()
    signal displayKeycardSharedModuleFlow()
    signal destroyKeycardSharedModuleFlow()

    readonly property Connections keycardRelatedMainModuleConnections: Connections {
        target: internal.mainModuleInst

        function onDisplayKeycardSharedModuleForAuthenticationOrSigning() {
            root.keycardSharedModuleForAuthenticationOrSigning = mainModule.keycardSharedModuleForAuthenticationOrSigning
            root.displayKeycardSharedModuleForAuthenticationOrSigning()
        }

        function onDestroyKeycardSharedModuleForAuthenticationOrSigning() {
            root.destroyKeycardSharedModuleForAuthenticationOrSigning()
        }

        function onDisplayKeycardSharedModuleFlow() {
            root.keycardSharedModule = mainModule.keycardSharedModule
            root.displayKeycardSharedModuleFlow()
        }

        function onDestroyKeycardSharedModuleFlow() {
            root.destroyKeycardSharedModuleFlow()
        }

        function onRequestGetCredentialFromKeychain(key: string) {
            keychain.requestGetCredential("authenticate", key)
        }

        function onRequestStoreCredentialToKeychain(key: string, password: string) {
            const result = keychain.updateCredential(key, password)
            if(result === Keychain.StatusSuccess) {
                internal.mainModuleInst.credentialStoredToKeychainResult(true)
            } else {
                internal.mainModuleInst.credentialStoredToKeychainResult(false)
            }
        }
    }
    // End of Keycard related stuff

    readonly property Connections keychainConnections: Connections {
        target: root.keychain
        function onGetCredentialRequestCompleted(status: int, secret: string) {
            if (status === Keychain.StatusSuccess) {
                internal.mainModuleInst.requestGetCredentialFromKeychainResult(true, secret)
            } else {
                internal.mainModuleInst.requestGetCredentialFromKeychainResult(false, "")
            }
        }
    }
}
