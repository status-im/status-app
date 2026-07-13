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
        id: donorComponent

        SendMessageIntentDonor {}
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
                    emoji: "🎨",
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
        name: "SendMessageIntentDonorTest"
        when: windowShown

        // Postable destinations for the donor, exactly as AppMain provides
        // them (source model -> adaptor -> donor).
        function createDonor(props = {}) {
            const sourceModel = createTemporaryObject(destinationsModelComponent, root)
            const adaptor = createTemporaryObject(adaptorComponent, root,
                                                  { sourceModel: sourceModel })
            const donor = createTemporaryObject(
                            donorComponent, root,
                            Object.assign({ model: adaptor.model }, props))
            const spy = createTemporaryObject(signalSpyComponent, root,
                                              { target: donor,
                                                signalName: "donationRequested" })
            return { sourceModel, donor, spy }
        }

        function test_sendDonatesTheDestination() {
            const { donor, spy } = createDonor()

            donor.donateForChat("chat-alice")

            tryCompare(spy, "count", 1)
            compare(spy.signalArguments[0][0], "chat-alice")
            compare(spy.signalArguments[0][1], "Alice")
            compare(spy.signalArguments[0][2], "") // no iconDirectory -> no avatar
        }

        function test_noDonationWithoutASend() {
            const { spy } = createDonor()

            wait(50)
            compare(spy.count, 0)
        }

        function test_unknownDestinationIsSkipped() {
            // A chat missing from the postable destinations model (e.g. no
            // longer postable) is never donated.
            const { donor, spy } = createDonor()

            donor.donateForChat("channel-announcements") // filtered: canPost false
            donor.donateForChat("chat-gone")

            wait(50)
            compare(spy.count, 0)
        }

        function test_sendBurstDonatesEachDestinationInOrder() {
            const { donor, spy } = createDonor()

            donor.donateForChat("chat-alice")
            donor.donateForChat("chat-design-group")

            tryCompare(spy, "count", 2)
            compare(spy.signalArguments[0][0], "chat-alice")
            compare(spy.signalArguments[1][0], "chat-design-group")
        }

        function test_avatarIsRenderedIntoIconDirectory() {
            const iconDir = SystemUtils.shareShortcutsIconDirectory()
            const { donor, spy } = createDonor({ iconDirectory: iconDir })

            donor.donateForChat("chat-alice")

            tryCompare(spy, "count", 1)
            compare(spy.signalArguments[0][0], "chat-alice")
            verify(spy.signalArguments[0][2].startsWith(iconDir),
                   "iconPath should live in the icon directory: "
                   + spy.signalArguments[0][2])
        }

        function test_repeatSendWhileDonationInFlightIsCoalesced() {
            // Avatar rendering makes donations asynchronous; a send burst to
            // the same chat must not queue duplicate donations.
            const iconDir = SystemUtils.shareShortcutsIconDirectory()
            const { donor, spy } = createDonor({ iconDirectory: iconDir })

            donor.donateForChat("chat-alice")
            donor.donateForChat("chat-design-group")
            donor.donateForChat("chat-design-group")

            tryCompare(spy, "count", 2)
            wait(50)
            compare(spy.count, 2)
            compare(spy.signalArguments[0][0], "chat-alice")
            compare(spy.signalArguments[1][0], "chat-design-group")
        }
    }
}
