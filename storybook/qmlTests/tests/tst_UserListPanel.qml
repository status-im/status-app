import QtQuick
import QtTest

import AppLayouts.Chat.panels

import StatusQ.Core.Utils as SQUtils

import utils

/*
 Perf regression guard: chat-switch profile showed the members panel fully
 re-sorting the community members model in QML (SFPM RoleSorter + StringSorter,
 881ms on a low-end device). The members model now arrives pre-sorted from Nim
 (online first, then name), so the panel must render rows in source order and
 never re-sort them.
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

        // The model owns the order (sorted in Nim): rows must come out exactly
        // as fed in, deliberately non-alphabetical here — a QML sorter sneaking
        // back in would flip this to ["Alice", "bob", "charlie"].
        function test_panelShowsRowsInModelOrder() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            const listView = memberListView(panel)
            tryCompare(listView, "count", 3)

            const order = []
            for (let i = 0; i < listView.count; i++)
                order.push(SQUtils.ModelUtils.get(listView.model, i, "preferredDisplayName"))
            compare(order, ["charlie", "Alice", "bob"])
        }

        function test_visiblePanelShowsRowsImmediately() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            tryCompare(memberListView(panel), "count", 3)
        }

        function test_searchFiltersMembers() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            const listView = memberListView(panel)
            tryCompare(listView, "count", 3)

            mouseClick(findChild(panel, "membersSearchButton"))
            const searchBox = findChild(panel, "membersSearchBox")
            tryVerify(() => searchBox.visible)

            searchBox.text = "ali"
            tryCompare(listView, "count", 1)
            compare(SQUtils.ModelUtils.get(listView.model, 0, "preferredDisplayName"),
                    "Alice")

            searchBox.text = ""
            tryCompare(listView, "count", 3)
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

    }
}
