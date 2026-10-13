import QtQuick
import QtTest

import AppLayouts.Chat.adaptors
import StatusQ.Core.Utils as SQUtils

// ChannelMembersAdaptor narrows the community roster to a channel: a gated
// channel keeps its member set (a key-set filter), any other channel shows the
// whole roster.
Item {
    id: root

    // community roster mock: rows plus the gated-channel API
    ListModel {
        id: roster

        property var channels: ({ "gated": ["0xalice"] })

        signal channelMembersChanged(string chatId)

        function isGatedChannel(chatId) {
            return chatId in channels
        }

        function getChannelMemberKeys(chatId) {
            return JSON.stringify(channels[chatId] ?? [])
        }

        ListElement { pubKey: "0xalice"; preferredDisplayName: "Alice" }
        ListElement { pubKey: "0xbob"; preferredDisplayName: "Bob" }
        ListElement { pubKey: "0xcarol"; preferredDisplayName: "Carol" }
    }

    Component {
        id: adaptorComponent

        ChannelMembersAdaptor {
            rosterModel: roster
        }
    }

    TestCase {
        name: "ChannelMembersAdaptor"

        function init() {
            roster.channels = ({ "gated": ["0xalice"] })
        }

        function keys(model) {
            return SQUtils.ModelUtils.modelToFlatArray(model, "pubKey")
        }

        function test_openChannelShowsTheWholeRoster() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: "open" })
            compare(adaptor.model, roster)
        }

        function test_gatedChannelShowsItsMembers() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: "gated" })
            compare(keys(adaptor.model), ["0xalice"])
        }

        function test_channelMemberChangesRefreshTheSet() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: "gated" })

            roster.channels = ({ "gated": ["0xalice", "0xcarol"], "other": ["0xbob"] })
            roster.channelMembersChanged("other")
            compare(keys(adaptor.model), ["0xalice"])

            roster.channelMembersChanged("gated")
            compare(keys(adaptor.model), ["0xalice", "0xcarol"])
        }

        function test_switchingChannels() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: "gated" })
            adaptor.chatId = "open"
            compare(adaptor.model, roster)
            adaptor.chatId = "gated"
            compare(keys(adaptor.model), ["0xalice"])
        }

        function test_channelGatedLater() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: "open" })
            roster.channels = ({ "open": ["0xbob"] })
            roster.channelMembersChanged("open")
            compare(keys(adaptor.model), ["0xbob"])
        }

        function test_noRosterNoModel() {
            const adaptor = createTemporaryObject(adaptorComponent, root,
                                                  { rosterModel: null, chatId: "gated" })
            compare(adaptor.model, null)
        }

        function test_rowsAddedToTheRosterAppearWhenInTheSet() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: "gated" })
            roster.append({ pubKey: "0xdave", preferredDisplayName: "Dave" })
            compare(keys(adaptor.model), ["0xalice"])

            roster.channels = ({ "gated": ["0xalice", "0xdave"] })
            roster.channelMembersChanged("gated")
            compare(keys(adaptor.model), ["0xalice", "0xdave"])
            roster.remove(3)
            compare(keys(adaptor.model), ["0xalice"])
        }
    }
}
