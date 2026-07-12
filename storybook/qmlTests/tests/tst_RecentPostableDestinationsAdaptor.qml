import QtQuick
import QtTest

import StatusQ.Core.Utils

import mainui.adaptors

Item {
    id: root

    Component {
        id: testComponent

        RecentPostableDestinationsAdaptor {}
    }

    Component {
        id: destinationsModelComponent

        ListModel {
            readonly property var data: [
                {
                    chatId: "chat-alice",
                    name: "Alice",
                    sectionId: "personal-section",
                    sectionName: "Chat",
                    lastMessageTimestamp: 400,
                    canPost: true
                },
                {
                    chatId: "chat-design-group",
                    name: "Design crew",
                    sectionId: "personal-section",
                    sectionName: "Chat",
                    lastMessageTimestamp: 900,
                    canPost: true
                },
                {
                    chatId: "channel-announcements",
                    name: "announcements",
                    sectionId: "community-1",
                    sectionName: "CryptoKitties",
                    lastMessageTimestamp: 1000,
                    canPost: false
                },
                {
                    chatId: "channel-general",
                    name: "general",
                    sectionId: "community-1",
                    sectionName: "CryptoKitties",
                    lastMessageTimestamp: 700,
                    canPost: true
                }
            ]

            Component.onCompleted: append(data)
        }
    }

    TestCase {
        name: "RecentPostableDestinationsAdaptorTest"

        function test_filtersOutNonPostableDestinations() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            compare(model.rowCount(), 3)
            compare(ModelUtils.indexOf(model, "chatId", "channel-announcements"), -1)
        }

        function test_sortsByRecencyMostRecentFirst() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            compare(ModelUtils.get(model, 0).chatId, "chat-design-group")
            compare(ModelUtils.get(model, 1).chatId, "channel-general")
            compare(ModelUtils.get(model, 2).chatId, "chat-alice")
        }

        function test_reactsToPostRightsChanges() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            // gaining post rights adds the destination
            sourceModel.setProperty(2, "canPost", true)
            compare(model.rowCount(), 4)
            compare(ModelUtils.get(model, 0).chatId, "channel-announcements")

            // losing post rights removes it
            sourceModel.setProperty(2, "canPost", false)
            compare(model.rowCount(), 3)
            compare(ModelUtils.indexOf(model, "chatId", "channel-announcements"), -1)
        }

        function test_reactsToRecencyChanges() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            sourceModel.setProperty(0, "lastMessageTimestamp", 2000)
            compare(ModelUtils.get(model, 0).chatId, "chat-alice")
        }
    }
}
