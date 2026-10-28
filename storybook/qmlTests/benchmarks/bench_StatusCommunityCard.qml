import QtQuick
import QtTest

import StatusQ.Components

import Benchmark

/*
  StatusCommunityCard, the cards of the communities portal: 20 big cards
  with a banner.

  Variant: cards (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 20
        cellWidth: 335
        cellHeight: 230
        // the banner image, wherever it is in the card
        isReady: item => {
            function find(i) {
                if (i instanceof Image && i.source.toString() === item.banner.toString())
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

        delegate: StatusCommunityCard {
            required property int index

            name: "Community " + index
            description: "A community"
            // a distinct pixmap per cell; the query only keys the pixmap cache
            banner: `${root.stillSource}?cell=${index}`
            asset.source: root.stillSource
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
