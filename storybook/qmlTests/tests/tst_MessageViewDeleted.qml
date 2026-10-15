import QtQuick
import QtTest
import StatusQ.Core.Theme
import shared.views.chat

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: messageComponent
        MessageView {
            deleted: true
            deletedBy: "0x123"
            deletedByContactDisplayName: "Prod-Test-ABC with a very long name"
            messageTimestamp: new Date(2026, 8, 29, 11, 20).getTime()
        }
    }

    TestCase {
        name: "MessageViewDeleted"
        when: windowShown

        function test_timestampRespectsInternalPadding_data() {
            return [260, 300, 450].map(width => ({ tag: String(width), width }))
        }

        function test_timestampRespectsInternalPadding(data) {
            const view = createTemporaryObject(messageComponent, root, { width: data.width })
            verify(!!view)
            verify(waitForPolish(view.item))
            const timestamp = findChild(view, "messageTimestamp")
            verify(!!timestamp)
            verify(timestamp.width >= timestamp.implicitWidth,
                   "The timestamp must fit without painting beyond its bounds")
            const right = timestamp.mapToItem(view, timestamp.width, 0).x
            verify(right <= view.width - Theme.padding + 1)
            compare(view.item.width, view.width)
        }
    }
}
