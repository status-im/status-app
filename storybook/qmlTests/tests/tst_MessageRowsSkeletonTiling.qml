import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Chat.panels

/*
 The message-rows skeleton doubles as the paging placeholder, which on a
 low-end device can be ~180k px tall. Item cost must be O(1) in height:
 exactly one pattern block of real tiles, rendered into one texture, tiled
 with single-node quads. Height changes must never rebuild the block, and
 the tiling is anchored to the bottom edge so the pattern at the seam with
 real rows stays pinned when a reveal shrinks the placeholder.

 Offscreen note: no pixel/grab assertions here — only instance counts,
 positions and live-texture wiring.
*/
Item {
    id: root

    width: 800
    height: 600

    Component {
        id: skeletonComp

        MessageRowsSkeleton {
            width: 800
        }
    }

    TestCase {
        name: "MessageRowsSkeletonTiling"
        when: windowShown

        function findAllByObjectName(item, name) {
            const found = []
            function walk(obj) {
                for (let i = 0; i < obj.children.length; ++i) {
                    const child = obj.children[i]
                    if (child.objectName === name)
                        found.push(child)
                    walk(child)
                }
            }
            walk(item)
            return found
        }

        // leaf items with a color — the LoadingSkeletonTile rectangles
        function findTiles(item) {
            const found = []
            function walk(obj) {
                for (let i = 0; i < obj.children.length; ++i) {
                    const child = obj.children[i]
                    if (!child.children.length && child.color !== undefined)
                        found.push(child)
                    walk(child)
                }
            }
            walk(item)
            return found
        }

        function bottomQuad(skeleton) {
            const quads = findAllByObjectName(skeleton, "patternQuad")
            verify(quads.length > 0)
            let best = quads[0]
            for (let i = 1; i < quads.length; ++i) {
                if (quads[i].y > best.y)
                    best = quads[i]
            }
            return best
        }

        function test_tallSkeletonIsOneBlockPlusQuads() {
            const height = 100000
            const skeleton = createTemporaryObject(skeletonComp, root,
                                                   { height })
            verify(!!skeleton)
            waitForRendering(skeleton) // lets the block's positioners settle

            const blocks = findAllByObjectName(skeleton, "patternBlock")
            compare(blocks.length, 1)

            const block = blocks[0]
            verify(block.height > 0)

            // the rest of the height is quads, one per block-sized step
            const step = block.height + Theme.padding
            const quads = findAllByObjectName(skeleton, "patternQuad")
            compare(quads.length, Math.ceil((height - block.height) / step))

            // O(height/500) — a couple hundred, not the ~8,500 items of the
            // per-height Repeater this replaces
            verify(quads.length <= height / 500 + 1)

            // quads are single nodes: no children of their own
            for (let i = 0; i < quads.length; ++i)
                compare(quads[i].children.length, 0)

            // together the block and quads leave no blank screenful
            let covered = block.height
            for (let i = 0; i < quads.length; ++i)
                covered += quads[i].height
            verify(covered + (quads.length + 1) * Theme.padding >= height)
        }

        function test_seamStaysPinnedToBottomOnShrink() {
            const skeleton = createTemporaryObject(skeletonComp, root,
                                                   { height: 5000 })
            verify(!!skeleton)
            waitForRendering(skeleton) // lets the block's positioners settle

            const block = findAllByObjectName(skeleton, "patternBlock")[0]
            verify(!!block)

            const quad = bottomQuad(skeleton)
            const quadBottomOffset = skeleton.height - (quad.y + quad.height)
            compare(block.y + block.height, skeleton.height)

            // a reveal shrinks the placeholder from the top
            skeleton.height = 3200

            const quadAfter = bottomQuad(skeleton)
            compare(skeleton.height - (quadAfter.y + quadAfter.height),
                    quadBottomOffset)
            compare(block.y + block.height, skeleton.height)
        }

        function test_heightChangesDoNotRebuildBlock() {
            const skeleton = createTemporaryObject(skeletonComp, root,
                                                   { height: 2000 })
            verify(!!skeleton)
            waitForRendering(skeleton) // lets the block's positioners settle

            const block = findAllByObjectName(skeleton, "patternBlock")[0]
            verify(!!block)
            const tileCount = findTiles(block).length
            verify(tileCount > 0)

            const heights = [40000, 300, 100000, 1234]
            for (let i = 0; i < heights.length; ++i) {
                skeleton.height = heights[i]

                const blocks = findAllByObjectName(skeleton, "patternBlock")
                compare(blocks.length, 1)
                verify(blocks[0] === block) // same instance, never recreated
                compare(findTiles(block).length, tileCount)
            }
        }

        function test_quadsSampleOneLiveBlockTexture() {
            const skeleton = createTemporaryObject(skeletonComp, root,
                                                   { height: 5000 })
            verify(!!skeleton)
            waitForRendering(skeleton) // lets the block's positioners settle

            const block = findAllByObjectName(skeleton, "patternBlock")[0]
            const sources = findAllByObjectName(skeleton, "patternBlockSource")
            compare(sources.length, 1)

            const source = sources[0]
            verify(source.live) // texture follows block changes (width, theme)
            verify(source.sourceItem === block)

            const quads = findAllByObjectName(skeleton, "patternQuad")
            verify(quads.length > 0)
            for (let i = 0; i < quads.length; ++i)
                verify(quads[i].source === source)
        }

        function test_widthChangeReshapesBlockWithoutRebuild() {
            const skeleton = createTemporaryObject(skeletonComp, root,
                                                   { height: 5000 })
            verify(!!skeleton)
            waitForRendering(skeleton) // lets the block's positioners settle

            const block = findAllByObjectName(skeleton, "patternBlock")[0]
            compare(block.width, 800)

            skeleton.width = 500

            compare(block.width, 500) // the live texture samples the new shape
            verify(findAllByObjectName(skeleton, "patternBlock")[0] === block)
        }

        function test_themeChangeRestylesBlockWithoutRebuild() {
            const skeleton = createTemporaryObject(skeletonComp, root,
                                                   { height: 5000 })
            verify(!!skeleton)
            waitForRendering(skeleton) // lets the block's positioners settle

            const block = findAllByObjectName(skeleton, "patternBlock")[0]
            const tile = findTiles(block)[0]
            verify(!!tile)
            const colorBefore = String(tile.color)

            skeleton.Theme.style = skeleton.Theme.style === Theme.Style.Dark
                                   ? Theme.Style.Light
                                   : Theme.Style.Dark

            verify(String(tile.color) !== colorBefore)
            verify(findAllByObjectName(skeleton, "patternBlock")[0] === block)
        }
    }
}
