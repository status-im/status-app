import QtQuick
import QtTest

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

// The members panel is built once and shared across the section's channels.
// These tests pin that a channel switch drops back to MembersListSkeleton
// instead of showing the previous channel's members, and that no member rows
// are built while the switch is in flight.
Item {
    id: root

    width: 1000
    height: 700

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
        id: harness
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

    TestCase {
        name: "ChatViewMembersSkeleton"
        when: windowShown

        function init() {
            mock.joined = true
            mock.memberRole = Constants.memberRole.none
            mock.amIBanned = false
            mock.requestToJoinState = Constants.RequestToJoinState.None
            mock.requiresTokenPermissionToJoin = false
            mock.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin = false
            mock.membersCount = 50
            mock.categoriesCount = 1
            mock.channelsPerCategory = 3
            mock.uncategorizedChannelsCount = 2
            mock.privateChannelsPerCategory = 0
            mock.messagesPerChannel = 20
            mock.install()
        }

        function cleanup() {
            harness.active = false
            mock.uninstall()
        }

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

        // Loads the section and waits until the members panel is up: the
        // skeleton has cleared and the real list holds the mock's members.
        function loadSectionWithMembers() {
            harness.active = true
            const loader = harness.item
            verify(!!loader)
            tryVerify(() => loader.status === Loader.Ready, 120000)

            const view = findChildByTypePrefix(loader, "ChatView")
            verify(!!view, "the section must load the paneled chat view")

            const skeleton = findChild(loader, "membersPanelSkeleton")
            verify(!!skeleton, "the members panel must have its skeleton")
            tryVerify(() => !skeleton.visible, 20000,
                      "the members skeleton must clear once the panel is built")

            const list = findChild(loader, "userListPanel")
            verify(!!list)
            tryVerify(() => list.count > 0, 20000,
                      "the members list must be populated before the switch")

            return { loader, view, skeleton, list }
        }

        function otherChannelRow(loader) {
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const rows = findAllByTypePrefix(lv.contentItem,
                                             "StatusChatListItem_QMLTYPE", [])
            for (let i = 0; i < rows.length; ++i) {
                const row = rows[i]
                if (row.chatId !== mock.activeChatId && row.visible && row.height > 0)
                    return row
            }
            return null
        }

        function test_membersSkeletonReturnsOnChannelSwitch() {
            const ctx = loadSectionWithMembers()
            // widen the re-arm window so the assertions do not race the timer
            ctx.view.membersWireDelay = 2000

            const row = otherChannelRow(ctx.loader)
            verify(!!row, "a non-active channel row must exist")
            mouseClick(row)
            tryVerify(() => mock.activeChatId === row.chatId, 5000)

            verify(ctx.skeleton.visible,
                   "switching channel must bring the members skeleton back")

            ctx.view.membersWireDelay = 10
            tryVerify(() => !ctx.skeleton.visible, 20000,
                      "the members skeleton must clear again after the switch")
            tryVerify(() => ctx.list.count > 0, 20000,
                      "the members list must repopulate after the switch")
        }

        function test_userListBuildsNoMemberRowsDuringChannelSwitch() {
            const ctx = loadSectionWithMembers()
            ctx.view.membersWireDelay = 2000

            const row = otherChannelRow(ctx.loader)
            verify(!!row, "a non-active channel row must exist")
            mouseClick(row)
            tryVerify(() => mock.activeChatId === row.chatId, 5000)

            compare(ctx.list.count, 0,
                    "the members list must hold no rows while the switch is in flight")
            compare(findAllByTypePrefix(ctx.list.contentItem,
                                        "StatusMemberListItem_QMLTYPE", []).length, 0,
                    "no member delegate may be built while the switch is in flight")
        }
    }
}
