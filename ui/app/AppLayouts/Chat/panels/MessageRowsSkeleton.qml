import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder for the message list alone: left-aligned message rows
// of varying sizes with date separators and an attachment card. Pair with
// ChatInputSkeleton when the real input is not on screen. Plain positioners
// on purpose — skeletons must stay near-free, QtQuick.Layouts polish is too
// expensive here.
LoadingSkeletonGroup {
    id: root

    // rows stack upward from the bottom edge (where the input sits); rows
    // that don't fit are clipped at the top instead of bleeding below
    clip: true

    Column {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        spacing: Theme.padding

        // name/line widths are fractions of the available text width so the
        // shape survives narrow and wide panels alike
        Repeater {
            model: [
                { name: 0.22, lines: [0.95, 0.9, 0.86, 0.5] },
                { separator: true },
                { name: 0.18, lines: [0.6], card: true },
                { name: 0.26, lines: [0.92, 0.35] },
                { separator: true },
                { name: 0.2, lines: [0.88, 0.44] },
            ]

            Item {
                id: entry

                required property var modelData

                // available width for the text bars; derived from the stable
                // root width, not the row itself, to avoid a sizing cycle
                readonly property real textWidth:
                    Math.max(0, root.width - 40 - Theme.halfPadding)

                width: parent.width
                height: childrenRect.height

                LoadingSkeletonTile {
                    visible: !!entry.modelData.separator
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: 96
                    implicitHeight: 12
                }

                Row {
                    visible: !entry.modelData.separator
                    width: parent.width
                    spacing: Theme.halfPadding

                    LoadingSkeletonTile {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: width / 2
                    }
                    Column {
                        spacing: 6

                        LoadingSkeletonTile {
                            implicitWidth: entry.textWidth * (entry.modelData.name ?? 0.2)
                            implicitHeight: 12
                        }
                        Repeater {
                            model: entry.modelData.lines ?? []

                            LoadingSkeletonTile {
                                required property real modelData

                                implicitWidth: entry.textWidth * modelData
                                implicitHeight: 14
                            }
                        }
                        // attachment / link-preview card
                        LoadingSkeletonTile {
                            visible: !!entry.modelData.card
                            implicitWidth: Math.min(320, entry.textWidth * 0.6)
                            implicitHeight: 150
                            radius: Theme.radius
                        }
                    }
                }
            }
        }
    }
}
