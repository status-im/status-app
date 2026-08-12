import QtQuick
import QtTest

import utils

import "helpers"

// The members panel is built once and shared across the section's channels.
// These tests pin that a switch onto a channel with its own members model
// drops back to MembersListSkeleton instead of showing the previous channel's
// members, that no member rows are built while that switch is in flight, and
// that a switch which keeps the same model object costs neither.
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

            // Test seam: the re-arm delay lives in the view's private object
            const internal = findChild(view, "chatViewInternal")
            verify(!!internal, "the chat view's private object must be reachable")

            const skeleton = findChild(loader, "membersPanelSkeleton")
            verify(!!skeleton, "the members panel must have its skeleton")
            tryVerify(() => !skeleton.visible, 20000,
                      "the members skeleton must clear once the panel is built")

            const list = findChild(loader, "userListPanel")
            verify(!!list)
            tryVerify(() => list.count > 0, 20000,
                      "the members list must be populated before the switch")

            return { loader, view, internal, skeleton, list }
        }

        // The permissioned channel carries its own members model, so landing on
        // it is the switch the latch exists for. A switch between unpermissioned
        // channels keeps the very same model object and must cost nothing.
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

        function test_membersSkeletonReturnsOnChannelSwitch() {
            const ctx = loadSectionWithMembers()
            // widen the re-arm window so the assertions do not race the timer
            ctx.internal.membersWireDelay = 2000

            const row = permissionedChannelRow(ctx.loader)
            verify(!!row, "the permissioned channel row must exist")
            mouseClick(row)
            tryVerify(() => mock.activeChatId === row.chatId, 5000)

            verify(ctx.skeleton.visible,
                   "switching to a channel with its own members model must bring "
                   + "the members skeleton back")

            ctx.internal.membersWireDelay = 10
            tryVerify(() => !ctx.skeleton.visible, 20000,
                      "the members skeleton must clear again after the switch")
            tryVerify(() => ctx.list.count > 0, 20000,
                      "the members list must repopulate after the switch")
        }

        function test_userListBuildsNoMemberRowsDuringChannelSwitch() {
            const ctx = loadSectionWithMembers()
            ctx.internal.membersWireDelay = 2000

            const row = permissionedChannelRow(ctx.loader)
            verify(!!row, "the permissioned channel row must exist")
            mouseClick(row)
            tryVerify(() => mock.activeChatId === row.chatId, 5000)

            compare(ctx.list.count, 0,
                    "the members list must hold no rows while the switch is in flight")
            compare(harness.findAllByTypePrefix(ctx.list.contentItem,
                                                "StatusMemberListItem_QMLTYPE", []).length, 0,
                    "no member delegate may be built while the switch is in flight")
        }

        // The dominant path: community channels without permissions all share
        // the section's members model, so the panel must not be torn down and
        // re-sorted on those switches.
        function test_membersPanelSurvivesSwitchWithUnchangedModel() {
            const ctx = loadSectionWithMembers()
            // long enough that an erroneous latch drop would still be down here
            ctx.internal.membersWireDelay = 2000

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
