import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the messages chat list: the real header row
// followed by skeleton chat rows (avatar + name). Plain positioners on
// purpose — skeletons must stay near-free, QtQuick.Layouts polish is too
// expensive here.
Column {
    id: root

    property alias createChatOpened: header.createChatOpened

    signal shareOwnProfileRequested()
    signal startChatClicked()

    // margins/spacing mirror ContactsColumnView so the swap doesn't shift
    topPadding: Theme.smallPadding
    spacing: Theme.halfPadding

    // The real header: invite and start-chat act app-globally, so they work
    // before the section exists; search needs the loaded list, so it is disabled
    MessagesListHeader {
        id: header
        x: Theme.padding
        width: parent.width - 2 * Theme.padding
        searchEnabled: false

        onShareOwnProfileRequested: root.shareOwnProfileRequested()
        onStartChatClicked: root.startChatClicked()
    }

    LoadingSkeletonGroup {
        x: Theme.padding
        width: parent.width - 2 * Theme.padding
        height: root.height - y
        // rows that don't fit must not bleed past the panel
        clip: true

        Column {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: Theme.padding

            Repeater {
                model: 12
                Row {
                    id: chatRow

                    required property int index

                    width: parent.width
                    spacing: Theme.halfPadding

                    LoadingSkeletonTile {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: width / 2
                    }
                    LoadingSkeletonTile {
                        anchors.verticalCenter: parent.verticalCenter
                        // chat names vary in length
                        implicitWidth: 88 + (chatRow.index * 59) % 132
                        implicitHeight: 14
                    }
                }
            }
        }
    }
}
