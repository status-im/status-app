import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import shared
import shared.panels
import shared.stores as SharedStores
import shared.stores.send
import utils

import "popups"
import "views"
import "views/profile"

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Layout
import StatusQ.Popups.Dialog

import AppLayouts.Communities.stores as CommunitiesStore
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Profile.helpers
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.stores
import AppLayouts.stores as AppLayoutsStores
import AppLayouts.stores.Messaging as MessagingStores

import SortFilterProxyModel
import QtModelsToolkit

StatusSectionLayout {
    id: root

    required property bool isProduction

    property int settingsSubsection: -1
    property int settingsSubSubsection: -1

    objectName: "profileStatusSectionLayout"

    required property TokensStore tokensStore
    required property WalletAssetsStore walletAssetsStore
    required property CollectiblesStore collectiblesStore
    required property SharedStores.CurrenciesStore currencyStore
    required property SharedStores.NetworksStore networksStore
    required property MessagingStores.MessagingRootStore messagingRootStore

    required property ProfileStores.ProfileStore profileStore
    required property ProfileStores.DevicesStore devicesStore
    required property ProfileStores.AdvancedStore advancedStore
    required property ProfileStores.PrivacyStore privacyStore
    required property ProfileStores.NotificationsStore notificationsStore
    required property ProfileStores.LanguageStore languageStore
    required property ProfileStores.KeycardNewStore keycardNewStore
    required property ProfileStores.LogosNetworkStore logosNetworkStore
    required property ProfileStores.WalletStore walletStore
    required property ProfileStores.EnsUsernamesStore ensUsernamesStore
    required property ProfileStores.AboutStore aboutStore
    required property BrowserStores.BrowserPreferencesStore browserPreferencesStore

    property SharedStores.RootStore sharedRootStore
    property SharedStores.UtilsStore utilsStore
    property SharedStores.NetworkConnectionStore networkConnectionStore
    property CommunitiesStore.CommunitiesStore communitiesStore
    property MessagingStores.MessagingSettingsStore messagingSettingsStore
    property AppLayoutsStores.ContactsStore contactsStore
    property AppLayoutsStores.RootStore globalStore


    required property Keychain keychain
    required property SecureStorage secureStorage

    property bool isKeycardEnabled: true
    property bool isBrowserEnabled: true
    required property bool messageLinkSharingFeatureEnabled
    required property bool privacyModeFeatureEnabled
    required property bool minimizeOnCloseOptionVisible

    property var mutualContactsModel
    property var blockedContactsModel
    property var pendingContactsModel
    property int pendingReceivedContactsCount
    property var dismissedReceivedRequestContactsModel

    required property int theme // ThemeUtils.Style.xxx
    required property real nativeWindowDpr // baseline/native DPR of the respective Screen

    required property var whitelistedDomainsModel

    required property int syncingBadgeCount

    signal addressWasShownRequested(string address)
    signal connectUsernameRequested(string ensName, string ownerAddress)
    signal registerUsernameRequested(string ensName, int chainId)
    signal releaseUsernameRequested(string ensName, string senderAddress, int chainId)

    signal themeChangeRequested(int theme)
    signal leaveCommunityRequest(string communityId)
    signal setCommunityMutedRequest(string communityId, int mutedType)
    signal inviteFriends(var communityData)

    signal openThirdpartyServicesInfoPopupRequested()
    signal openDiscussPageRequested()
    signal removeWhitelistedDomain(int index)

    backButtonName: d.backButtonName
    onBackButtonClicked: {
        switch (root.settingsSubsection) {
        case Constants.settingsSubsection.contacts:
            Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.messaging)
            break;
        case Constants.settingsSubsection.about_privacy:
        case Constants.settingsSubsection.about_terms:
            Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.about)
            break;
        case Constants.settingsSubsection.wallet:
            profileContainer.currentItem.goBack()
            break;
        case Constants.settingsSubsection.privacyAndSecurity:
            profileContainer.currentItem.resetStack()
            break;
        case Constants.settingsSubsection.keycardNew:
            profileContainer.currentItem.handleBackAction()
            break;
        }

        root.settingsSubSubsection = -1
    }

    function forceSubsectionNavigation() {
        root.goToNextPanel()
    }

    QtObject {
        id: d

        readonly property int contentWidth: Math.min(profileContainer.width, 560)
        readonly property int rightPanelWidth: Math.min(profileContainer.height, 768)

        readonly property bool isProfilePanelActive: root.settingsSubsection === Constants.settingsSubsection.profile
        readonly property bool sideBySidePreviewAvailable: root.Window.width >= 1840 // design

        // Used to alternatively add an error message to the dirty bubble if ephemeral notification
        // can clash at smaller viewports
        readonly property bool toastClashesWithDirtyBubble: root.Window.width <= 1650 // design

        property string backButtonName
    }

    SettingsEntriesModel {
        id: settingsEntriesModel

        showWalletEntries: root.walletStore.isWalletEnabled
        showBrowserEntries: root.isBrowserEnabled && localAccountSensitiveSettings.isBrowserEnabled
        showBackUpSeed: !root.privacyStore.mnemonicBackedUp
        backUpSeedBadgeCount: root.profileStore.userDeclinedBackupBanner ? 0 : showBackUpSeed
        isKeycardEnabled: root.isKeycardEnabled
        localBackupEnabled: root.devicesStore.localBackupEnabled

        syncingBadgeCount: root.syncingBadgeCount
        messagingBadgeCount: root.pendingReceivedContactsCount
    }

    // Subsection back history keyed by the settingsSubsection enum.
    subsectionHistory: SQUtils.SubsectionNavigationHistory {
        currentKey: root.settingsSubsection
        validateFn: (key) => SQUtils.ModelUtils.indexOf(settingsEntriesModel, "subsection", parseInt(key)) >= 0
        onNavigateRequested: (key) => {
                                 Global.changeAppSectionBySectionType(Constants.appSection.profile, parseInt(key))
                                 root.goToNextPanel()
                             }
    }

    leftPanel: SettingsLeftTabView {
        id: leftPanel
        anchors.fill: parent

        settingsSubsection: root.settingsSubsection
        model: settingsEntriesModel

        onMenuItemClicked: function(subsection) {
            if (profileContainer.currentItem?.dirty && !profileContainer.currentItem?.ignoreDirty) {
                profileContainer.currentItem.notifyDirty();
                return
            }
            Global.changeAppSectionBySectionType(Constants.appSection.profile, subsection)
            root.goToNextPanel();
        }
    }

    function loadSection(section: int): void {
        d.backButtonName = ""
        if (section === -1) {
            profileContainer.clear()
            return
        }
        var componentToLoad = null
        switch (section) {
        case Constants.settingsSubsection.profile:
            componentToLoad = myProfileViewComp
            break
        case Constants.settingsSubsection.password:
            componentToLoad = changePasswordViewComp
            break
        case Constants.settingsSubsection.contacts:
            d.backButtonName = settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.messaging)
            componentToLoad = contactsViewComp
            break
        case Constants.settingsSubsection.ensUsernames:
            componentToLoad = ensViewComp
            break
        case Constants.settingsSubsection.messaging:
            componentToLoad = messagingViewComp
            break
        case Constants.settingsSubsection.wallet:
            componentToLoad = walletViewComp
            break
        case Constants.settingsSubsection.appearance:
            componentToLoad = appearanceViewComp
            break
        case Constants.settingsSubsection.language:
            componentToLoad = languageViewComp
            break
        case Constants.settingsSubsection.notifications:
            componentToLoad = notificationsViewComp
            break
        case Constants.settingsSubsection.syncingSettings:
            componentToLoad = syncingViewComp
            break
        case Constants.settingsSubsection.browserSettings:
            componentToLoad = browserViewComp
            break
        case Constants.settingsSubsection.advanced:
            componentToLoad = advancedViewComp
            break
        case Constants.settingsSubsection.about:
            componentToLoad = aboutViewComp
            break
        case Constants.settingsSubsection.communitiesSettings:
            componentToLoad = communitiesViewComp
            break
        case Constants.settingsSubsection.keycardNew:
            componentToLoad = keycardViewNewComp
            break
        case Constants.settingsSubsection.about_terms:
            d.backButtonName = settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.about)
            componentToLoad = termsOfUseComp
            break
        case Constants.settingsSubsection.about_privacy:
            d.backButtonName = settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.about)
            componentToLoad = privacyPolicyComp
            break
        case Constants.settingsSubsection.privacyAndSecurity:
            componentToLoad = privacyAndSecurityViewComp
            break
        case Constants.settingsSubsection.backupSettings:
            componentToLoad = backupViewComp
            break
        case Constants.settingsSubsection.logosNetworkSettings:
            componentToLoad = logosNetworkViewComp
            break
        default:
            console.warn("ProfileLayout.loadSection: unhandled settings subsection:", section)
            break
        }
        if (typeof componentToLoad?.adopt === "function") {
            const item = profileContainer.replaceCurrentItem(componentToLoad.component(),
                                                             componentToLoad.properties,
                                                             StackView.Immediate)
            componentToLoad.adopt(item)
        } else if (!!componentToLoad) {
            profileContainer.replaceCurrentItem(componentToLoad, {}, StackView.Immediate)
        }
    }

    Connections {
        target: root
        function onSettingsSubsectionChanged(): void {
            root.loadSection(root.settingsSubsection)
        }
    }

    centerPanel: Item {
        StackView {
            id: profileContainer

            anchors.fill: parent
            anchors.leftMargin: root.Theme.xlPadding * 2
            anchors.rightMargin: root.Theme.xlPadding * 2

        SQUtils.DeferredComponent {
            id: myProfileViewComp

            source: Qt.resolvedUrl("views/MyProfileView.qml")
            properties: ({
                ignoreDirty: Qt.binding(() => root.isPortrait),
                profileStore: root.profileStore,
                contactsStore: root.contactsStore,
                communitiesStore: root.communitiesStore,
                utilsStore: root.utilsStore,
                networksStore: root.networksStore,
                sendToAccountEnabled: Qt.binding(() => root.networkConnectionStore.walletReadyForTransactionsEnabled),
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.profile)),
                contentWidth: Qt.binding(() => d.contentWidth),
                sideBySidePreview: Qt.binding(() => d.sideBySidePreviewAvailable),
                toastClashesWithDirtyBubble: Qt.binding(() => d.toastClashesWithDirtyBubble),
                communitiesShowcaseModel: Qt.binding(() => root.profileStore.ownShowcaseCommunitiesModel),
                accountsShowcaseModel: Qt.binding(() => root.profileStore.ownShowcaseAccountsModel),
                socialLinksShowcaseModel: Qt.binding(() => root.profileStore.ownShowcaseSocialLinksModel),
                assetsModel: Qt.binding(() => root.globalStore.globalAssetsModel),
                collectiblesModel: Qt.binding(() => root.globalStore.globalCollectiblesModel)
            })

            onCreated: view => view.collectiblesShowcaseModel = collectiblesShowcaseModelComp.createObject(view)
        }

        Component {
            id: collectiblesShowcaseModelComp

            SortFilterProxyModel {
                sourceModel: root.profileStore.ownShowcaseCollectiblesModel
                sorters: [
                    FastExpressionSorter {
                        expression: {
                            root.collectiblesStore.collectiblesController.revision
                            return root.collectiblesStore.collectiblesController.compareTokens(modelLeft.uid, modelRight.uid)
                        }
                        expectedRoles: ["uid"]
                    }
                ]
                filters: [
                    FastExpressionFilter {
                        expression: {
                            root.collectiblesStore.collectiblesController.revision
                            return root.collectiblesStore.collectiblesController.filterAcceptsKey(model.uid) // TODO: use token/group key
                        }
                        expectedRoles: ["uid"]
                    }
                ]
            }
        }

        SQUtils.DeferredComponent {
            id: changePasswordViewComp

            source: Qt.resolvedUrl("views/ChangePasswordView.qml")
            properties: ({
                privacyStore: root.privacyStore,
                keychain: root.keychain,
                secureStorage: root.secureStorage,
                passwordStrengthScoreFunction: root.sharedRootStore.getPasswordStrengthScore,
                contentWidth: Qt.binding(() => d.contentWidth),
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.password))
            })
        }

        SQUtils.DeferredComponent {
            id: contactsViewComp

            source: Qt.resolvedUrl("views/ContactsView.qml")
            properties: ({
                contactsStore: root.contactsStore,
                utilsStore: root.utilsStore,
                sectionTitle: qsTr("Contacts"),
                contentWidth: Qt.binding(() => d.contentWidth),
                mutualContactsModel: Qt.binding(() => root.mutualContactsModel),
                blockedContactsModel: Qt.binding(() => root.blockedContactsModel),
                pendingContactsModel: Qt.binding(() => root.pendingContactsModel),
                pendingReceivedContactsCount: Qt.binding(() => root.pendingReceivedContactsCount),
                dismissedReceivedRequestContactsModel: Qt.binding(() => root.dismissedReceivedRequestContactsModel)
            })
        }

        SQUtils.DeferredComponent {
            id: ensViewComp

            source: Qt.resolvedUrl("views/EnsView.qml")
            properties: ({
                ensUsernamesStore: root.ensUsernamesStore,
                walletAssetsStore: root.walletAssetsStore,
                networkConnectionStore: root.networkConnectionStore,
                profileContentWidth: Qt.binding(() => d.contentWidth)
            })

            onCreated: view => {
                view.connectUsernameRequested.connect((ensName, ownerAddress) => root.connectUsernameRequested(ensName, ownerAddress))
                view.registerUsernameRequested.connect((ensName, chainId) => root.registerUsernameRequested(ensName, chainId))
                view.releaseUsernameRequested.connect((ensName, senderAddress, chainId) => root.releaseUsernameRequested(ensName, senderAddress, chainId))
            }
        }

        SQUtils.DeferredComponent {
            id: messagingViewComp

            source: Qt.resolvedUrl("views/MessagingView.qml")
            properties: ({
                contentWidth: Qt.binding(() => d.contentWidth),
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.messaging)),
                requestsCount: Qt.binding(() => root.pendingReceivedContactsCount),
                messagingSettingsStore: root.messagingSettingsStore
            })
        }

        SQUtils.DeferredComponent {
            id: walletViewComp

            source: Qt.resolvedUrl("views/WalletView.qml")
            properties: ({
                contentWidth: Qt.binding(() => d.contentWidth),
                settingsSubSubsection: Qt.binding(() => root.settingsSubSubsection),
                isKeycardEnabled: Qt.binding(() => root.isKeycardEnabled),
                walletStore: root.walletStore,
                tokensStore: root.tokensStore,
                networkConnectionStore: root.networkConnectionStore,
                assetsStore: root.walletAssetsStore,
                collectiblesStore: root.collectiblesStore,
                networksStore: root.networksStore,
                contactsStore: root.contactsStore,
                thirdpartyServicesEnabled: Qt.binding(() => root.privacyStore.thirdpartyServicesEnabled),
                myPublicKey: Qt.binding(() => userProfile.pubKey),
                currencySymbol: Qt.binding(() => root.sharedRootStore.currencyStore.currentCurrency),
                sectionTitle: settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.wallet)
            })

            onCreated: view => {
                view.addressWasShownRequested.connect(address => root.addressWasShownRequested(address))
                view.backButtonNameChanged.connect(() => d.backButtonName = view.backButtonName)
                view.initStack()
            }
        }

        SQUtils.DeferredComponent {
            id: appearanceViewComp

            source: Qt.resolvedUrl("views/AppearanceView.qml")
            properties: ({
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.appearance)),
                contentWidth: Qt.binding(() => d.contentWidth),
                nativeWindowDpr: Qt.binding(() => root.nativeWindowDpr),
                theme: Qt.binding(() => root.theme),
                uiScaleFile: Qt.binding(() => uiScaleFilePath)
            })

            onCreated: view => {
                view.themeChangeRequested.connect((theme) => root.themeChangeRequested(theme))
                view.restartRequested.connect(() => Qt.callLater(() => SystemUtils.restartApplication()))
            }
        }

        SQUtils.DeferredComponent {
            id: languageViewComp

            source: Qt.resolvedUrl("views/LanguageView.qml")
            properties: ({
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.language)),
                contentWidth: Qt.binding(() => d.contentWidth),
                spellCheckEnabled: Qt.binding(() => root.languageStore.spellCheckSettings.enabled),
                spellCheckSkipCapitalizedWords: Qt.binding(() => root.languageStore.spellCheckSettings.skipCapitalizedWords),
                availableSpellcheckLanguages: Qt.binding(() => root.languageStore.spellCheckSettings.availableLanguages),
                activeSpellcheckLanguages: Qt.binding(() => root.languageStore.spellCheckSettings.activeLanguages),
                currentLanguage: Qt.binding(() => root.languageStore.currentLanguage),
                availableLanguages: Qt.binding(() => root.languageStore.availableLanguages),
                currentCurrency: Qt.binding(() => root.currencyStore.currentCurrency),
                currenciesModel: Qt.binding(() => root.currencyStore.currenciesModel)
            })

            onCreated: view => {
                view.spellCheckEnabledChangeRequested.connect(value => root.languageStore.spellCheckSettings.setEnabled(value))
                view.spellCheckSkipCapitalizedWordsChangeRequested.connect(value => root.languageStore.spellCheckSettings.setSkipCapitalizedWords(value))
                view.enableSpellcheckLanguageRequested.connect((code, enabled) => root.languageStore.spellCheckSettings.toggleSpellcheckLanguage(code, enabled))
                view.changeLanguageRequested.connect(newLanguageCode => {
                    const result = root.languageStore.changeLanguage(newLanguageCode, false /*shouldRetranslate*/)
                    if (result)
                        Qt.callLater(() => SystemUtils.restartApplication())
                    else
                        console.warn("Failed setting language to:", newLanguageCode)
                })
                view.changeCurrencyRequested.connect(shortName => root.currencyStore.updateCurrency(shortName))
            }
        }

        SQUtils.DeferredComponent {
            id: notificationsViewComp

            source: Qt.resolvedUrl("views/NotificationsView.qml")
            properties: ({
                privacyStore: root.privacyStore,
                notificationsStore: root.notificationsStore,
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.notifications)),
                contentWidth: Qt.binding(() => d.contentWidth)
            })
        }

        SQUtils.DeferredComponent {
            id: syncingViewComp

            source: Qt.resolvedUrl("views/SyncingView.qml")
            properties: ({
                profileStore: root.profileStore,
                devicesStore: root.devicesStore,
                privacyStore: root.privacyStore,
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.syncingSettings)),
                contentWidth: Qt.binding(() => d.contentWidth)
            })

            onCreated: view => view.deleteDeviceRequested.connect(installationId => {
                const error = root.devicesStore.devicesModule.deleteDevice(installationId)
                if (error)
                    view.errorDeletingDeviceMessage = error
            })
        }

        SQUtils.DeferredComponent {
            id: browserViewComp

            source: Qt.resolvedUrl("views/BrowserView.qml")
            properties: ({
                userUID: Qt.binding(() => root.userUID),
                accountSettings: Qt.binding(() => localAccountSensitiveSettings),
                browserPreferencesStore: root.browserPreferencesStore,
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.browserSettings)),
                contentWidth: Qt.binding(() => d.contentWidth)
            })
        }

        SQUtils.DeferredComponent {
            id: advancedViewComp

            source: Qt.resolvedUrl("views/AdvancedView.qml")
            properties: ({
                advancedStore: root.advancedStore,
                walletStore: root.walletStore,
                isFleetSelectionEnabled: fleetSelectionEnabled,
                isBrowserEnabled: Qt.binding(() => root.isBrowserEnabled),
                messageLinkSharingFeatureEnabled: Qt.binding(() => root.messageLinkSharingFeatureEnabled),
                minimizeOnCloseOptionVisible: Qt.binding(() => root.minimizeOnCloseOptionVisible),
                sectionTitle: settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.advanced),
                contentWidth: Qt.binding(() => d.contentWidth)
            })
        }

        SQUtils.DeferredComponent {
            id: aboutViewComp

            source: Qt.resolvedUrl("views/AboutView.qml")
            properties: ({
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.about)),
                contentWidth: Qt.binding(() => d.contentWidth),
                isProduction: Qt.binding(() => root.isProduction),
                currentVersion: Qt.binding(() => root.aboutStore.getCurrentVersion()),
                gitCommit: Qt.binding(() => root.aboutStore.getGitCommit()),
                statusGoVersion: Qt.binding(() => root.aboutStore.getStatusGoVersion()),
                qtRuntimeVersion: Qt.binding(() => SystemUtils.qtRuntimeVersion())
            })

            onCreated: view => {
                view.checkForUpdates.connect(() => root.aboutStore.checkForUpdates())
                view.openLink.connect((url) => Global.requestOpenLink(url))
            }
        }

        SQUtils.DeferredComponent {
            id: communitiesViewComp

            function getSpecificCommunityAccessStore(owner, communityId: string) {
                const communityRootStore = root.messagingRootStore.createCommunityRootStore(owner, communityId)
                return communityRootStore ? communityRootStore.communityAccessStore : null
            }

            source: Qt.resolvedUrl("views/CommunitiesView.qml")
            properties: ({
                rootStore: root.globalStore,
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.communitiesSettings)),
                contentWidth: Qt.binding(() => d.contentWidth),
                communitiesList: Qt.binding(() => root.profileStore.communitiesList)
            })

            onCreated: view => {
                view.fnIsMyCommunityRequestPending = communityId => {
                    const communityAccessStore = communitiesViewComp.getSpecificCommunityAccessStore(view, communityId)
                    return communityAccessStore ? communityAccessStore.isMyCommunityRequestPending : false
                }
                view.leaveCommunityRequest.connect(communityId => root.leaveCommunityRequest(communityId))
                view.setCommunityMutedRequest.connect((communityId, mutedType) => root.setCommunityMutedRequest(communityId, mutedType))
                view.inviteFriends.connect(communityData => root.inviteFriends(communityData))
                view.cancelPendingRequestRequested.connect(communityId => {
                    const communityAccessStore = communitiesViewComp.getSpecificCommunityAccessStore(view, communityId)
                    if (communityAccessStore)
                        communityAccessStore.cancelPendingRequest(communityId)
                })
            }
        }

        SQUtils.DeferredComponent {
            id: keycardViewNewComp

            source: Qt.resolvedUrl("views/KeycardViewNew.qml")
            properties: ({
                keycardNewStore: root.keycardNewStore,
                areTestNetworksEnabled: Qt.binding(() => root.networksStore.areTestNetworksEnabled),
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.keycardNew)),
                mainSectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.keycardNew)),
                contentWidth: Qt.binding(() => d.contentWidth)
            })

            onCreated: view => {
                view.backButtonNameRequested.connect(name => d.backButtonName = name)
                view.handleBackAction()
            }
        }

        Component {
            id: termsOfUseComp
            SettingsContentBase {
                sectionTitle: "Status Software - Terms of Use"
                contentWidth: d.contentWidth

                StatusBaseText {
                    width: d.contentWidth
                    wrapMode: Text.Wrap
                    textFormat: Text.MarkdownText
                    text: SQUtils.StringUtils.readTextFile(":/imports/assets/docs/terms-of-use.mdwn")
                    onLinkActivated: (link) => Global.requestOpenLink(link)
                }
            }
        }

        Component {
            id: privacyPolicyComp
            SettingsContentBase {
                sectionTitle: "Status Software - Privacy Policy"
                contentWidth: d.contentWidth

                StatusBaseText {
                    width: d.contentWidth
                    wrapMode: Text.Wrap
                    textFormat: Text.MarkdownText
                    text: SQUtils.StringUtils.readTextFile(":/imports/assets/docs/privacy.mdwn")
                    onLinkActivated: (link) => Global.requestOpenLink(link)
                }
            }
        }

        SQUtils.DeferredComponent {
            id: privacyAndSecurityViewComp

            source: Qt.resolvedUrl("views/PrivacyAndSecurityView.qml")
            properties: ({
                whitelistedDomainsModel: Qt.binding(() => root.whitelistedDomainsModel),
                isStatusNewsViaRSSEnabled: Qt.binding(() => root.privacyStore.isStatusNewsViaRSSEnabled),
                thirdpartyServicesEnabled: Qt.binding(() => root.privacyStore.thirdpartyServicesEnabled),
                privacyModeFeatureEnabled: Qt.binding(() => root.privacyModeFeatureEnabled),
                privacySectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.privacyAndSecurity)),
                contentWidth: Qt.binding(() => d.contentWidth)
            })

            onCreated: view => {
                view.setNewsRSSEnabledRequested.connect(enabled => root.privacyStore.setNewsRSSEnabled(enabled))
                view.openThirdpartyServicesInfoPopupRequested.connect(() => root.openThirdpartyServicesInfoPopupRequested())
                view.openDiscussPageRequested.connect(() => root.openDiscussPageRequested())
                view.backButtonTextChanged.connect(() => d.backButtonName = view.backButtonText)
                view.removeWhitelistedDomain.connect(index => root.removeWhitelistedDomain(index))
                view.resetStack()
            }
        }

        SQUtils.DeferredComponent {
            id: backupViewComp

            source: Qt.resolvedUrl("views/BackupView.qml")
            properties: ({
                contentWidth: Qt.binding(() => d.contentWidth),
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.backupSettings)),
                backupDataState: Qt.binding(() => root.devicesStore.backupDataState),
                backupDataError: Qt.binding(() => root.devicesStore.backupDataError),
                backupImportState: Qt.binding(() => root.devicesStore.backupImportState),
                backupImportError: Qt.binding(() => root.devicesStore.backupImportError),
                backupPath: Qt.binding(() => root.devicesStore.backupPath),
                messagesBackupEnabled: Qt.binding(() => root.devicesStore.messagesBackupEnabled)
            })

            onCreated: view => {
                view.backupPathSet.connect(path => root.devicesStore.setBackupPath(path))
                view.backupMessagesEnabledToggled.connect(enabled => root.devicesStore.setMessagesBackupEnabled(enabled))
                view.performLocalBackupRequested.connect(() => root.devicesStore.performLocalBackup())
                view.importLocalBackupFileRequested.connect(selectedFile => root.devicesStore.importLocalBackupFile(selectedFile))
            }
        }

        SQUtils.DeferredComponent {
            id: logosNetworkViewComp

            source: Qt.resolvedUrl("views/LogosNetworkView.qml")
            properties: ({
                contentWidth: Qt.binding(() => d.contentWidth),
                sectionTitle: Qt.binding(() => settingsEntriesModel.getNameForSubsection(Constants.settingsSubsection.logosNetworkSettings)),
                peerCount: Qt.binding(() => root.logosNetworkStore.peerCount),
                peerCountLoading: Qt.binding(() => root.logosNetworkStore.peerCountLoading),
                peerCountError: Qt.binding(() => root.logosNetworkStore.peerCountError)
            })

            onCreated: view => {
                view.pollingActive = Qt.binding(() => view.StackView.visible)
                view.refreshPeerCountRequested.connect(() => root.logosNetworkStore.refreshPeerCount())
            }
        }
        }
    }

    showRightPanel: d.isProfilePanelActive && d.sideBySidePreviewAvailable
    rightPanelWidth: d.rightPanelWidth
    rightPanel: Loader {
        active: root.showRightPanel
        sourceComponent: profileContainer.currentItem?.sideBySidePreviewComponent
    }
}
