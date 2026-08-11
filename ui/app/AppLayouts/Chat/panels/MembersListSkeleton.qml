import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the chat members panel: the real header
// (label + disabled search button) above skeleton member rows (avatar + name).
// Plain positioners on purpose — skeletons must stay near-free,
// QtQuick.Layouts polish is too expensive here.
Column {
    id: root

    topPadding: Theme.padding
    // the header's own bottom margin plus the panel spacing
    spacing: Theme.padding + Theme.halfPadding

    MembersPanelHeader {
        x: Theme.padding
        width: parent.width - 2 * Theme.padding
        label: qsTr("Members")
        searchEnabled: false
    }

    LoadingSkeletonGroup {
        // list margin + StatusMemberListItem's own horizontal padding
        x: Theme.padding + Theme.halfPadding
        width: parent.width - x
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

            // two member categories (online / inactive), each a small label
            // followed by member rows: avatar + name and key lines
            Repeater {
                model: 2

                Column {
                    id: categorySection

                    required property int index

                    width: parent.width
                    topPadding: index > 0 ? Theme.halfPadding : 0
                    spacing: Theme.padding

                    LoadingSkeletonTile {
                        implicitWidth: 44 + categorySection.index * 16
                        implicitHeight: 12
                    }

                    Repeater {
                        model: categorySection.index === 0 ? 6 : 3
                        Row {
                            id: memberRow

                            required property int index

                            width: parent.width
                            spacing: Theme.halfPadding

                            LoadingSkeletonTile {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: width / 2
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                LoadingSkeletonTile {
                                    // member names vary in length
                                    implicitWidth: 72 + (memberRow.index * 41
                                                   + categorySection.index * 23) % 88
                                    implicitHeight: 12
                                }
                                LoadingSkeletonTile {
                                    implicitWidth: 64
                                    implicitHeight: 8
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
