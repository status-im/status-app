import QtQuick
import QtTest

import AppLayouts.Chat.panels

/*
 The message-rows skeleton doubles as the paging placeholder, which can stand
 in for many screens of out-of-window messages. A fast fling travels deep into
 it, so the pattern must fill the whole height — a single bottom-anchored
 block leaves white screens above it (device repro on PR #21970).
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
        name: "MessageRowsSkeleton"
        when: windowShown

        function tilesIntersecting(item, yFrom, yTo) {
            let n = 0
            function walk(obj) {
                for (let i = 0; i < obj.children.length; ++i) {
                    const child = obj.children[i]
                    if (child.height > 0 && child.width > 0 && !child.children.length) {
                        const top = child.mapToItem(item, 0, 0).y
                        if (top < yTo && top + child.height > yFrom)
                            ++n
                    }
                    walk(child)
                }
            }
            walk(item)
            return n
        }

        function test_patternFillsTallPlaceholder() {
            const skeleton = createTemporaryObject(skeletonComp, root, { height: 12000 })
            verify(!!skeleton)
            waitForRendering(skeleton)

            // every screenful of the placeholder must show skeleton rows,
            // including the regions far above the bottom-anchored start
            for (let y = 0; y < 12000; y += 600) {
                verify(tilesIntersecting(skeleton, y, y + 600) > 0,
                       "no skeleton tiles between y=" + y + " and y=" + (y + 600))
            }
        }

        function test_smallSkeletonStillRendersOneBlock() {
            const skeleton = createTemporaryObject(skeletonComp, root, { height: 400 })
            verify(!!skeleton)
            waitForRendering(skeleton)

            verify(tilesIntersecting(skeleton, 0, 400) > 0,
                   "a viewport-sized skeleton must render its pattern")
        }
    }
}
