import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the messages chat list: the real header row
// followed by skeleton chat rows (avatar + name). Plain positioners on
// purpose — skeletons must stay near-free, QtQuick.Layouts polish is too
// expensive here.
Column {
    id: root

    // Plain property rather than an alias: the header lives behind a Loader,
    // and an alias into a deferred subtree does not work.
    property bool createChatOpened: false

    /*
       False while the section this stands in for is not yet known — the
       startup overlay, which paints before the backend has said which
       section is active. The real header asserts a title ("Messages") and
       offers invite / start-chat / search, none of which are appropriate for
       a section that may turn out to be a community; and in that mode its
       signals are not connected to anything, so the buttons render as
       tappable and do nothing. Draw a placeholder row instead.
    */
    property bool sectionKnown: true

    signal shareOwnProfileRequested()
    signal startChatClicked()

    // margins/spacing mirror ContactsColumnView so the swap doesn't shift
    topPadding: Theme.smallPadding
    spacing: Theme.halfPadding

    Loader {
        x: Theme.padding
        width: parent.width - 2 * Theme.padding
        sourceComponent: root.sectionKnown ? realHeader : placeholderHeader
    }

    // The real header: invite and start-chat act app-globally, so they work
    // before the section exists; search needs the loaded list, so it is disabled
    Component {
        id: realHeader

        MessagesListHeader {
            createChatOpened: root.createChatOpened
            searchEnabled: false

            onShareOwnProfileRequested: root.shareOwnProfileRequested()
            onStartChatClicked: root.startChatClicked()
        }
    }

    // Mirrors MessagesListHeader's shape — headline left, three round buttons
    // right — sized from the same theme values so it follows the font-size
    // setting. Deliberately approximate: both sides of the handover are
    // placeholders, so a few pixels are not worth more machinery.
    Component {
        id: placeholderHeader

        LoadingSkeletonGroup {
            id: placeholder

            // icon-only Large round button: icon box plus its padding
            readonly property int buttonSize: 24 + 2 * Theme.defaultHalfPadding

            implicitHeight: buttonSize

            LoadingSkeletonTile {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 96
                implicitHeight: Theme.secondaryAdditionalTextSize
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.halfPadding

                Repeater {
                    model: 3

                    LoadingSkeletonTile {
                        implicitWidth: placeholder.buttonSize
                        implicitHeight: placeholder.buttonSize
                        radius: width / 2
                    }
                }
            }
        }
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
