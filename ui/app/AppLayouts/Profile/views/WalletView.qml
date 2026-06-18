import QtCore
import QtQml
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import utils
import shared
import shared.panels
import shared.popups
import shared.popups.keypairimport
import shared.status
import shared.stores as SharedStores

import "../stores"
import "../controls"
import "../popups"
import "../panels"

import AppLayouts.Profile.views.wallet
import AppLayouts.Wallet.stores
import AppLayouts.Wallet.controls
import AppLayouts.Wallet
import AppLayouts.stores as AppLayoutStores

SettingsContentBase {
    id: root

    property var emojiPopup
    property string myPublicKey: ""
    property alias currencySymbol: manageTokensView.currencySymbol

    required property bool thirdpartyServicesEnabled

    property int settingsSubSubsection
    readonly property alias backButtonName: priv.backButtonName

    property WalletStore walletStore
    property AppLayoutStores.ContactsStore contactsStore
    required property TokensStore tokensStore
    property SharedStores.NetworkConnectionStore networkConnectionStore
    required property WalletAssetsStore assetsStore
    required property CollectiblesStore collectiblesStore
    required property SharedStores.NetworksStore networksStore

    // There are 3 different deep levels on this view:
    readonly property int mainViewIndex: 0              // Level 0 - Base / "parent"
    readonly property int networksViewIndex: 1          // Level 1 - First networks level
    readonly property int editNetworksViewIndex: 2      // Level 2 - Second networks level
    readonly property int accountOrderViewIndex: 3      // Level 1
    readonly property int accountViewIndex: 4           // Level 1
    readonly property int manageTokensViewIndex: 5      // Level 1
    readonly property int savedAddressesViewIndex: 6    // Level 1

    readonly property string walletSectionTitle: qsTr("Wallet")
    readonly property string networksSectionTitle: qsTr("Networks")

    property bool isKeycardEnabled: true

    signal addressWasShownRequested(string address)

    function goBack() {
        // This case means it was in Level 2 deep:
        if(stackContainer.currentIndex === root.editNetworksViewIndex) {
            networksView.overrideInitialTabIndex(editNetwork.network.isTest ? networksView.testnetTabIndex : networksView.mainnetTabIndex)
            priv.navigateToDetails(root.networksViewIndex)
            return
        }

        // This case means it was in any of the Level 1 deep options, so navigate to main level 0
        priv.navigateToDetails(root.mainViewIndex)
    }

    function initStack() {
        // This is a forced initial navigation to main view (deep level 0) to ensure that once the stack is initiated by a navigation
        // from outside the component, there's always the main page inside the "memory" of the stack so that there's back button
        // although the navigation is directly pointing to the details page (deep level 1)
        if(stackContainer.currentIndex !== root.mainViewIndex) {
            priv.navigateToDetails(root.mainViewIndex)
        }

        // These are all detail navigation flow started / requested from outside this component
        switch(root.settingsSubSubsection) {
            // Manage tokens details view:
            case Constants.walletSettingsSubsection.manageAssets:
            case Constants.walletSettingsSubsection.manageCollectibles:
            case Constants.walletSettingsSubsection.manageHidden:
            case Constants.walletSettingsSubsection.manageAdvanced:
                priv.navigateToDetails(root.manageTokensViewIndex)
                return

            // Manage networks details view:
            case Constants.walletSettingsSubsection.manageNetworks:
                priv.navigateToDetails(root.networksViewIndex)
                return
        }

        // Main Wallet settings view:
        priv.navigateToDetails(root.mainViewIndex)
    }

    // Dirty state will be just ignored when user leaves manage tokens settings (excluding advanced settings that needs user action)
    ignoreDirty: stackContainer.currentIndex === manageTokensViewIndex && !manageTokensView.advancedTabVisible
    dirty: manageTokensView.dirty
    saveChangesButtonEnabled: dirty
    toast.type: SettingsDirtyToastMessage.Type.Info
    toast.cancelButtonVisible: manageTokensView.advancedTabVisible
    toast.saveForLaterButtonVisible: !manageTokensView.advancedTabVisible
    toast.saveForLaterText: qsTr("Save")
    toast.saveChangesText: manageTokensView.advancedTabVisible ? toast.defaultSaveChangesText : qsTr("Save and apply")
    toast.changesDetectedText: manageTokensView.advancedTabVisible ? toast.defaultChangesDetectedText : qsTr("New custom sort order created")

    onSaveForLaterClicked: {
        manageTokensView.saveChanges(false /* update */)
    }
    onSaveChangesClicked: {
        manageTokensView.saveChanges(true /* update */)

        if (manageTokensView.advancedTabVisible) {
            // don't emit toasts when the Advanced tab is visible
            return
        }

        let sectionLink = "%1/%2/".arg(Constants.appSection.wallet).arg(WalletLayout.LeftPanelSelection.AllAddresses)
        if (manageTokensView.assetsPanelVisible) {
            sectionLink += WalletLayout.RightPanelSelection.Assets
            priv.walletSettings.setValue("assetsViewCustomOrderApplyTimestamp", new Date().getTime())
            priv.walletSettings.sync()
        } else if (manageTokensView.collectiblesPanelVisible) {
            sectionLink += WalletLayout.RightPanelSelection.Collectibles
            priv.walletSettings.setValue("collectiblesViewCustomOrderApplyTimestamp", new Date().getTime())
            priv.walletSettings.sync()
        }

        Global.displayToastMessage(
            qsTr("Your new custom token order has been applied to your %1", "Go to Wallet")
                    .arg(`<a style="text-decoration:none" href="#${sectionLink}">` + qsTr("Wallet", "Go to Wallet") + "</a>"),
            "",
            "checkmark-circle",
            false,
            Constants.ephemeralNotificationType.success,
            ""
        )
    }
    onResetChangesClicked: {
        manageTokensView.resetChanges()
    }

    readonly property var priv: QtObject {
        id: priv

        readonly property string removeKeypairIdentifier: "profile-remove-keypair"

        readonly property var walletSettings: Settings {
            category: "walletSettings-" + root.myPublicKey
        }

        property string backButtonName: ""

        function navigateToDetails(detailsIndex) {
            // No need for a navigation:
            if(detailsIndex === stackContainer.currentIndex)
                return

            switch (detailsIndex) {
                case root.mainViewIndex:
                case root.networksViewIndex:
                case root.editNetworksViewIndex:
                case root.accountOrderViewIndex:
                case root.accountViewIndex:
                case root.manageTokensViewIndex:
                case root.savedAddressesViewIndex:
                    stackContainer.currentIndex = detailsIndex
                    return
            }
            // This is the default:
            console.warn("Unexpected details index so, navigate to main view. Index: " + detailsIndex)
            stackContainer.currentIndex = root.mainViewIndex
        }
    }

    StackLayout {
        id: stackContainer

        width: root.contentWidth

        currentIndex: mainViewIndex

        onCurrentIndexChanged: {
            // Defaults
            priv.backButtonName = root.walletSectionTitle
            root.sectionTitle = root.walletSectionTitle
            root.titleRowComponentLoader.sourceComponent = undefined
            root.titleRowLeftComponentLoader.sourceComponent = undefined
            root.titleRowLeftComponentLoader.visible = false
            root.stickTitleRowComponentLoader = false
            root.titleLayout.spacing = 5

            // Specific cases
            switch (stackContainer.currentIndex) {
            case root.mainViewIndex:
                priv.backButtonName = ""
                root.sectionTitle = root.walletSectionTitle
                root.titleRowComponentLoader.sourceComponent = addNewAccountButtonComponent
                break

            case root.networksViewIndex:
                priv.backButtonName = root.walletSectionTitle
                root.sectionTitle = root.networksSectionTitle
                root.titleRowComponentLoader.sourceComponent = toggleTestnetModeSwitchComponent
                break

            case root.editNetworksViewIndex:
                priv.backButtonName = root.networksSectionTitle
                root.sectionTitle = qsTr("Edit %1").arg(
                            (editNetwork.network && editNetwork.network.chainName) ?
                                editNetwork.network.chainName : "")
                root.titleRowLeftComponentLoader.sourceComponent = networkIcon
                root.titleRowLeftComponentLoader.visible = true
                root.titleLayout.spacing = 12
                break

            case root.accountViewIndex:
                priv.backButtonName = root.walletSectionTitle
                root.sectionTitle = ""
                break

            case root.accountOrderViewIndex:
                priv.backButtonName = root.walletSectionTitle
                root.sectionTitle = qsTr("Edit account order")
                root.stickTitleRowComponentLoader = true
                break

            case root.manageTokensViewIndex:
                priv.backButtonName = root.walletSectionTitle
                root.sectionTitle = qsTr("Manage tokens")
                root.stickTitleRowComponentLoader = true
                break

            case root.savedAddressesViewIndex:
                priv.backButtonName = root.walletSectionTitle
                root.sectionTitle = qsTr("Saved addresses")
                root.titleRowComponentLoader.sourceComponent = addNewSavedAddressButtonComponent
                break
            }
        }

        MainView {
            id: main

            Layout.fillWidth: true
            Layout.fillHeight: false

            walletStore: root.walletStore
            emojiPopup: root.emojiPopup
            isKeycardEnabled: root.isKeycardEnabled

            onGoToNetworksView: priv.navigateToDetails(root.networksViewIndex)

            onGoToAccountView: (account) => {
                if (!!account && !!account.address) {
                    root.addressWasShownRequested(account.address)
                }

                root.walletStore.setSelectedAccount(account.address)
                root.walletStore.selectedAccount = Qt.binding(function() { return root.walletStore.accountsModule.selectedAccount })
                accountView.keyPair = Qt.binding(function() { return root.walletStore.accountsModule.selectedKeyPair })
                priv.navigateToDetails(root.accountViewIndex)
            }

            onGoToAccountOrderView: priv.navigateToDetails(root.accountOrderViewIndex)

            onRunRenameKeypairFlow: (model) => {
                renameKeypairPopup.keyUid = model.keyPair.keyUid
                renameKeypairPopup.name = model.keyPair.name
                renameKeypairPopup.accounts = model.keyPair.accounts
                renameKeypairPopup.active = true
            }
            onRunRemoveKeypairFlow: (model) => {
                removeKeypairPopup.name = model.keyPair.name
                removeKeypairPopup.keyUid = model.keyPair.keyUid
                removeKeypairPopup.accounts= model.keyPair.accounts
                removeKeypairPopup.migratedToColdWallet = model.keyPair.migratedToColdWallet
                removeKeypairPopup.active = true
            }
            onRunMoveKeypairToKeycardFlow: (model) => {
                                               Global.openKeycardManagementPopup(Constants.keycard.flow.moveKeyPair,
                                                                                 model.keyPair.keyUid,
                                                                                 "",
                                                                                 "",
                                                                                 "[]")
                                           }
            onRunStopUsingKeycardFlow: (model) => {
                                           Global.openKeycardManagementPopup(Constants.keycard.flow.stopUsingKeycard,
                                                                             model.keyPair.keyUid,
                                                                             "",
                                                                             "",
                                                                             "[]")
                                       }
            onGoToManageTokensView: priv.navigateToDetails(root.manageTokensViewIndex)
            onGoToSavedAddressesView: priv.navigateToDetails(root.savedAddressesViewIndex)
        }

        NetworksView {
            id: networksView
            Layout.fillWidth: true
            Layout.fillHeight: true

            flatNetworks: root.networksStore.allNetworks
            areTestNetworksEnabled: root.networksStore.areTestNetworksEnabled

            onGoBack: priv.navigateToDetails(root.mainViewIndex)

            onEditNetwork: function (chainId) {
                editNetwork.network = ModelUtils.getByKey(root.networksStore.allNetworks, "chainId", chainId)
                priv.navigateToDetails(root.editNetworksViewIndex)
            }

            onSetNetworkActive: function (chainId, active) {
                root.networksStore.setNetworkActive(chainId, active)
            }
        }

        EditNetworkView {
            id: editNetwork
            Layout.fillHeight: true
            Layout.fillWidth: true
            networksModule: root.networksStore.networksModuleInst
            networkRPCChanged: root.networksStore.networkRPCChanged
            rpcProviders: root.networksStore.rpcProviders
            areTestNetworksEnabled: root.networksStore.areTestNetworksEnabled
            onEvaluateRpcEndPoint: (url, isMainUrl) => root.networksStore.evaluateRpcEndPoint(url, isMainUrl)
            onUpdateNetworkValues: (chainId, newMainRpcInput, newFailoverRpcUrl) => root.networksStore.updateNetworkEndPointValues(chainId, newMainRpcInput, newFailoverRpcUrl)
        }

        AccountOrderView {
            id: accountOrderView
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            walletStore: root.walletStore
            onGoBack: priv.navigateToDetails(root.mainViewIndex)
        }

        AccountView {
            id: accountView
            account: root.walletStore.selectedAccount
            walletStore: root.walletStore
            emojiPopup: root.emojiPopup
            userProfilePublicKey: walletStore.userProfilePublicKey
            activeNetworks: root.networksStore.activeNetworks
            onGoBack: priv.navigateToDetails(root.mainViewIndex)
            onVisibleChanged: {
                if (!visible && !!root.walletStore) {
                    root.walletStore.selectedAccount = null
                    keyPair = null
                }
            }
            onRunRenameKeypairFlow: {
                renameKeypairPopup.keyUid = keyPair.keyUid
                renameKeypairPopup.name = keyPair.name
                renameKeypairPopup.accounts = keyPair.accounts
                renameKeypairPopup.active = true
            }
            onRunRemoveKeypairFlow: {
                removeKeypairPopup.name = keyPair.name
                removeKeypairPopup.keyUid = keyPair.keyUid
                removeKeypairPopup.accounts= keyPair.accounts
                removeKeypairPopup.migratedToColdWallet = keyPair.migratedToColdWallet
                removeKeypairPopup.active = true
            }
            onRunImportMissingKeypairFlow: {
                root.walletStore.runKeypairImportPopup(keyPair.keyUid, Constants.keypairImportPopup.mode.selectImportMethod)
            }
            onRunMoveKeypairToKeycardFlow: {
                Global.openKeycardManagementPopup(Constants.keycard.flow.moveKeyPair,
                                                  keyPair.keyUid,
                                                  "",
                                                  "",
                                                  "[]")
            }
            onRunStopUsingKeycardFlow: {
                Global.openKeycardManagementPopup(Constants.keycard.flow.stopUsingKeycard,
                                                  keyPair.keyUid,
                                                  "",
                                                  "",
                                                  "[]")
            }
            onUpdateWatchAccountHiddenFromTotalBalance: (address, hideFromTotalBalance) => {
                root.walletStore.updateWatchAccountHiddenFromTotalBalance(address, hideFromTotalBalance)
            }
        }

        ManageTokensView {
            id: manageTokensView

            implicitHeight: root.availableHeight
            Layout.fillWidth: true

            tokensStore: root.tokensStore
            thirdpartyServicesEnabled: root.thirdpartyServicesEnabled
            tokenListUpdatedAt: tokensStore.tokenListUpdatedAt
            assetsController: root.assetsStore.assetsController
            collectiblesController: root.collectiblesStore.collectiblesController
            tokenListsModel: tokensStore.tokenListsModel
            allNetworks: root.networksStore.allNetworks
            baseWalletAssetsModel: root.assetsStore.groupedAccountAssetsModel
            baseWalletCollectiblesModel: root.collectiblesStore.allCollectiblesModel
            getCurrencyAmount: function (balance, key) {
                return RootStore.currencyStore.getCurrencyAmount(balance, key)
            }

            getCurrentCurrencyAmount: function (balance) {
                return RootStore.currencyStore.getCurrentCurrencyAmount(balance)
            }
        }

        SavedAddressesView {
            id: savedAddressesView

            contactsStore: root.contactsStore
            networkConnectionStore: root.networkConnectionStore
            networksStore: root.networksStore

            onSendToAddressRequested: {
                Global.sendToRecipientRequested(address)
            }
        }

        Component {
            id: addNewAccountButtonComponent
            StatusButton {
                objectName: "settings_Wallet_MainView_AddNewAccountButton"
                text: qsTr("Add new account")
                onClicked: root.walletStore.runAddAccountPopup()
            }
        }

        Component {
            id: toggleTestnetModeSwitchComponent

            StatusSwitch {
                id: testnetSwitch
                objectName: "testnetModeSwitch"
                text: qsTr("Testnet mode")
                leftSide: false
                checked: root.networksStore.areTestNetworksEnabled
                onToggled:{
                    checked = Qt.binding(() => root.networksStore.areTestNetworksEnabled)
                    Global.openTestnetPopup()
                }
            }
        }

        Component {
            id: addNewSavedAddressButtonComponent

            StatusButton {
                objectName: "addNewSavedAddressButton"
                text: qsTr("Add new address")
                onClicked: {
                    Global.openAddEditSavedAddressesPopup({})
                }
            }
        }

        Component {
            id: networkIcon
            StatusRoundedImage {
                width: 28
                height: 28
                image.source: Assets.svg(!!editNetwork.network && !!editNetwork.network.iconUrl ? editNetwork.network.iconUrl: "")
                image.fillMode: Image.PreserveAspectCrop
            }
        }

        Loader {
            id: renameKeypairPopup
            active: false

            property string keyUid
            property string name
            property var accounts

            sourceComponent: RenameKeypairPopup {
                accountsModule: root.walletStore.accountsModule
                keyUid: renameKeypairPopup.keyUid
                name: renameKeypairPopup.name
                accounts: renameKeypairPopup.accounts

                onClosed: {
                    renameKeypairPopup.active = false
                }
            }

            onLoaded: {
                renameKeypairPopup.item.open()
            }
        }

        Loader {
            id: removeKeypairPopup
            active: false

            property string name
            property string keyUid
            property var accounts
            property bool migratedToColdWallet

            sourceComponent: RemoveKeypairPopup {
                name: removeKeypairPopup.name
                relatedAccounts: removeKeypairPopup.accounts
                onClosed: removeKeypairPopup.active = false
                onConfirmClicked: {
                    if (removeKeypairPopup.migratedToColdWallet) {
                        root.walletStore.deleteKeypair(removeKeypairPopup.keyUid, "")
                        removeKeypairPopup.active = false
                        return
                    }
                    root.walletStore.authenticateLoggedInUser(priv.removeKeypairIdentifier)
                }
            }

            onLoaded: {
                const loggedInUserAuthenticated = (requestedBy, password, pin, keyUid, keycardUid) => {
                    if (priv.removeKeypairIdentifier !== requestedBy || password === "") {
                        return
                    }
                    root.walletStore.deleteKeypair(removeKeypairPopup.keyUid, password)
                    removeKeypairPopup.active = false
                }

                root.walletStore.loggedInUserAuthenticated.connect(loggedInUserAuthenticated)
                removeKeypairPopup.item.open()
            }
        }

        Connections {
            target: root.walletStore.walletModule

            function onDisplayKeypairImportPopup() {
                keypairImport.active = true
            }
            function onDestroyKeypairImportPopup() {
                keypairImport.active = false
            }
        }


        Loader {
            id: keypairImport
            active: false

            sourceComponent: KeypairImportPopup {
                store.keypairImportModule: root.walletStore.walletModule.keypairImportModule
            }

            onLoaded: {
                keypairImport.item.open()
            }
        }
    }

    Component.onCompleted: {
        root.titleRowComponentLoader.sourceComponent = addNewAccountButtonComponent
    }
}
