import QtQuick
import QtTest

import StatusQ.Core

import mainui
import mainui.adaptors

Item {
    id: root

    width: 400
    height: 400

    Component {
        id: publisherComponent

        ShareShortcutsPublisher {
            debounceIntervalMs: 0
        }
    }

    Component {
        id: adaptorComponent

        RecentPostableDestinationsAdaptor {}
    }

    Component {
        id: destinationsModelComponent

        ListModel {
            readonly property var data: [
                {
                    chatId: "chat-alice",
                    name: "Alice",
                    color: "#ff0000",
                    colorId: "",
                    icon: "",
                    emoji: "",
                    sectionId: "personal-section",
                    sectionName: "Chat",
                    lastMessageTimestamp: 500,
                    canPost: true
                },
                {
                    chatId: "chat-design-group",
                    name: "Design crew",
                    color: "#00ff00",
                    colorId: "",
                    icon: "",
                    emoji: "",
                    sectionId: "personal-section",
                    sectionName: "Chat",
                    lastMessageTimestamp: 900,
                    canPost: true
                },
                {
                    chatId: "channel-announcements",
                    name: "announcements",
                    color: "#0000ff",
                    colorId: "",
                    icon: "",
                    emoji: "",
                    sectionId: "community-1",
                    sectionName: "CryptoKitties",
                    lastMessageTimestamp: 1000,
                    canPost: false
                },
                {
                    chatId: "channel-general",
                    name: "general",
                    color: "#123456",
                    colorId: "",
                    icon: "",
                    emoji: "🐱",
                    sectionId: "community-1",
                    sectionName: "CryptoKitties",
                    lastMessageTimestamp: 700,
                    canPost: true
                },
                {
                    chatId: "chat-bob",
                    name: "Bob",
                    color: "#654321",
                    colorId: "",
                    icon: "",
                    emoji: "",
                    sectionId: "personal-section",
                    sectionName: "Chat",
                    lastMessageTimestamp: 300,
                    canPost: true
                },
                {
                    chatId: "chat-carol",
                    name: "Carol",
                    color: "#abcdef",
                    colorId: "",
                    icon: "",
                    emoji: "",
                    sectionId: "personal-section",
                    sectionName: "Chat",
                    lastMessageTimestamp: 200,
                    canPost: true
                }
            ]

            Component.onCompleted: append(data)
        }
    }

    Component {
        id: signalSpyComponent

        SignalSpy {}
    }

    TestCase {
        name: "ShareShortcutsPublisherTest"
        when: windowShown

        // Recency-sorted postable destinations for the publisher, exactly as
        // AppMain provides them (source model -> adaptor -> publisher).
        function createPublisher(props = {}) {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(adaptorComponent, root,
                                                  { sourceModel: sourceModel })
            const publisher = createTemporaryObject(
                                publisherComponent, root,
                                Object.assign({ model: adaptor.model }, props))
            const spy = createTemporaryObject(signalSpyComponent, root,
                                              { target: publisher,
                                                signalName: "publishRequested" })
            return { sourceModel, publisher, spy }
        }

        function lastPayload(spy) {
            return JSON.parse(spy.signalArguments[spy.count - 1][0])
        }

        function test_publishesTopFourPostableByRecency() {
            const { spy } = createPublisher()

            tryCompare(spy, "count", 1)

            const payload = lastPayload(spy)
            compare(payload.length, 4)
            compare(payload.map(e => e.id),
                    ["chat-design-group", "channel-general", "chat-alice", "chat-bob"])
            compare(payload[0].name, "Design crew")
            // non-postable "announcements" is never published
            verify(!payload.some(e => e.id === "channel-announcements"))
        }

        function test_republishesWhenRecencyChanges() {
            const { sourceModel, spy } = createPublisher()
            tryCompare(spy, "count", 1)

            // Carol (least recent, not in the top 4) gets a successful send:
            // she must enter the published set at the top.
            sourceModel.setProperty(5, "lastMessageTimestamp", 2000)

            tryCompare(spy, "count", 2)
            const payload = lastPayload(spy)
            compare(payload.map(e => e.id),
                    ["chat-carol", "chat-design-group", "channel-general", "chat-alice"])
        }

        function test_doesNotRepublishWhenPublishedSetUnchanged() {
            const { sourceModel, spy } = createPublisher()
            tryCompare(spy, "count", 1)

            // The most recent chat gets even more recent: order, names and
            // avatars are unchanged, so nothing new must be published.
            sourceModel.setProperty(1, "lastMessageTimestamp", 3000)
            wait(50)

            compare(spy.count, 1)
        }

        function test_publishesAllWhenFewerThanMaxDestinations() {
            const { sourceModel, spy } = createPublisher()
            tryCompare(spy, "count", 1)

            sourceModel.remove(4, 2) // drop Bob and Carol

            tryCompare(spy, "count", 2)
            const payload = lastPayload(spy)
            compare(payload.map(e => e.id),
                    ["chat-design-group", "channel-general", "chat-alice"])
        }

        function test_maxShortcutsCapsThePublishedSet() {
            const { spy } = createPublisher({ maxShortcuts: 2 })

            tryCompare(spy, "count", 1)
            const payload = lastPayload(spy)
            compare(payload.map(e => e.id), ["chat-design-group", "channel-general"])
        }

        function test_renamedDestinationIsRepublished() {
            const { sourceModel, spy } = createPublisher()
            tryCompare(spy, "count", 1)

            sourceModel.setProperty(0, "name", "Alice Cooper")

            tryCompare(spy, "count", 2)
            const payload = lastPayload(spy)
            compare(payload[2].name, "Alice Cooper")
        }

        function test_iconsAreRenderedIntoIconDirectory() {
            const iconDir = SystemUtils.shareShortcutsIconDirectory()
            const { spy } = createPublisher({ iconDirectory: iconDir })

            tryCompare(spy, "count", 1)
            const payload = lastPayload(spy)
            compare(payload.length, 4)
            for (let i = 0; i < payload.length; i++) {
                verify(payload[i].iconPath.startsWith(iconDir),
                       "iconPath should live in the icon directory: " + payload[i].iconPath)
            }
        }
    }
}
