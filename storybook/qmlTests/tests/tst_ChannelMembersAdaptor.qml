import QtQuick
import QtTest

import AppLayouts.Chat.adaptors
import StatusQ.Core.Utils as SQUtils

// ChannelMembersAdaptor narrows the community roster to a channel: a gated
// channel keeps its member set (a key-set filter), any other channel shows the
// whole roster.
Item {
    id: root

    // real-shaped ids: a chat id is the community id followed by the channel uuid
    readonly property string communityId: "0x02b5bdaf5a25fcfe2ee14c501fab1836b8de57f61621080c3d52073d16de0d98d6"
    readonly property string gatedId: communityId + "8f5e8c6a-2b47-4e0c-9a1d-3c3f2b1d6e7a"
    readonly property string openId: communityId + "0b6f3e1c-0d55-4c38-9c7e-1f1d2a3b4c5d"
    readonly property string otherId: communityId + "c1d2e3f4-5a6b-4c7d-8e9f-0a1b2c3d4e5f"

    readonly property string alice: "0x04" + "a".repeat(128)
    readonly property string bob: "0x04" + "b".repeat(128)
    readonly property string carol: "0x04" + "c".repeat(128)
    readonly property string dave: "0x04" + "d".repeat(128)

    // community roster mock: rows plus the gated-channel API, addressed by full
    // chat id like CommunityRosterModel
    ListModel {
        id: roster

        property var channels: ({})

        signal channelMembersChanged(string chatId)

        function isGatedChannel(chatId) {
            return chatId in channels
        }

        function getChannelMemberKeys(chatId) {
            return JSON.stringify(channels[chatId] ?? [])
        }

        Component.onCompleted: {
            append({ pubKey: root.alice, preferredDisplayName: "Alice" })
            append({ pubKey: root.bob, preferredDisplayName: "Bob" })
            append({ pubKey: root.carol, preferredDisplayName: "Carol" })
        }
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
            roster.channels = ({ [root.gatedId]: [root.alice] })
        }

        function keys(model) {
            return SQUtils.ModelUtils.modelToFlatArray(model, "pubKey")
        }

        function test_openChannelShowsTheWholeRoster() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: root.openId })
            compare(adaptor.model, roster)
        }

        function test_gatedChannelShowsItsMembers() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: root.gatedId })
            compare(keys(adaptor.model), [root.alice])
        }

        function test_channelMemberChangesRefreshTheSet() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: root.gatedId })

            roster.channels = ({ [root.gatedId]: [root.alice, root.carol], [root.otherId]: [root.bob] })
            roster.channelMembersChanged(root.otherId)
            compare(keys(adaptor.model), [root.alice])

            roster.channelMembersChanged(root.gatedId)
            compare(keys(adaptor.model), [root.alice, root.carol])
        }

        function test_switchingChannels() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: root.gatedId })
            adaptor.chatId = root.openId
            compare(adaptor.model, roster)
            adaptor.chatId = root.gatedId
            compare(keys(adaptor.model), [root.alice])
        }

        function test_channelGatedLater() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: root.openId })
            roster.channels = ({ [root.openId]: [root.bob] })
            roster.channelMembersChanged(root.openId)
            compare(keys(adaptor.model), [root.bob])
        }

        function test_noRosterNoModel() {
            const adaptor = createTemporaryObject(adaptorComponent, root,
                                                  { rosterModel: null, chatId: root.gatedId })
            compare(adaptor.model, null)
        }

        function test_rowsAddedToTheRosterAppearWhenInTheSet() {
            const adaptor = createTemporaryObject(adaptorComponent, root, { chatId: root.gatedId })
            roster.append({ pubKey: root.dave, preferredDisplayName: "Dave" })
            compare(keys(adaptor.model), [root.alice])

            roster.channels = ({ [root.gatedId]: [root.alice, root.dave] })
            roster.channelMembersChanged(root.gatedId)
            compare(keys(adaptor.model), [root.alice, root.dave])
            roster.remove(3)
            compare(keys(adaptor.model), [root.alice])
        }
    }
}
