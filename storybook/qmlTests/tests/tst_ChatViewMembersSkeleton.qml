import QtQuick
import QtTest

import utils

import "helpers"

// The members panel loads asynchronously behind the section chrome's members
// skeleton (the loader-owned "rightPanelSkeleton" slot), which must cover the
// load and clear once the panel is ready. Channel switches — whether they keep
// the members model or swap it (permissioned channels) — must neither tear the
// panel down nor bring the skeleton back, because the model arrives pre-sorted
// from Nim and rebinding it is cheap.
Item {
    id: root

    width: 1000
    height: 700

    CommunityChatSectionHarness {
        id: harness
        anchors.fill: parent
    }

    TestCase {
        name: "ChatViewMembersSkeleton"
        when: windowShown

        readonly property var mock: harness.mock

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
            // One permissioned channel per category: only a switch that lands
            // on it hands the view a different members model, which is what
            // arms the latch
            mock.privateChannelsPerCategory = 1
            mock.messagesPerChannel = 20
            mock.install()
        }

        function cleanup() {
            harness.loader.active = false
            mock.uninstall()
        }

        // Loads the section and waits until the members panel is up: the
        // skeleton has cleared and the real list holds the mock's members.
        function loadSectionWithMembers() {
            harness.loader.active = true
            const loader = harness.loader.item
            verify(!!loader)
            tryVerify(() => loader.status === Loader.Ready, 120000)

            const view = harness.findChildByTypePrefix(loader, "ChatView")
            verify(!!view, "the section must load the paneled chat view")

            const skeleton = findChild(loader, "rightPanelSkeleton")
            verify(!!skeleton, "the chrome must have its members skeleton slot")
            tryVerify(() => !skeleton.active, 20000,
                      "the members skeleton must clear once the rows are built")

            const list = findChild(loader, "userListPanel")
            verify(!!list)
            tryVerify(() => list.count > 0, 20000,
                      "the members list must be populated before the switch")

            return { loader, view, skeleton, list }
        }

        // The permissioned channel carries its own members model, so landing on
        // it swaps the model under the panel. A switch between unpermissioned
        // channels keeps the very same model object.
        function permissionedChannelRow(loader) {
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const targetId = mock.firstPrivateChannelId()
            verify(!!targetId, "the mock must build a permissioned channel")

            const rows = harness.findAllByTypePrefix(lv.contentItem,
                                                     "StatusChatListItem_QMLTYPE", [])
            for (let i = 0; i < rows.length; ++i) {
                const row = rows[i]
                if (row.chatId === targetId && row.visible && row.height > 0)
                    return row
            }
            return null
        }

        function unpermissionedChannelRow(loader) {
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const gatedId = mock.firstPrivateChannelId()
            const rows = harness.findAllByTypePrefix(lv.contentItem,
                                                     "StatusChatListItem_QMLTYPE", [])
            for (let i = 0; i < rows.length; ++i) {
                const row = rows[i]
                if (row.chatId !== mock.activeChatId && row.chatId !== gatedId
                        && row.visible && row.height > 0)
                    return row
            }
            return null
        }

        // The skeleton covers the async members-panel load from the first
        // frame and clears once the panel is up, with the members populated.
        function test_membersSkeletonCoversSectionLoad() {
            harness.loader.active = true
            const loader = harness.loader.item
            verify(!!loader)

            // the chrome skeleton exists (and covers) from the first frame,
            // before the section view is even loaded — watch it from here
            const skeleton = findChild(loader, "rightPanelSkeleton")
            verify(!!skeleton)
            verify(skeleton.active,
                   "the members skeleton must cover the section load")

            tryVerify(() => !skeleton.active, 20000,
                      "the members skeleton must eventually clear")

            const list = findChild(loader, "userListPanel")
            verify(!!list)
            tryVerify(() => list.count > 0, 20000,
                      "the members list must populate once the skeleton clears")
        }

        // In portrait the chrome slides between panels and brackets the slide
        // with panelSwitchStarted/panelSwitchEnded. A panel that becomes
        // ready mid-slide must keep its skeleton until the end signal —
        // swapping mid-slide stutters the animation.
        function test_membersPanelPromotionWaitsOutPanelSwitch() {
            harness.loader.active = true
            const loader = harness.loader.item
            verify(!!loader)

            const chrome = findChild(loader, "sectionChrome")
            verify(!!chrome)
            const skeleton = findChild(loader, "rightPanelSkeleton")
            verify(!!skeleton)

            // a panel switch starts before the members panel is ready...
            chrome.panelSwitchStarted()

            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            verify(!!view)
            tryVerify(() => view.rightPanelReady, 20000,
                      "the members panel must become ready underneath")
            verify(skeleton.active,
                   "the skeleton must hold while the panel switch is in flight")

            chrome.panelSwitchEnded()
            tryVerify(() => !skeleton.active, 5000,
                      "the panel must swap in once the switch ends")
            const list = findChild(loader, "userListPanel")
            verify(!!list)
            tryVerify(() => list.count > 0)
        }

        // The panel is loaded only while shown: hiding the members list
        // discards it, and the next show re-incubates it behind the
        // skeleton, held until the rows are back.
        function test_membersPanelDiscardedWhenHidden() {
            const ctx = loadSectionWithMembers()

            ctx.view.showUsersList = false
            tryVerify(() => findChild(ctx.loader, "userListPanel") === null,
                      5000, "hiding the members panel must unload it")

            ctx.view.showUsersList = true
            verify(ctx.skeleton.active,
                   "re-showing the members panel must bring the skeleton up")

            tryVerify(() => !ctx.skeleton.active, 20000,
                      "the members skeleton must clear again after the re-show")

            const list = findChild(ctx.loader, "userListPanel")
            verify(!!list)
            tryVerify(() => list.count > 0, 20000,
                      "the members list must repopulate on re-show")
        }

        // Landing on a channel with its own members model swaps the model
        // under the live panel: the rows follow, the skeleton stays gone.
        function test_membersPanelSwapsModelWithoutSkeleton() {
            const ctx = loadSectionWithMembers()

            const row = permissionedChannelRow(ctx.loader)
            verify(!!row, "the permissioned channel row must exist")
            mouseClick(row)
            tryVerify(() => mock.activeChatId === row.chatId, 5000)

            verify(!ctx.skeleton.visible,
                   "a members-model swap must not bring the skeleton back")
            tryVerify(() => ctx.list.count > 0, 20000,
                      "the members list must repopulate after the switch")
        }

        // The dominant path: community channels without permissions all share
        // the section's members model, so the panel must not be torn down on
        // those switches.
        function test_membersPanelSurvivesSwitchWithUnchangedModel() {
            const ctx = loadSectionWithMembers()

            const before = ctx.list.count
            const row = unpermissionedChannelRow(ctx.loader)
            verify(!!row, "another unpermissioned channel row must exist")
            mouseClick(row)
            tryVerify(() => mock.activeChatId === row.chatId, 5000)

            verify(!ctx.skeleton.visible,
                   "a switch that keeps the same members model must not show the skeleton")
            compare(ctx.list.count, before,
                    "a switch that keeps the same members model must not drop the rows")
        }
    }
}
