import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the community left column: the real
// community header (its data is known before the section loads) followed
// by skeleton channel rows. Plain positioners on purpose — skeletons must
// stay near-free, QtQuick.Layouts polish is too expensive here.
Column {
    id: root

    property alias name: header.name
    property alias membersCount: header.membersCount
    property alias image: header.image
    property alias color: header.color

    signal shareOwnProfileRequested()

    // mirrors CommunityColumnView's own top margin; the chrome slot adds none
    topPadding: Theme.smallPadding
    spacing: Theme.halfPadding

    ColumnHeaderPanel {
        id: header
        width: parent.width
        amISectionAdmin: false
        onShareOwnProfileRequested: root.shareOwnProfileRequested()
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

            // two channel categories: category header row (label left,
            // collapse button right) followed by its channel rows
            Repeater {
                model: 2

                Column {
                    id: categorySection

                    required property int index

                    width: parent.width
                    topPadding: index > 0 ? Theme.halfPadding : 0
                    spacing: Theme.padding

                    Item {
                        width: parent.width
                        height: 16

                        LoadingSkeletonTile {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 72 + categorySection.index * 32
                            implicitHeight: 14
                        }
                        LoadingSkeletonTile {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 4
                        }
                    }

                    Repeater {
                        // first category at the top of the list, the second
                        // at its bottom third
                        model: categorySection.index === 0 ? 7 : 4
                        Row {
                            id: channelRow

                            required property int index

                            width: parent.width
                            spacing: Theme.halfPadding

                            LoadingSkeletonTile {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: width / 2
                            }
                            LoadingSkeletonTile {
                                anchors.verticalCenter: parent.verticalCenter
                                // channel names vary in length
                                implicitWidth: 64 + (channelRow.index * 53
                                               + categorySection.index * 29) % 96
                                implicitHeight: 16
                            }
                        }
                    }
                }
            }
        }
    }
}
