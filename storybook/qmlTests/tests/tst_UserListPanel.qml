import QtQuick
import QtTest

import AppLayouts.Chat.panels

import StatusQ.Core.Utils as SQUtils

import utils

/*
 Perf regression guard: chat-switch profile showed the members panel fully
 re-sorting the community members model (SFPM RoleSorter + StringSorter,
 881ms on a low-end device) even while the right panel was hidden. A hidden
 panel must not materialize rows from usersModel; showing it populates the
 sorted list on demand.
*/
Item {
    id: root

    width: 300
    height: 600

    ListModel {
        id: membersModel

        function addMember(name, onlineStatus) {
            append({
                       pubKey: "0x0" + name,
                       compressedPubKey: "zx" + name,
                       preferredDisplayName: name,
                       displayName: name,
                       ensName: "",
                       alias: name + "-alias",
                       localNickname: "",
                       usesDefaultName: true,
                       isEnsVerified: false,
                       isContact: true,
                       isVerified: false,
                       isUntrustworthy: false,
                       isBlocked: false,
                       isCurrentUser: false,
                       memberRole: 0,
                       contactRequest: 0,
                       trustStatus: 0,
                       emojiHash: "[]",
                       icon: "",
                       colorId: 1,
                       onlineStatus: onlineStatus
                   })
        }
    }

    Component {
        id: panelComponent

        UserListPanel {
            anchors.fill: parent
            label: "Members"
            usersModel: membersModel
        }
    }

    Component {
        id: skeletonComponent

        MembersListSkeleton {
            anchors.fill: parent
        }
    }

    TestCase {
        name: "UserListPanel"
        when: windowShown

        function init() {
            membersModel.clear()
            // deliberately unsorted input: online statuses mixed, names mixed case
            membersModel.addMember("charlie", Constants.onlineStatus.inactive)
            membersModel.addMember("Alice", Constants.onlineStatus.online)
            membersModel.addMember("bob", Constants.onlineStatus.online)
        }

        function memberListView(panel) {
            const listView = findChild(panel, "userListPanel")
            verify(!!listView)
            return listView
        }

        function test_hiddenPanelMaterializesNoRows() {
            const panel = createTemporaryObject(panelComponent, root,
                                                {visible: false})
            verify(!!panel)
            wait(50)

            compare(memberListView(panel).count, 0,
                    "hidden panel must not pull rows from usersModel")
        }

        function test_showingPanelPopulatesSortedList() {
            const panel = createTemporaryObject(panelComponent, root,
                                                {visible: false})
            verify(!!panel)

            panel.visible = true
            const listView = memberListView(panel)
            tryCompare(listView, "count", 3)

            // online first (RoleSorter desc), then name case-insensitive
            const order = []
            for (let i = 0; i < listView.count; i++)
                order.push(SQUtils.ModelUtils.get(listView.model, i, "preferredDisplayName"))
            compare(order, ["Alice", "bob", "charlie"])
        }

        function test_visiblePanelShowsRowsImmediately() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            tryCompare(memberListView(panel), "count", 3)
        }

        // Chrome inversion creates panels without a visual parent until the
        // section chrome reparents them; that state must not sort either.
        function test_unparentedPanelMaterializesNoRows() {
            const panel = createTemporaryObject(panelComponent, null)
            verify(!!panel)
            wait(50)

            compare(memberListView(panel).count, 0,
                    "unparented panel must not pull rows from usersModel")
        }

        // The skeleton must look identical to the real panel header, so both
        // must render the SAME header component (search disabled while
        // loading).
        function test_panelAndSkeletonShareTheHeader() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            waitForRendering(panel)
            verify(!!findChild(panel, "membersPanelHeader"),
                   "real panel must use the shared header")
            const panelTitle = findChild(panel, "membersPanelTitle")
            tryVerify(() => panelTitle.visible, 5000,
                      "panel title must be visible at panel width")
            compare(panelTitle.text, "Members")

            const skeleton = createTemporaryObject(skeletonComponent, root)
            verify(!!skeleton)
            waitForRendering(skeleton)
            const skeletonHeader = findChild(skeleton, "membersPanelHeader")
            verify(!!skeletonHeader, "skeleton must use the shared header")
            verify(!findChild(skeletonHeader, "membersSearchButton").enabled,
                   "skeleton search must be disabled")
            tryVerify(() => findChild(skeleton, "membersPanelTitle").visible, 5000,
                      "skeleton title must be visible at panel width")
        }

        function test_searchButtonTogglesSearchBox() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            waitForRendering(panel)

            const searchBtn = findChild(panel, "membersSearchButton")
            verify(!!searchBtn)
            const searchBox = findChild(panel, "membersSearchBox")
            verify(!!searchBox)
            verify(!searchBox.visible)

            mouseClick(searchBtn)
            tryVerify(() => searchBox.visible)
        }

        function test_hidingPanelReleasesRows() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            const listView = memberListView(panel)
            tryCompare(listView, "count", 3)

            panel.visible = false
            tryCompare(listView, "count", 0)
        }
    }
}
