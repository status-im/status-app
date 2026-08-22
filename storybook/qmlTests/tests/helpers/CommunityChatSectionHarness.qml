import QtQuick

import utils

import Models

import shared.stores as SharedStores
import shared.stores.send as SendStores

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores.Messaging as MessagingStores

import mainui.adaptors
import mainui.sectionLoaders

/*
   Shared QmlTests harness: a fully-wired CommunityChatLoader against
   CommunitySectionMock and stub stores. Configure `mock`, flip
   `loader.active`, and drive the section through `loader.item`.
*/
Item {
    id: root

    readonly property alias mock: mock
    readonly property alias loader: harnessLoader

    function findChildByTypePrefix(item, prefix) {
        if (!item)
            return null
        if (item.toString().indexOf(prefix) === 0)
            return item
        const list = item.children
        for (let i = 0; i < list.length; ++i) {
            const found = findChildByTypePrefix(list[i], prefix)
            if (found)
                return found
        }
        return null
    }

    function findAllByTypePrefix(item, prefix, out) {
        if (!item)
            return out
        if (item.toString().indexOf(prefix) === 0)
            out.push(item)
        const list = item.children
        for (let i = 0; i < list.length; ++i)
            findAllByTypePrefix(list[i], prefix, out)
        return out
    }

    CommunitySectionMock { id: mock }

    AppStores.RootStore { id: appRootStoreMock }
    AppStores.ContactsStore { id: contactsStoreMock }
    AppStores.AccountSettingsStore {
        id: accountSettingsStoreMock
        showUsersList: true
    }
    AppStores.FeatureFlagsStore { id: featureFlagsStoreMock }
    SharedStores.RootStore { id: sharedRootStoreMock }
    SharedStores.CurrenciesStore { id: currenciesStoreMock }
    SharedStores.CommunityTokensStore { id: communityTokensStoreMock }
    SharedStores.NetworkConnectionStore { id: networkConnectionStoreMock }
    SharedStores.NetworksStore { id: networksStoreMock }
    SendStores.TransactionStore { id: transactionStoreMock }
    WalletStores.TokensStore { id: tokensStoreMock }
    WalletStores.WalletAssetsStore { id: walletAssetsStoreMock }
    ProfileStores.AdvancedStore { id: advancedStoreMock }
    CommunitiesStores.CommunitiesStore { id: communitiesStoreMock }
    MessagingStores.MessagingRootStore { id: messagingRootStoreMock }
    ChatStores.CreateChatPropertiesStore { id: createChatPropertiesStoreMock }
    ContactsModelAdaptor {
        id: contactsAdaptorMock
        allContacts: ListModel {}
    }

    Item {
        visible: false
        Loader { id: emojiPopupLoaderMock; active: false }
        Loader { id: stickersPopupLoaderMock; active: false }
    }

    Loader {
        id: harnessLoader
        anchors.fill: parent
        active: false

        sourceComponent: CommunityChatLoader {
            active: true

            rootStore: appRootStoreMock
            contactsStore: contactsStoreMock
            accountSettingsStore: accountSettingsStoreMock
            featureFlagsStore: featureFlagsStoreMock
            sharedRootStore: sharedRootStoreMock
            currencyStore: currenciesStoreMock
            communityTokensStore: communityTokensStoreMock
            networkConnectionStore: networkConnectionStoreMock
            networksStore: networksStoreMock
            transactionStore: transactionStoreMock
            tokensStore: tokensStoreMock
            walletAssetsStore: walletAssetsStoreMock
            advancedStore: advancedStoreMock
            communitiesStore: communitiesStoreMock
            messagingRootStore: messagingRootStoreMock
            createChatPropertiesStore: createChatPropertiesStoreMock
            contactsAdaptor: contactsAdaptorMock
            popupHandler: null
            emojiPopupLoader: emojiPopupLoaderMock
            stickersPopupLoader: stickersPopupLoaderMock
            sectionId: mock.communityId
            sectionItemModel: mock.sectionItemModel
            createChatViewOpened: false
            isPortraitMode: false
        }
    }
}
