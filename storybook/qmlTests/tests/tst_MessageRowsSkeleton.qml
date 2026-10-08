import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Chat.panels

Item {
    id: root

    width: 800
    height: 2400

    Component {
        id: skeletonComp

        MessageRowsSkeleton {
            width: 700
        }
    }

    TestCase {
        name: "MessageRowsSkeleton"
        when: windowShown

        function rowsOf(skeleton) {
            const rows = findChild(skeleton, "skeletonRows")
            verify(!!rows)
            return rows
        }

        // However tall it is made - a band one viewport tall, in a maximized
        // window - the rows cover it, with no empty space left.
        function test_theRowsCoverAnyHeight() {
            for (const stackFromTop of [false, true]) {
                const skeleton = createTemporaryObject(skeletonComp, root,
                                                       { stackFromTop: stackFromTop })
                verify(!!skeleton)

                for (const height of [100, 399, 400, 401, 600, 900, 1300, 2200]) {
                    skeleton.height = height
                    waitForRendering(skeleton)

                    const rows = rowsOf(skeleton)
                    verify(rows.height >= height,
                           `${rows.height} px of rows for ${height} px, stacked from the `
                           + (stackFromTop ? "top" : "bottom"))
                }
            }
        }

        // The fake rows line up with the real ones: StatusMessage's side
        // margins, its 40 px avatar, and its gap between avatar and text.
        function test_theRowsHaveTheMarginsOfARealMessage() {
            const skeleton = createTemporaryObject(skeletonComp, root, { height: 600 })
            verify(!!skeleton)
            waitForRendering(skeleton)

            const avatar = findChild(skeleton, "skeletonAvatar")
            const text = findChild(skeleton, "skeletonText")
            verify(!!avatar && !!text)

            compare(avatar.mapToItem(skeleton, 0, 0).x, Theme.padding, "the left margin")
            compare(avatar.width, 40)
            compare(text.mapToItem(skeleton, 0, 0).x, Theme.padding + 40 + Theme.halfPadding,
                    "the text after the avatar")

            for (let i = 0; i < text.children.length; ++i) {
                const bar = text.children[i]
                if (!bar.visible)
                    continue
                verify(bar.mapToItem(skeleton, bar.width, 0).x <= skeleton.width - Theme.padding,
                       "no bar runs into the right margin")
            }
        }

        // By default the rows start at the bottom edge, next to the input; from
        // the top edge when asked - next to the rows above a placeholder.
        function test_theRowsStartAtTheEdgeAskedFor() {
            const skeleton = createTemporaryObject(skeletonComp, root, { height: 900 })
            verify(!!skeleton)
            waitForRendering(skeleton)

            const rows = rowsOf(skeleton)
            compare(rows.y + rows.height, skeleton.height, "from the bottom edge")

            skeleton.stackFromTop = true
            waitForRendering(skeleton)
            compare(rows.y, 0, "from the top edge")

            // and back, the way the one paging placeholder moves from the band
            // below the rows to the one above them
            skeleton.stackFromTop = false
            waitForRendering(skeleton)
            compare(rows.y + rows.height, skeleton.height, "from the bottom edge again")
            compare(rows.height, rows.implicitHeight, "the rows keep their own height")
        }
    }
}
