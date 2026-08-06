import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the messages chat list: the real header row
// followed by skeleton chat rows (avatar, name, message preview, timestamp)
ColumnLayout {
    id: root

    property alias createChatOpened: header.createChatOpened

    signal shareOwnProfileRequested()
    signal startChatClicked()

    spacing: Theme.padding

    // The real header: invite and start-chat act app-globally, so they work
    // before the section exists; search shows its loading tile
    MessagesListHeader {
        id: header
        Layout.fillWidth: true
        searchLoading: true

        onShareOwnProfileRequested: root.shareOwnProfileRequested()
        onStartChatClicked: root.startChatClicked()
    }

    LoadingSkeletonGroup {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: rowsLayout.implicitHeight

        ColumnLayout {
            id: rowsLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: Theme.padding

            Repeater {
                model: 9
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: Theme.padding

                    LoadingSkeletonTile {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: width / 2
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.halfPadding

                        LoadingSkeletonTile {
                            implicitWidth: 120
                            implicitHeight: 14
                        }
                        LoadingSkeletonTile {
                            implicitWidth: 180
                            implicitHeight: 12
                        }
                    }
                    LoadingSkeletonTile {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 36
                        implicitHeight: 10
                    }
                }
            }
        }
    }
}
