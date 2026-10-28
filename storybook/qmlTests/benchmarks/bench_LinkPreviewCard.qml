import QtQuick
import QtTest

import shared.controls.chat
import utils

import Benchmark

/*
  LinkPreviewCard, the link previews under chat messages: 60 standard
  link cards with a thumbnail banner.

  Variant: cards (static, scroll). The card has a fixed size in the app,
  so there is no resize scenario.
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 60
        cellWidth: 326
        cellHeight: 290
        // the banner image, wherever it is in the card
        isReady: item => {
            function find(i) {
                if (i instanceof Image && i.source.toString() === item.linkData.thumbnail)
                    return i
                for (const c of i.children) {
                    const f = find(c)
                    if (f)
                        return f
                }
                return null
            }
            const banner = find(item)
            return !!banner && banner.status === Image.Ready
        }

        delegate: LinkPreviewCard {
            required property int index

            type: Constants.LinkPreviewType.Standard
            linkData {
                title: "Link " + index
                description: "A link preview"
                domain: "www.example.com"
                // a distinct pixmap per cell; the query only keys the pixmap
                // cache
                thumbnail: `${root.stillSource}?cell=${index}`
            }
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_cards() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
