import QtQuick
import QtTest
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import AppLayouts.Chat.panels

Item {
    id: root
    width: 420
    height: 720

    ListModel { id: threads }
    ListModel { id: participants }

    Component {
        id: panelComponent
        ChatInfoPanel {
            anchors.fill: parent
            onTabRequested: tab => requestedTab = tab
            threadsModel: threads
            membersContent: Component { Item {} }
            pinsContent: Component { Item {} }
        }
    }

    SignalSpy { id: openSpy; signalName: "openThreadRequested" }
    SignalSpy { id: loadSpy; signalName: "loadThreadsRequested" }

    TestCase {
        name: "ChatInfoPanel"
        when: windowShown
        property var panel

        function init() {
            threads.clear()
            for (const entry of [
                { key: "older", title: "Design tokens", timestamp: 10 },
                { key: "newer", title: "Roadmap", timestamp: 20 }
            ]) {
                threads.append({
                    key: entry.key, originalMessageId: "parent-" + entry.key,
                    archived: false,
                    title: entry.title, lastMessageTimestamp: entry.timestamp,
                    messagesCount: 2, notificationCount: 1, participantsCount: 0, participantsModel: participants,
                    lastMessageSenderName: "Alice", lastMessageSenderImage: "",
                    lastMessageSenderColorId: 0, lastMessageText: "Latest reply"
                })
            }
            panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            loadSpy.target = panel
            loadSpy.clear()
            openSpy.target = panel
            openSpy.clear()
        }

        function test_tabsFitWithoutScrolling_data() {
            const cases = []
            for (const width of [300, 640])
                for (const members of [true, false])
                    for (const threads of [true, false])
                        cases.push({ tag: `${width}-${members}-${threads}`, width, members, threads })
            return cases
        }

        function test_tabsFitWithoutScrolling(data) {
            const previousWidth = root.width
            try {
                root.width = data.width
                panel.membersAvailable = data.members
                panel.threadsEnabled = data.threads
                const tabs = findChild(panel, "chatInfoTabs")
                const buttons = [findChild(panel, "chatInfoMembersTab"),
                                 findChild(panel, "chatInfoThreadsTab"),
                                 findChild(panel, "chatInfoPinsTab")]
                const visibleButtons = buttons.filter(button => button.visible)
                verify(waitForPolish(tabs.contentItem))
                tryVerify(() => Math.abs(tabs.contentItem.contentWidth - tabs.availableWidth) < 1)
                compare(tabs.contentItem.contentX, 0)
                for (const button of visibleButtons) {
                    verify(Math.abs(button.width - tabs.availableWidth / visibleButtons.length) < 1)
                    mouseClick(button)
                    compare(panel.currentTab, buttons.indexOf(button))
                    compare(tabs.contentItem.contentX, 0)
                }
                mouseDrag(tabs, tabs.width / 2, tabs.height / 2, -40, 0)
                compare(tabs.contentItem.contentX, 0)
            } finally {
                root.width = previousWidth
            }
        }

        function test_tabsAndSearchReset() {
            verify(waitForPolish(panel))
            const headerPosition = panel.headerContent.mapToItem(panel, 0, 0)
            compare(headerPosition.x, Theme.padding)
            compare(headerPosition.y, Theme.padding)
            compare(panel.headerContent.width, panel.width - 2 * Theme.padding)
            compare(panel.currentTab, ChatInfoPanel.Members)
            const search = findChild(panel, "chatInfoSearchBox")
            verify(!search.visible)
            mouseClick(findChild(panel, "membersSearchButton"))
            tryCompare(search, "visible", true)
            search.text = "Alice"
            mouseClick(findChild(panel, "chatInfoThreadsTab"))
            compare(panel.currentTab, ChatInfoPanel.Threads)
            tryCompare(loadSpy, "count", 1)
            compare(search.text, "")
            verify(!search.visible)
            mouseClick(findChild(panel, "membersSearchButton"))
            search.text = "road"
            const list = findChild(panel, "chatInfoThreadsList")
            tryCompare(list, "count", 1)
            compare(SQUtils.ModelUtils.get(list.model, 0, "key"), "newer")
            keyClick(Qt.Key_Escape)
            tryCompare(search, "visible", false)
            compare(search.text, "")
            tryCompare(list, "count", 2)
        }

        function test_tabAccessibleNames() {
            compare(findChild(panel, "chatInfoMembersTab").Accessible.name, qsTr("Members"))
            compare(findChild(panel, "chatInfoThreadsTab").Accessible.name, qsTr("Threads"))
            compare(findChild(panel, "chatInfoPinsTab").Accessible.name, qsTr("Pins"))
        }

        function test_activityOrderUpdatesAndNavigation() {
            panel.requestedTab = ChatInfoPanel.Threads
            const list = findChild(panel, "chatInfoThreadsList")
            tryCompare(list, "count", 2)
            compare(SQUtils.ModelUtils.get(list.model, 0, "key"), "newer")
            threads.setProperty(0, "lastMessageTimestamp", 30)
            tryCompare(list.itemAtIndex(0), "threadId", "older")
            verify(waitForPolish(panel))
            const card = list.itemAtIndex(0)
            mouseClick(card, card.width / 2, card.height / 2)
            compare(openSpy.count, 1)
            compare(openSpy.signalArguments[0][0], "older")
        }

        function test_archivedThreadRemainsDiscoverableAndOpenable() {
            threads.setProperty(1, "archived", true)
            panel.requestedTab = ChatInfoPanel.Threads
            const list = findChild(panel, "chatInfoThreadsList")
            verify(!!list)
            tryCompare(list, "count", 2)
            mouseClick(findChild(panel, "membersSearchButton"))
            const search = findChild(panel, "chatInfoSearchBox")
            verify(!!search)
            search.text = "road"
            tryCompare(list, "count", 1)
            tryVerify(() => !!list.itemAtIndex(0))
            verify(waitForPolish(panel))
            const card = list.itemAtIndex(0)
            compare(card.threadId, "newer")
            mouseClick(card, card.width / 2, card.height / 2)
            tryCompare(openSpy, "count", 1)
            compare(openSpy.signalArguments[0][0], "newer")
            compare(threads.get(1).archived, true)
        }

        function test_directMessageAndFeatureFlag() {
            panel.membersAvailable = false
            panel.reset()
            compare(panel.currentTab, ChatInfoPanel.Threads)
            verify(!findChild(panel, "chatInfoMembersTab").visible)
            panel.threadsEnabled = false
            panel.reset()
            compare(panel.currentTab, ChatInfoPanel.Pins)
            verify(!findChild(panel, "chatInfoThreadsTab").visible)
        }

        function test_loadingFailureAndRetry() {
            panel.requestedTab = ChatInfoPanel.Threads
            panel.threadsLoading = true
            verify(!findChild(panel, "chatInfoThreadsList").visible)
            compare(findChild(panel, "chatInfoThreadsState").text, qsTr("Loading threads..."))
            panel.threadsLoading = false
            panel.threadsError = true
            compare(findChild(panel, "chatInfoThreadsState").text, qsTr("Couldn't load threads"))
            loadSpy.clear()
            mouseClick(findChild(panel, "chatInfoThreadsRetry"))
            compare(loadSpy.count, 1)
        }

        function test_directMessageSwitchLoadsThreadsOnce() {
            panel.membersAvailable = false
            tryCompare(loadSpy, "count", 1)
            loadSpy.clear()
            panel.chatKey = "another-direct-message"
            compare(panel.currentTab, ChatInfoPanel.Threads)
            tryCompare(loadSpy, "count", 1)
        }

        function test_chatSwitchResetsSearchAndTab() {
            panel.requestedTab = ChatInfoPanel.Threads
            mouseClick(findChild(panel, "membersSearchButton"))
            findChild(panel, "chatInfoSearchBox").text = "road"
            panel.chatKey = "another-chat"
            compare(panel.currentTab, ChatInfoPanel.Members)
            compare(panel.searchText, "")
            verify(!findChild(panel, "chatInfoSearchBox").visible)
        }
    }
}
