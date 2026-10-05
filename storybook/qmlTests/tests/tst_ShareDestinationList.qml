import QtQuick
import QtTest

import StatusQ.Core.Utils

import utils
import mainui

Item {
    id: root
    width: 360
    height: 600

    Component {
        id: listComponent
        ShareDestinationList { anchors.fill: parent }
    }

    Component {
        id: selectionComponent
        ShareSelection {}
    }

    Component {
        id: modelComponent
        ListModel {
            readonly property var data: [
                { chatId: "0x04alice", name: "Alice", color: "", colorId: 1, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: 1, membersCount: 0, onlineStatus: 1 },
                { chatId: "group-travel", name: "Travel Days", color: "#7cda00", colorId: 2, icon: "", emoji: "🏔️", sectionId: "personal", sectionName: "Chat", chatType: 3, membersCount: 5, onlineStatus: 0 },
                { chatId: "channel-pets", name: "pets", color: "#887af9", colorId: 4, icon: "", emoji: "🐶", sectionId: "community-1", sectionName: "Status", chatType: 6, membersCount: 0, onlineStatus: 0 },
                { chatId: "channel-feedback", name: "feedback-desktop", color: "#887af9", colorId: 4, icon: "", emoji: "🖥️", sectionId: "community-1", sectionName: "Status", chatType: 6, membersCount: 0, onlineStatus: 0 }
            ]
            Component.onCompleted: append(data)
        }
    }

    SignalSpy { id: toggleSpy; signalName: "toggleRequested" }

    TestCase {
        name: "ShareDestinationList"
        when: windowShown

        function init() { toggleSpy.clear() }

        function create(props = {}) {
            const model = createTemporaryObject(modelComponent, root)
            const selection = createTemporaryObject(selectionComponent, root)
            const list = createTemporaryObject(listComponent, root,
                Object.assign({ model: model, selection: selection }, props))
            toggleSpy.target = list
            waitForRendering(list)
            return list
        }

        function test_allTabListsEveryDestinationInModelOrder() {
            const list = create()
            compare(list.count, 4)
            compare(ModelUtils.get(findChild(list, "shareDestinationListView").model, 0).chatId, "0x04alice")
        }

        function test_chatTypeFilterKeepsOnlyThatType() {
            const list = create({ chatTypeFilter: Constants.chatType.communityChat })
            compare(list.count, 2)
        }

        function test_searchFiltersOnNameAndSectionName() {
            const list = create()
            list.searchPhrase = "fee"
            tryCompare(list, "count", 1)
            list.searchPhrase = "Stat"
            tryCompare(list, "count", 2)
            list.searchPhrase = ""
            tryCompare(list, "count", 4)
        }

        function test_searchIgnoresLeadingHash() {
            const list = create()
            list.searchPhrase = "#fee"
            tryCompare(list, "count", 1)
        }

        function test_selectedOnlyFollowsSelectionInModelOrder() {
            const list = create({ selectedOnly: true })
            compare(list.count, 0)
            verify(findChild(list, "shareDestinationListEmptyText").visible)
            list.selection.toggle("channel-pets")
            list.selection.toggle("0x04alice")
            tryCompare(list, "count", 2)
            const view = findChild(list, "shareDestinationListView")
            compare(ModelUtils.get(view.model, 0).chatId, "0x04alice")
            compare(ModelUtils.get(view.model, 1).chatId, "channel-pets")
            list.selection.toggle("0x04alice")
            tryCompare(list, "count", 1)
        }

        function test_selectedOnlyEmptyTextTellsSelectionFromFilter() {
            const list = create({ selectedOnly: true })
            const emptyText = findChild(list, "shareDestinationListEmptyText")
            verify(emptyText.visible)
            compare(emptyText.text, "Nothing selected yet")
            list.selection.toggle("channel-pets")
            list.searchPhrase = "zzz"
            tryCompare(list, "count", 0)
            verify(emptyText.visible)
            compare(emptyText.text, list.emptyText)
        }

        function test_delegateCheckedReflectsSelection() {
            const list = create()
            const delegate = findChild(list, "shareDestinationDelegate_group-travel")
            verify(delegate)
            verify(!delegate.checked)
            list.selection.toggle("group-travel")
            tryCompare(delegate, "checked", true)
        }

        function test_untickedRowsDisableWhileSelectionIsFull() {
            const list = create()
            list.selection.maxCount = 1
            list.selection.toggle("0x04alice")
            waitForRendering(list)
            const ticked = findChild(list, "shareDestinationDelegate_0x04alice")
            const other = findChild(list, "shareDestinationDelegate_group-travel")
            verify(ticked.enabled)
            verify(!other.enabled)
            verify(!other.selectable)

            list.selection.toggle("0x04alice")
            waitForRendering(list)
            verify(other.enabled)
            verify(other.selectable)
        }

        function test_rowClickEmitsToggleRequestedWithoutMutatingSelection() {
            const list = create()
            mouseClick(findChild(list, "shareDestinationDelegate_group-travel"))
            compare(toggleSpy.count, 1)
            compare(toggleSpy.signalArguments[0][0], "group-travel")
            compare(list.selection.count, 0)
        }
    }
}
