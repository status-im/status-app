import QtQuick
import Qt.labs.qmlmodels

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder for the message list alone: left-aligned message rows
// of varying sizes with date separators and an attachment card. Pair with
// ChatInputSkeleton when the real input is not on screen. Plain positioners
// on purpose — skeletons must stay near-free, QtQuick.Layouts polish is too
// expensive here.
LoadingSkeletonGroup {
    id: root

    // Rows stack upward from the bottom edge (where the input sits), and those
    // that don't fit are clipped at the top instead of bleeding below. Set,
    // they stack down from the top edge instead and are clipped at the bottom
    // - for a placeholder standing below the rows it leads to.
    property bool stackFromTop: false

    clip: true

    QtObject {
        id: d

        // name/line widths are fractions of the available text width so the
        // shape survives narrow and wide panels alike
        readonly property var pattern: [
            { name: 0.22, lines: [0.95, 0.9, 0.86, 0.5] },
            { separator: true },
            { name: 0.18, lines: [0.6], card: true },
            { name: 0.26, lines: [0.92, 0.35] },
            { separator: true },
            { name: 0.2, lines: [0.88, 0.44] },
        ]

        // The pattern, repeated to cover any height: it is taller than this,
        // so whole copies never fall short. Rebuilt only when the number of
        // copies changes, not on every resize.
        readonly property int patternHeightAtLeast: 400
        readonly property int copies: Math.max(1, Math.ceil(root.height / patternHeightAtLeast))

        readonly property var rows: {
            const rows = []

            for (let i = 0; i < copies; ++i)
                rows.push(...pattern)

            return rows
        }
    }

    Column {
        objectName: "skeletonRows"

        anchors.left: parent.left
        anchors.right: parent.right

        // Placed by y, not by switching between a top and a bottom anchor:
        // the two anchor bindings update one at a time, the moment both are
        // set stretches the column to the skeleton's height, and that height
        // outlives the anchor - leaving the rows at the top for good.
        y: root.stackFromTop ? 0 : root.height - height

        spacing: Theme.padding

        Repeater {
            model: d.rows

            delegate: DelegateChooser {
                role: "separator"

                DelegateChoice {
                    roleValue: true

                    LoadingSkeletonTile {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: 96
                        implicitHeight: 12
                    }
                }
                DelegateChoice {
                    Row {
                        id: entry

                        required property var modelData

                        // available width for the text bars; derived from the
                        // stable root width, not the row itself, to avoid a
                        // sizing cycle
                        readonly property real textWidth:
                            Math.max(0, root.width - 40 - Theme.halfPadding)

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
}
