import QtQml
import QtQuick

import StatusQ.Core.Theme

import utils

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.HomePage
import AppLayouts.Wallet
import AppLayouts.Wallet.stores as WalletStores

import mainui.adaptors

Loader {
    id: root

    required property AppStores.RootStore rootStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property ChatStores.RootStore rootChatStore
    required property ProfileStores.ProfileStore profileStore
    required property ProfileStores.PrivacyStore privacyStore

    required property ContactsModelAdaptor contactsAdaptor
    required property Loader dappsServiceLoader

    required property bool browserEnabled
    required property int syncingBadgeCount

    property real leftPanelWidthOverride: 0

    // Routes the navigation request that was previously dispatched via globalConns.
    signal appSectionRequested(int sectionType, var subsection, int subSubsection, var data)

    asynchronous: false

    Loader {
        id: adaptor
        active: root.active
        sourceComponent: HomePageAdaptor {
            id: homePageAdaptor

            readonly property bool sectionsLoaded: root.rootStore.sectionsLoaded

            sectionsBaseModel: sectionsLoaded ? root.rootStore.sectionsModel : null
            chatsBaseModel: sectionsLoaded ? root.rootChatStore.chatSectionModuleModel : null
            chatsSearchBaseModel: sectionsLoaded && !!root.rootStore.chatSearchModel ? root.rootStore.chatSearchModel : null
            walletsBaseModel: sectionsLoaded ? WalletStores.RootStore.accounts : null
            dappsBaseModel: root.dappsServiceLoader.active && root.dappsServiceLoader.item ? root.dappsServiceLoader.item.dappsModel : null

            showEnabledSectionsOnly: true
            marketEnabled: root.featureFlagsStore.marketEnabled
            browserEnabled: root.browserEnabled
            showDapps: false // SEE https://github.com/status-im/status-app/issues/19580

            syncingBadgeCount: root.syncingBadgeCount
            messagingBadgeCount: root.contactsAdaptor.pendingReceivedRequestContacts.count
            showBackUpSeed: !root.privacyStore.mnemonicBackedUp
            backUpSeedBadgeCount: root.profileStore.userDeclinedBackupBanner ? 0 : showBackUpSeed
            keycardEnabled: root.featureFlagsStore.keycardEnabled

            searchPhrase: root.item ? root.item.searchPhrase : ""

            profileId: root.profileStore.pubKey

            // no automatic propagation to QtObject, needs to be specified explicitely
            Theme.style: root.Theme.style
        }
        onLoaded: loadSection()
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.homeUrl))
    }

    function loadSection() {
        if (!root.active)
            return
        if (!!root.item)
            return
        if (source === QmlCompiler.homeUrl)
            return
        setSource(QmlCompiler.homeUrl, {
            objectName:             "homeContainer",
            visible:                false,
            homePageEntriesModel:   Qt.binding(() => adaptor.item?.homePageEntriesModel ?? null),
            sectionsModel:          Qt.binding(() => adaptor.item?.sectionsModel ?? null),
            pinnedModel:            Qt.binding(() => adaptor.item?.pinnedModel ?? null),
            leftPanelWidthOverride: Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onLoaded: {
        root.item.visible = true
    }

    onActiveChanged: loadSection()

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onItemActivated(key, sectionType, itemId) {
            adaptor.item.setTimestamp(key, new Date().valueOf())

            if (sectionType === -1) { // search
                const [sectionId, chatId] = key.split(";")
                root.rootStore.setActiveSectionChat(sectionId, chatId)
                return
            }

            if (sectionType === Constants.appSection.profile) {
                if (itemId == Constants.settingsSubsection.backUpSeed) {
                    Global.openBackUpSeedPopup()
                    return
                }
                if (itemId == Constants.settingsSubsection.signout) {
                    Global.quitAppRequested()
                    return
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

            root.appSectionRequested(sectionType, subsection, subSubsection, data)
        }

        function onItemPinRequested(key, pin) {
            adaptor.item.setPinned(key, pin)
            if (pin)
                adaptor.item.setTimestamp(key, new Date().valueOf())
        }

        function onDappDisconnectRequested(dappUrl) {
            root.dappsServiceLoader.dappDisconnectRequested(dappUrl)
        }
    }
}
