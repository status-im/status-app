import QtQuick
import QtTest

import Benchmark

/*
  Rounded image techniques (Benchmark.RoundedImageTechnique), as chat images,
  as GIFs and as avatars. Variants: <preset>_<technique>, e.g.
  chat_layer, gif_item, avatar_avatar.

    chat    200 images of 144 px, 16 px corners, a 4 px bubble tail
    gif     the same, animated GIFs
    avatar  500 circles of 40 px
    avatarBordered  the same, with a 2 px border
*/
Item {
    id: root

    width: 1000
    height: 800

    property string technique
    property bool animated: false
    property bool circular: false
    property real tailRadius: 4
    property real borderWidth: 0

    readonly property real dpr: Window.window ? Window.window.devicePixelRatio : 1
    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")
    readonly property url animatedSource: Qt.resolvedUrl("../../testData/image_example_animated.gif")

    BenchmarkRunner {
        id: runner

        anchors.fill: parent

        delegate: RoundedImageTechnique {
            required property int index

            width: runner.cellWidth * runner.sizeFactor
            height: runner.cellHeight * runner.sizeFactor

            technique: root.technique
            animated: root.animated
            circular: root.circular
            tailRadius: root.tailRadius
            borderWidth: root.borderWidth
            // decoded for the unresized cell: resizing must not re-decode
            sourceSize: Qt.size(Math.ceil(runner.cellWidth * root.dpr),
                                Math.ceil(runner.cellHeight * root.dpr))
            // a distinct pixmap per cell, as distinct photos are; the query
            // only keys the pixmap cache
            source: `${root.animated ? root.animatedSource : root.stillSource}?cell=${index}`
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function bench(preset, technique) {
            root.technique = technique
            root.animated = preset === "gif"
            const avatar = preset.startsWith("avatar")
            root.circular = avatar
            root.borderWidth = preset === "avatarBordered" ? 2 : 0
            runner.count = avatar ? 500 : 200
            runner.cellWidth = avatar ? 40 : 144
            runner.scenarios = preset === "gif" ? ["animated", "scroll"]
                                                : ["static", "scroll", "resize"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }

        function test_chat_plain() { bench("chat", "plain") }
        function test_chat_layer() { bench("chat", "layer") }
        function test_chat_item() { bench("chat", "item") }
        function test_gif_plain() { bench("gif", "plain") }
        function test_gif_layer() { bench("gif", "layer") }
        function test_gif_item() { bench("gif", "item") }
        function test_avatar_plain() { bench("avatar", "plain") }
        function test_avatar_avatar() { bench("avatar", "avatar") }
        function test_avatar_item() { bench("avatar", "item") }
        function test_avatarBordered_avatar() { bench("avatarBordered", "avatar") }
    }
}
