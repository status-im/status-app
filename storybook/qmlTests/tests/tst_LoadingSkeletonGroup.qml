import QtQuick
import QtQuick.Effects
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core

Item {
    id: root
    width: 400
    height: 300

    Component {
        id: groupComp

        LoadingSkeletonGroup {
            id: group

            readonly property alias column: column

            width: 300
            height: 200

            Column {
                id: column
                spacing: 10

                LoadingSkeletonTile {
                    objectName: "avatarTile"
                    width: 40
                    height: 40
                    radius: 20
                }
                Row {
                    spacing: 8

                    LoadingSkeletonTile {
                        objectName: "titleTile"
                        width: 100
                        height: 14
                    }
                    LoadingSkeletonTile {
                        objectName: "subtitleTile"
                        width: 60
                        height: 12
                    }
                }
            }
        }
    }

    TestCase {
        name: "LoadingSkeletonGroup"
        when: windowShown

        function descendants(item) {
            let result = []
            const stack = [item]
            while (stack.length) {
                const current = stack.pop()
                result.push(current)
                const kids = current.children ?? []
                for (let i = 0; i < kids.length; ++i)
                    stack.push(kids[i])
            }
            return result
        }

        function init() {
            failOnWarning(/.*/)
        }

        function test_shader_is_built_in() {
            verify(SystemUtils.fileExists(":/StatusQ/shaders/skeletontile.frag.qsb"),
                   "the compiled tile shader must be a StatusQ resource")
            verify(SystemUtils.fileExists(":/StatusQ/shaders/skeletontile.vert.qsb"),
                   "the compiled tile shader must be a StatusQ resource")
        }

        function test_no_offscreen_render_passes() {
            const group = createTemporaryObject(groupComp, root)
            verify(!!group)

            for (const item of descendants(group)) {
                verify(!(item instanceof MultiEffect), "MultiEffect found")
                verify(!(item instanceof ShaderEffectSource),
                       "ShaderEffectSource found")
                verify(!(item.layer && item.layer.enabled),
                       `layer enabled on ${item}`)
            }
        }

        function test_tiles_follow_radius_and_size() {
            const group = createTemporaryObject(groupComp, root)
            verify(!!group)

            const avatar = findChild(group, "avatarTile")
            verify(avatar instanceof SkeletonTileItem)
            compare(avatar.radius, 20)
            compare(avatar.width, 40)

            const title = findChild(group, "titleTile")
            verify(title instanceof SkeletonTileItem)
            compare(title.radius, 4)

            compare(title.sweepSize, Qt.size(300, 200),
                    "a grouped tile sweeps across the group, not itself")
        }

        function test_sweep_is_continuous_across_the_group() {
            const group = createTemporaryObject(groupComp, root)
            verify(!!group)

            const avatar = findChild(group, "avatarTile")
            const title = findChild(group, "titleTile")
            const subtitle = findChild(group, "subtitleTile")

            for (const tile of [avatar, title, subtitle])
                compare(tile.sweepSize, Qt.size(300, 200))

            compare(avatar.sweepOrigin, Qt.point(0, 0))
            tryCompare(title, "sweepOrigin", Qt.point(0, 50))
            tryCompare(subtitle, "sweepOrigin", Qt.point(108, 50))

            group.column.spacing = 20
            tryCompare(title, "sweepOrigin", Qt.point(0, 60))
            tryCompare(subtitle, "sweepOrigin", Qt.point(108, 60))

            group.width = 500
            for (const tile of [avatar, title, subtitle])
                compare(tile.sweepSize, Qt.size(500, 200))
        }
    }
}
