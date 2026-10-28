import QtQuick
import QtTest

import Benchmark

/*
  RoundedRenderSizedImage against the layer + MultiEffect mask it replaces,
  an unrounded Image, StatusImage and StatusRoundedImage, with a 1280 x 720
  source that every technique scales down (so they decode alike). Variants:
  <preset>_<technique>.

    chat    200 images of 144 px, 16 px corners, a 4 px bubble tail
    avatar  500 circles of 40 px
*/
Item {
    id: root

    width: 1000
    height: 800

    property string technique
    property bool circular: false

    readonly property real dpr: Window.window ? Window.window.devicePixelRatio : 1
    readonly property url source: Qt.resolvedUrl("../../testData/image_example_large.jpg")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent

        delegate: RoundedImageTechnique {
            required property int index

            width: runner.cellWidth * runner.sizeFactor
            height: runner.cellHeight * runner.sizeFactor

            technique: root.technique
            circular: root.circular
            tailRadius: 4
            // decoded for the unresized cell: resizing must not re-decode
            sourceSize: Qt.size(Math.ceil(runner.cellWidth * root.dpr),
                                Math.ceil(runner.cellHeight * root.dpr))
            // a distinct pixmap per cell; the query only keys the pixmap cache
            source: `${root.source}?cell=${index}`
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function bench(preset, technique) {
            root.technique = technique
            root.circular = preset === "avatar"
            runner.count = preset === "avatar" ? 500 : 200
            runner.cellWidth = preset === "avatar" ? 40 : preset === "chat130" ? 130 : 144
            runner.scenarios = ["static", "scroll", "resize"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }

        function test_chat_plain() { bench("chat", "plain") }
        function test_chat_layer() { bench("chat", "layer") }
        function test_chat_item() { bench("chat", "item") }
        function test_avatar_plain() { bench("avatar", "plain") }
        function test_avatar_avatar() { bench("avatar", "avatar") }
        function test_avatar_layer() { bench("avatar", "layer") }
        function test_avatar_item() { bench("avatar", "item") }
        function test_chat_status() { bench("chat", "status") }
        function test_avatar_status() { bench("avatar", "status") }
        function test_chat130_layer() { bench("chat130", "layer") }
        function test_chat130_item() { bench("chat130", "item") }
        function test_chat130_status() { bench("chat130", "status") }
    }
}
