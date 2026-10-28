import QtQuick
import QtTest

import Models
import shared.controls.chat

import Benchmark

/*
  ChatInputLinksPreviewArea, the link previews above the chat input: 20
  areas (one is shown per chat input; 20 make its cost measurable) of
  600 px, each with the mocked link previews.

  Variant: previews (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    ListModel { id: emptyModel }

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 20
        cellWidth: 600
        cellHeight: 100

        delegate: ChatInputLinksPreviewArea {
            required property int index

            width: runner.cellWidth
            imagePreviewArray: []
            linkPreviewModel: LinkPreviewModel {}
            showLinkPreviewSettings: false
            paymentRequestModel: emptyModel
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function test_previews() {
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }
    }
}
