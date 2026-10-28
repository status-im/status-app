import QtQuick
import QtTest

import Benchmark

import "../../../ui/app/AppLayouts/ActivityCenter/controls"

/*
  NotificationAvatar, the avatar of an activity center notification:
  300 circular image avatars at the default size, with their badge.

  Variant: avatars (static, scroll; their size does not animate in the
  app, and a resize would re-decode them every frame).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 300
        cellWidth: 48
        isReady: item => {
            // the avatar image, wherever it is in the tree
            function find(i) {
                if (i.status !== undefined && i.source !== undefined && i.source.toString().startsWith("file:"))
                    return i
                for (const c of i.children) {
                    const f = find(c)
                    if (f)
                        return f
                }
                return null
            }
            const image = find(item)
            return !!image && image.status === Image.Ready
        }

        delegate: Item {
            required property int index

            width: runner.cellWidth * runner.sizeFactor
            height: runner.cellHeight * runner.sizeFactor

            NotificationAvatar {
                density: parent.width / runner.cellWidth
                // a distinct pixmap per cell; the query only keys the pixmap
                // cache
                avatarSource: `${root.stillSource}?cell=${parent.index}`
                badgeIconName: "action-mention"
            }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_avatars() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
