import QtQuick
import Qt.labs.qmlmodels

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder for the message list alone: left-aligned message rows
// of varying sizes with date separators and an attachment card. Pair with
// ChatInputSkeleton when the real input is not on screen. Plain positioners
// on purpose — skeletons must stay near-free, QtQuick.Layouts polish is too
// expensive here.
//
// As a paging placeholder this can be given hundreds of screens of height, so
// the item cost must stay O(1) in height: exactly one pattern block of real
// tiles is instantiated, rendered once into a texture, and the height above
// it is filled with plain single-node quads sampling that texture. Height
// changes only add/remove/reposition quads; the texture re-renders only when
// the block itself changes (panel width, theme).
LoadingSkeletonGroup {
    id: root

    // rows stack upward from the bottom edge (where the input sits); rows
    // that don't fit are clipped at the top instead of bleeding below
    clip: true

    QtObject {
        id: d

        // vertical rhythm of the tiling: one block plus the same gap the
        // bottom-anchored Column used to leave between repeated blocks
        readonly property real step: block.height + Theme.padding

        // the count divisor is floored at a safe underestimate of the block
        // height: the block reports partial heights while its nested
        // positioners settle, and reacting to those would churn thousands of
        // transient quads on a very tall placeholder
        readonly property int quadCount: block.height > 0
                                         ? Math.max(0, Math.ceil((root.height - block.height)
                                                                 / Math.max(d.step, 400)))
                                         : 0
    }

    Column {
        id: block

        objectName: "patternBlock"

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        spacing: Theme.padding

        // name/line widths are fractions of the available text width
        // so the shape survives narrow and wide panels alike
        Repeater {
            model: [
                { name: 0.22, lines: [0.95, 0.9, 0.86, 0.5] },
                { separator: true },
                { name: 0.18, lines: [0.6], card: true },
                { name: 0.26, lines: [0.92, 0.35] },
                { separator: true },
                { name: 0.2, lines: [0.88, 0.44] },
            ]

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

                        // available width for the text bars; derived
                        // from the stable root width, not the row
                        // itself, to avoid a sizing cycle
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

    // The one live texture every tiled quad samples; follows the block, so
    // it re-renders on panel-width and theme changes and nothing else
    ShaderEffectSource {
        id: blockTexture

        objectName: "patternBlockSource"

        visible: false
        sourceItem: block
        live: true
    }

    // Textured quads (default shaders — no custom shader) filling the height
    // above the block, positioned relative to the bottom edge so the pattern
    // at the seam with real rows stays pinned when a reveal shrinks the
    // placeholder; the topmost quad is clipped at the top
    Repeater {
        model: d.quadCount

        ShaderEffect {
            objectName: "patternQuad"

            required property int index

            property var source: blockTexture

            width: root.width
            height: block.height
            y: root.height - block.height - (index + 1) * d.step
        }
    }
}
