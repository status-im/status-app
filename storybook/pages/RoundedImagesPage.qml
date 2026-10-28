pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Benchmark

/*
  Ways of rounding an image's corners, side by side (see
  Benchmark.RoundedImageTechnique): a plain Image, the layer + MultiEffect
  mask chat images used, StatusRoundedImage as avatars use it, and
  RoundedRenderSizedImage (RoundedAnimatedImage when animated).

  The top row shows one large sample of each with its top-left corner
  magnified; the grid below holds `imageCount` images of the chosen
  technique, all alive at once. The live figures are the process' own (GPU
  memory and time need Linux DRM fdinfo stats and QML_XHR_ALLOW_FILE_READ=1).

  For numbers to compare, run qmlTests/benchmarks/bench_RoundedImages.qml
  through run_benchmark.py: each technique in its own process.
*/
SplitView {
    id: root

    readonly property var techniques: ["plain", "layer", "avatar", "item"]
    readonly property var techniqueNames: ({
        plain: "Plain Image (no rounding)",
        layer: "Layer + MultiEffect mask",
        avatar: "StatusRoundedImage",
        item: "RoundedRenderSizedImage"
    })

    property string technique: "item"
    property int imageCount: 100
    property real cellSize: 144
    property real radius: 16
    property bool circular: false
    property bool tail: true
    property int fillMode: Image.PreserveAspectCrop
    property bool animated: false

    readonly property real dpr: Window.window ? Window.window.devicePixelRatio : 1
    readonly property url stillSource: Qt.resolvedUrl("../testData/image_example.png")
    readonly property url animatedSource: Qt.resolvedUrl("../testData/image_example_animated.gif")

    function usePreset(name) {
        const avatars = name === "avatars"
        cellSize = avatars ? 40 : 144
        radius = 16
        circular = avatars
        tail = !avatars
        fillMode = Image.PreserveAspectCrop
    }

    component Sample: RoundedImageTechnique {
        animated: root.animated
        fillMode: root.fillMode
        radius: root.radius
        circular: root.circular
        tailRadius: root.tail ? 4 : root.radius
        sourceSize: root.fillMode === Image.PreserveAspectCrop
                    ? Qt.size(Math.ceil(width * root.dpr), Math.ceil(height * root.dpr))
                    : Qt.size(Math.ceil(width * root.dpr), 0)
    }

    GpuStats {
        id: stats
    }

    QtObject {
        id: d

        property int frames: 0
        property int lastFrames: 0
        property var lastGpu: null
        property real fps: 0
        property real gpuMsPerFrame: NaN
        property real gpuMemMiB: NaN
        property real rssMiB: NaN

        function fmt(v, digits = 1) {
            return isNaN(v) ? "n/a" : v.toFixed(digits)
        }
    }

    Connections {
        target: root.Window.window
        function onFrameSwapped() {
            d.frames++
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            const frames = d.frames - d.lastFrames
            d.lastFrames = d.frames
            d.fps = frames * 1000 / interval

            const gpu = stats.gpu()
            d.gpuMemMiB = gpu ? gpu.memKiB / 1024 : NaN
            d.gpuMsPerFrame = gpu && d.lastGpu && frames > 0
                    ? (gpu.engineNs - d.lastGpu.engineNs) / frames / 1e6 : NaN
            d.lastGpu = gpu
            d.rssMiB = stats.rssKiB() / 1024
        }
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        padding: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // one large sample of each technique, and its top-left corner
            // magnified 6x without smoothing
            RowLayout {
                Layout.margins: 12
                spacing: 16

                Repeater {
                    model: root.techniques

                    ColumnLayout {
                        id: column

                        required property string modelData

                        spacing: 4

                        Label {
                            text: root.techniqueNames[column.modelData]
                            font.bold: root.technique === column.modelData
                        }

                        Rectangle {
                            id: frame

                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 200
                            color: "#c8d0dc"

                            Sample {
                                anchors.fill: parent
                                technique: column.modelData
                                source: root.animated ? root.animatedSource : root.stillSource
                            }
                        }

                        ShaderEffectSource {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 100
                            sourceItem: frame
                            sourceRect: Qt.rect(0, 0, 50, 25)
                            smooth: false
                            live: true
                        }
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                Flow {
                    width: parent.width
                    padding: 8
                    spacing: 8

                    Repeater {
                        model: root.imageCount

                        Sample {
                            required property int index

                            width: root.cellSize
                            height: root.cellSize
                            technique: root.technique
                            // a distinct pixmap per cell; the query only keys
                            // the pixmap cache
                            source: `${root.animated ? root.animatedSource : root.stillSource}?cell=${index}`
                        }
                    }
                }
            }
        }
    }

    Pane {
        SplitView.preferredWidth: 320
        SplitView.fillHeight: true

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 6

                Label { text: "Technique (grid)"; font.bold: true }

                Repeater {
                    model: root.techniques

                    RadioButton {
                        required property string modelData

                        text: root.techniqueNames[modelData]
                        checked: root.technique === modelData
                        onToggled: root.technique = modelData
                    }
                }

                Label { text: "Preset"; font.bold: true; Layout.topMargin: 8 }

                RowLayout {
                    Button {
                        text: "Chat images"
                        onClicked: root.usePreset("chat")
                    }
                    Button {
                        text: "Avatars"
                        onClicked: root.usePreset("avatars")
                    }
                }

                Label { text: `Images: ${root.imageCount}` }
                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 1000
                    stepSize: 10
                    value: root.imageCount
                    onMoved: root.imageCount = value
                }

                Label { text: `Size: ${root.cellSize} px` }
                Slider {
                    Layout.fillWidth: true
                    from: 24
                    to: 400
                    stepSize: 4
                    value: root.cellSize
                    onMoved: root.cellSize = value
                }

                CheckBox {
                    text: "Circular (avatars)"
                    checked: root.circular
                    onToggled: root.circular = checked
                }

                Label { text: `Radius: ${root.radius} px`; enabled: !root.circular }
                Slider {
                    Layout.fillWidth: true
                    enabled: !root.circular
                    from: 0
                    to: 100
                    stepSize: 1
                    value: root.radius
                    onMoved: root.radius = value
                }

                CheckBox {
                    text: "Bubble tail (4 px bottom-left corner)"
                    enabled: !root.circular
                    checked: root.tail
                    onToggled: root.tail = checked
                }

                CheckBox {
                    text: "Crop (off: fit)"
                    checked: root.fillMode === Image.PreserveAspectCrop
                    onToggled: root.fillMode = checked ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                }

                CheckBox {
                    text: "Animated GIF"
                    checked: root.animated
                    onToggled: root.animated = checked
                }

                Label { text: "Live"; font.bold: true; Layout.topMargin: 8 }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.family: "monospace"
                    text: `frames    ${d.fmt(d.fps, 0)} /s\n`
                        + `GPU       ${d.fmt(d.gpuMsPerFrame, 2)} ms/frame\n`
                        + `GPU mem   ${d.fmt(d.gpuMemMiB)} MiB\n`
                        + `RSS       ${d.fmt(d.rssMiB)} MiB`
                        + (stats.fileReadable ? "" : "\n(set QML_XHR_ALLOW_FILE_READ=1 for memory and GPU)")
                }
            }
        }
    }
}

// category: Components
// status: good
