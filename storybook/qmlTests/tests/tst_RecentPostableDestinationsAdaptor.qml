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
                    lastOwnMessageTimestamp: 400,
                    canPost: true
                },
                {
                    chatId: "chat-design-group",
                    name: "Design crew",
                    sectionId: "personal-section",
                    sectionName: "Chat",
                    lastMessageTimestamp: 900,
                    lastOwnMessageTimestamp: 100,
                    canPost: true
                },
                {
                    chatId: "channel-announcements",
                    name: "announcements",
                    sectionId: "community-1",
                    sectionName: "CryptoKitties",
                    lastMessageTimestamp: 1000,
                    lastOwnMessageTimestamp: 0,
                    canPost: false
                },
                {
                    chatId: "channel-general",
                    name: "general",
                    sectionId: "community-1",
                    sectionName: "CryptoKitties",
                    lastMessageTimestamp: 700,
                    lastOwnMessageTimestamp: 0,
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

        function test_ranksByOwnSendRecencyNotAnyMessageRecency() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            // the busy channel-general (lastMessageTimestamp 700, never sent
            // to) must not outrank the chats the user actually sent to
            compare(ModelUtils.get(model, 0).chatId, "chat-alice")
            compare(ModelUtils.get(model, 1).chatId, "chat-design-group")
            compare(ModelUtils.get(model, 2).chatId, "channel-general")
        }

        function test_neverSentToChatsFallBackToAnyMessageRecency() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            // both community channels have no own sends; once postable they
            // rank after all sent-to chats, ordered by any-message recency
            sourceModel.setProperty(2, "canPost", true)
            compare(model.rowCount(), 4)
            compare(ModelUtils.get(model, 2).chatId, "channel-announcements")
            compare(ModelUtils.get(model, 3).chatId, "channel-general")
        }

        function test_reactsToPostRightsChanges() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            // gaining post rights adds the destination
            sourceModel.setProperty(2, "canPost", true)
            compare(model.rowCount(), 4)

            // losing post rights removes it
            sourceModel.setProperty(2, "canPost", false)
            compare(model.rowCount(), 3)
            compare(ModelUtils.indexOf(model, "chatId", "channel-announcements"), -1)
        }

        function test_ownSendBumpsChatToTop() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            // a successful send updates both recency roles on the source model
            sourceModel.setProperty(3, "lastMessageTimestamp", 2000)
            sourceModel.setProperty(3, "lastOwnMessageTimestamp", 2000)
            compare(ModelUtils.get(model, 0).chatId, "channel-general")
            compare(ModelUtils.get(model, 1).chatId, "chat-alice")
        }

        function test_anyMessageRecencyChangeDoesNotOutrankSentToChats() {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(testComponent, root,
                                                  { sourceModel: sourceModel })
            const model = adaptor.model

            // someone else posting in the busy channel must not promote it
            sourceModel.setProperty(3, "lastMessageTimestamp", 5000)
            compare(ModelUtils.get(model, 0).chatId, "chat-alice")
            compare(ModelUtils.get(model, 1).chatId, "chat-design-group")
            compare(ModelUtils.get(model, 2).chatId, "channel-general")
        }
    }
}
