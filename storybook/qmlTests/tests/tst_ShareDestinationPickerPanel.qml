import QtQuick
import QtTest

import StatusQ.Core.Utils

import mainui

Item {
    id: root

    width: 500
    height: 600

    Component {
        id: testComponent

        ShareDestinationPickerPanel {
            anchors.fill: parent
        }
    }

    Component {
        id: destinationsModelComponent

        ListModel {
            readonly property var data: [
                {
                    chatId: "chat-design-group",
                    name: "Design crew",
                    color: "#7cda00",
                    colorId: 2,
                    icon: "",
                    emoji: "🎨",
                    sectionId: "personal-section",
                    sectionName: "Chat"
                },
                {
                    chatId: "channel-general",
                    name: "general",
                    color: "#887af9",
                    colorId: 4,
                    icon: "",
                    emoji: "",
                    sectionId: "community-1",
                    sectionName: "CryptoKitties"
                },
                {
                    chatId: "chat-alice",
                    name: "Alice",
                    color: "#ff7d46",
                    colorId: 1,
                    icon: "",
                    emoji: "",
                    sectionId: "personal-section",
                    sectionName: "Chat"
                }
            ]

            Component.onCompleted: append(data)
        }
    }

    SignalSpy {
        id: destinationPickedSpy
        signalName: "destinationPicked"
    }

    SignalSpy {
        id: cancelRequestedSpy
        signalName: "cancelRequested"
    }

    TestCase {
        name: "ShareDestinationPickerPanelTest"
        when: windowShown

        function init() {
            destinationPickedSpy.clear()
            cancelRequestedSpy.clear()
        }

        function createPicker() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const picker = createTemporaryObject(testComponent, root,
                                                 { model: sourceModel })
            destinationPickedSpy.target = picker
            cancelRequestedSpy.target = picker
            waitForRendering(picker)
            return picker
        }

        function test_listsAllDestinations() {
            const picker = createPicker()
            const listView = findChild(picker, "shareDestinationPickerListView")
            verify(listView)
            compare(listView.count, 3)
        }

        function test_searchFiltersAcrossDestinations() {
            const picker = createPicker()
            const listView = findChild(picker, "shareDestinationPickerListView")
            const searchBox = findChild(picker, "shareDestinationPickerSearchBox")
            verify(searchBox)

            searchBox.text = "ali"
            tryCompare(listView, "count", 1)
            compare(ModelUtils.get(listView.model, 0).name, "Alice")

            // also matches the community (section) name
            searchBox.text = "CryptoKit"
            tryCompare(listView, "count", 1)
            compare(ModelUtils.get(listView.model, 0).name, "general")

            searchBox.text = ""
            tryCompare(listView, "count", 3)
        }

        function test_pickingDestinationEmitsIntent() {
            const picker = createPicker()
            const delegate = findChild(picker, "shareDestinationDelegate_general")
            verify(delegate)

            mouseClick(delegate)

            compare(destinationPickedSpy.count, 1)
            compare(destinationPickedSpy.signalArguments[0][0], "community-1")
            compare(destinationPickedSpy.signalArguments[0][1], "channel-general")
            compare(destinationPickedSpy.signalArguments[0][2], "general")
        }

        function test_cancelEmitsIntent() {
            const picker = createPicker()
            const cancelButton = findChild(picker, "shareDestinationPickerCancelButton")
            verify(cancelButton)

            mouseClick(cancelButton)

            compare(cancelRequestedSpy.count, 1)
            compare(destinationPickedSpy.count, 0)
        }
    }
}
