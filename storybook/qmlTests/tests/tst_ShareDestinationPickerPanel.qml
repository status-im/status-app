import QtQuick
import QtTest

import StatusQ.Core.Utils

import utils
import mainui

Item {
    id: root
    width: 360
    height: 800

    Component {
        id: pickerComponent
        ShareDestinationPickerPanel {
            anchors.fill: parent
            text: "https://youtu.be/d3wHC956WLk"
        }
    }

    Component {
        id: modelComponent
        ListModel {
            readonly property var data: [
                { chatId: "0x04alice", name: "Alice", color: "", colorId: 1, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: 1, membersCount: 0, onlineStatus: 1 },
                { chatId: "channel-pets", name: "pets", color: "#887af9", colorId: 4, icon: "", emoji: "🐶", sectionId: "community-1", sectionName: "Status", chatType: 6, membersCount: 0, onlineStatus: 0 },
                { chatId: "group-travel", name: "Travel Days", color: "#7cda00", colorId: 2, icon: "", emoji: "🏔️", sectionId: "personal", sectionName: "Chat", chatType: 3, membersCount: 5, onlineStatus: 0 },
                { chatId: "channel-feedback", name: "feedback-desktop", color: "#887af9", colorId: 4, icon: "", emoji: "🖥️", sectionId: "community-1", sectionName: "Status", chatType: 6, membersCount: 0, onlineStatus: 0 }
            ]
            Component.onCompleted: append(data)
        }
    }

    SignalSpy { id: sendSpy; signalName: "sendRequested" }
    SignalSpy { id: cancelSpy; signalName: "cancelRequested" }

    TestCase {
        name: "ShareDestinationPickerPanel"
        when: windowShown

        function init() { sendSpy.clear(); cancelSpy.clear() }

        function tabs(picker) { return findChild(picker, "shareDestinationPickerTabs") }

        function currentList(picker) {
            const loader = tabs(picker).itemAt(tabs(picker).currentIndex)
            return loader ? loader.item : null
        }

        function createPicker(props = {}) {
            const model = createTemporaryObject(modelComponent, root)
            const picker = createTemporaryObject(pickerComponent, root, Object.assign({ model: model }, props))
            sendSpy.target = picker
            cancelSpy.target = picker
            tryVerify(() => currentList(picker) !== null)
            waitForRendering(picker)
            return picker
        }

        function switchTab(picker, tab) {
            findChild(picker, "shareDestinationPickerTabBar").currentIndex = tab
            tryCompare(tabs(picker), "currentIndex", tab)
            waitForPagesToSettle(picker, tab)
            tryVerify(() => currentList(picker) !== null)
        }

        // The SwipeView glides to the target page (the brief's mandated
        // "pill catches up" feel); wait for that glide to finish before a
        // test interacts with the destination page, or a click can land
        // mid-transition.
        function waitForPagesToSettle(picker, tab) {
            tryVerify(() => {
                const view = tabs(picker).contentItem
                const tabBar = findChild(picker, "shareDestinationPickerTabBar")
                return !view.moving && Math.abs(tabBar.position - tab) < 0.01
            })
        }

        function test_allTabListsEverythingAndSendDisabledUntilSelection() {
            const picker = createPicker()
            compare(currentList(picker).count, 4)
            compare(picker.selectedCount, 0)
            verify(!findChild(picker, "statusChatInputSendButton").enabled)
        }

        function test_tickingAcrossTabsAccumulatesAndSendsInModelOrder() {
            const picker = createPicker()
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_group-travel"))
            switchTab(picker, ShareDestinationTabBar.Tab.Communities)
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_channel-pets"))
            compare(picker.selectedCount, 2)
            const toggle = findChild(picker, "shareDestinationPickerSelectedToggle")
            tryVerify(() => toggle.visible)
            mouseClick(toggle)
            // selected-only mode jumps back to All and narrows it to the selection
            tryCompare(tabs(picker), "currentIndex", ShareDestinationTabBar.Tab.All)
            waitForPagesToSettle(picker, ShareDestinationTabBar.Tab.All)
            tryCompare(currentList(picker), "count", 2)
            verify(findChild(picker, "shareDestinationPickerTabBar").visible)
            const sendButton = findChild(picker, "statusChatInputSendButton")
            tryVerify(() => sendButton.enabled)
            mouseClick(sendButton)
            compare(sendSpy.count, 1)
            const destinations = sendSpy.signalArguments[0][0]
            compare(destinations.length, 2)
            compare(destinations[0].chatId, "channel-pets")      // model order, not tick order
            compare(destinations[0].sectionId, "community-1")
            compare(destinations[1].chatId, "group-travel")
            compare(StringUtils.plainText(sendSpy.signalArguments[0][1]), "https://youtu.be/d3wHC956WLk")
        }

        function test_searchAppliesToCurrentTabAcrossSwitches() {
            const picker = createPicker()
            mouseClick(findChild(picker, "shareDestinationPickerSearchToggle"))
            const searchBox = findChild(picker, "shareDestinationPickerSearchBox")
            tryVerify(() => searchBox.visible)
            searchBox.text = "fee"
            tryCompare(currentList(picker), "count", 1)
            switchTab(picker, ShareDestinationTabBar.Tab.Contacts)
            tryCompare(currentList(picker), "count", 0)
            switchTab(picker, ShareDestinationTabBar.Tab.Communities)
            tryCompare(currentList(picker), "count", 1)
            searchBox.text = ""
            tryCompare(currentList(picker), "count", 2)
        }

        function test_selectionDropsDestinationsThatLeaveTheModel() {
            const picker = createPicker()
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_group-travel"))
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_0x04alice"))
            compare(picker.selectedCount, 2)
            picker.model.remove(2)   // group-travel
            tryCompare(picker, "selectedCount", 1)
            mouseClick(findChild(picker, "statusChatInputSendButton"))
            compare(sendSpy.signalArguments[0][0].length, 1)
            compare(sendSpy.signalArguments[0][0][0].chatId, "0x04alice")
        }

        function test_resetClearsSelectionSearchAndComposer() {
            const picker = createPicker()
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_0x04alice"))
            mouseClick(findChild(picker, "shareDestinationPickerSearchToggle"))
            findChild(picker, "shareDestinationPickerSearchBox").text = "ali"
            findChild(picker, "statusChatInput").setText("typed")
            picker.text = "https://status.app"
            mouseClick(findChild(picker, "shareDestinationPickerSelectedToggle"))
            picker.reset()
            compare(picker.selectedCount, 0)
            verify(!findChild(picker, "shareDestinationPickerSearchBox").visible)
            compare(findChild(picker, "shareDestinationPickerTabBar").currentIndex, ShareDestinationTabBar.Tab.All)
            compare(findChild(picker, "statusChatInput").getPlainText(), "https://status.app")
            verify(findChild(picker, "shareDestinationPickerTabBar").visible)
        }

        function test_cancelEmitsIntent() {
            const picker = createPicker()
            mouseClick(findChild(picker, "shareDestinationPickerCancelButton"))
            compare(cancelSpy.count, 1)
            compare(sendSpy.count, 0)
        }

        function test_selectedToggleVisibilityFollowsSelection() {
            const picker = createPicker()
            const toggle = findChild(picker, "shareDestinationPickerSelectedToggle")
            verify(!toggle.visible)
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_0x04alice"))
            tryVerify(() => toggle.visible)
            mouseClick(toggle)
            tryCompare(currentList(picker), "count", 1)
            // unticking the last destination leaves selected-only mode
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_0x04alice"))
            tryVerify(() => !toggle.visible)
            tryCompare(currentList(picker), "count", 4)
        }

        function test_selectedModeNarrowsEveryTabAndJumpsToAll() {
            const picker = createPicker()
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_0x04alice"))
            mouseClick(findChild(currentList(picker), "shareDestinationDelegate_channel-pets"))
            switchTab(picker, ShareDestinationTabBar.Tab.Communities)
            const toggle = findChild(picker, "shareDestinationPickerSelectedToggle")
            mouseClick(toggle)
            tryCompare(tabs(picker), "currentIndex", ShareDestinationTabBar.Tab.All)
            waitForPagesToSettle(picker, ShareDestinationTabBar.Tab.All)
            tryCompare(currentList(picker), "count", 2)
            switchTab(picker, ShareDestinationTabBar.Tab.Contacts)
            tryCompare(currentList(picker), "count", 1)
            switchTab(picker, ShareDestinationTabBar.Tab.Groups)
            tryCompare(currentList(picker), "count", 0)
            // toggling off restores the full tab
            mouseClick(toggle)
            tryCompare(currentList(picker), "count", 1)   // the one group in the model
        }

        function test_tabBarAndPagesStayInSync() {
            const picker = createPicker()
            const tabBar = findChild(picker, "shareDestinationPickerTabBar")
            tabs(picker).currentIndex = ShareDestinationTabBar.Tab.Groups
            tryCompare(tabBar, "currentIndex", ShareDestinationTabBar.Tab.Groups)
            tryCompare(tabBar, "position", ShareDestinationTabBar.Tab.Groups)
            tabBar.currentIndex = ShareDestinationTabBar.Tab.All
            tryCompare(tabs(picker), "currentIndex", ShareDestinationTabBar.Tab.All)
        }

        function test_draggingPagesSlidesThePillAndSwitchesTab() {
            const picker = createPicker()
            const view = tabs(picker)
            const tabBar = findChild(picker, "shareDestinationPickerTabBar")
            // drag left by 60% of the width: SwipeView snaps to the next page
            mouseDrag(view, view.width * 0.8, view.height / 2, -view.width * 0.6, 0)
            tryCompare(view, "currentIndex", ShareDestinationTabBar.Tab.Contacts)
            tryCompare(tabBar, "currentIndex", ShareDestinationTabBar.Tab.Contacts)
            tryVerify(() => Math.abs(tabBar.position - ShareDestinationTabBar.Tab.Contacts) < 0.01)
        }
    }
}
