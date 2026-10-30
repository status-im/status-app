import QtQuick

/*
  Builds `count` instances of `delegate` in a scrollable grid, all alive at
  once, and measures what they cost: build time, GPU memory and RSS added,
  and per frame the GPU and CPU time in each scenario:

    static    every frame redraws the whole scene, nothing else changes
    scroll    the grid scrolls up and down
    resize    the cells shrink to 85% and grow back, continuously
    animated  nothing is driven: the content animates itself (GIFs,
              shimmer, ...)

  The delegate is a Repeater delegate (index is available) and sizes itself
  from `cellWidth` / `cellHeight` times `sizeFactor`, which the resize
  scenario animates.

  A scenario that presented fewer than `minFps` frames per second is marked
  invalid (screen blanked or locked, compositor stalled), and so is the
  whole result; so is a result where not all `count` instances were built
  and ready. GPU figures need GpuStats' file access
  (QML_XHR_ALLOW_FILE_READ=1) and a driver with DRM fdinfo stats.
*/
Item {
    id: root

    property Component delegate
    property int count: 200
    property real cellWidth: 144
    property real cellHeight: cellWidth
    property real spacing: 8
    property var scenarios: ["static", "scroll", "resize"]
    // whether a delegate instance has finished loading
    property var isReady: item => item.status === undefined || item.status === Image.Ready
    property real minFps: 5

    readonly property real sizeFactor: d.sizeFactor
    readonly property alias running: d.running
    readonly property alias result: d.result

    signal finished(var result)

    function start() {
        d.start()
    }

    GpuStats {
        id: stats
    }

    QtObject {
        id: d

        property bool running: false
        property var result: null
        property int frames: 0
        property real sizeFactor: 1
        property bool driving: false
        property bool resizing: false
        property bool scrolling: false
        property int instances: 0

        property var pending: null
        readonly property Timer timer: Timer {
            onTriggered: {
                const cb = d.pending
                d.pending = null
                if (cb)
                    cb()
            }
        }

        function delay(ms, cb) {
            pending = cb
            timer.interval = ms
            timer.restart()
        }

        function readyCount() {
            let n = 0
            for (let i = 0; i < cells.count; ++i) {
                const item = cells.itemAt(i)
                if (item && root.isReady(item))
                    ++n
            }
            return n
        }

        function whenReady(cb, started = Date.now()) {
            if (readyCount() === cells.count || Date.now() - started > 20000) {
                cb()
                return
            }
            delay(20, () => whenReady(cb, started))
        }

        function memory() {
            gc()
            const gpu = stats.gpu()
            return { gpuKiB: gpu ? gpu.memKiB : NaN, rssKiB: stats.rssKiB() }
        }

        // frames, GPU and CPU time over `ms`
        function measure(ms, cb) {
            const gpu0 = stats.gpu()
            const cpu0 = stats.cpuMs()
            const frames0 = frames
            const t0 = Date.now()
            delay(ms, () => {
                const gpu1 = stats.gpu()
                const cpu1 = stats.cpuMs()
                const n = frames - frames0
                const dt = Date.now() - t0
                const gpuMs = gpu0 && gpu1 ? (gpu1.engineNs - gpu0.engineNs) / 1e6 : NaN
                const fps = n * 1000 / dt
                cb({
                    fps,
                    gpuMsPerFrame: n > 0 ? gpuMs / n : NaN,
                    cpuMsPerFrame: n > 0 ? (cpu1 - cpu0) / n : NaN,
                    valid: fps >= root.minFps
                })
            })
        }

        readonly property var scenarioDefs: ({
            static: { ms: 2000, begin: () => d.driving = true, end: () => d.driving = false },
            scroll: { ms: 3000, begin: () => d.scrolling = true,
                      end: () => { d.scrolling = false; flick.contentY = 0 } },
            resize: { ms: 3000, begin: () => d.resizing = true,
                      end: () => { d.resizing = false; d.sizeFactor = 1 } },
            animated: { ms: 3000, begin: () => {}, end: () => {} }
        })

        function runScenarios(r, cb, i = 0) {
            if (i === root.scenarios.length) {
                cb()
                return
            }
            const name = root.scenarios[i]
            const s = scenarioDefs[name]
            s.begin()
            // a moment for whatever starts to settle before it is measured
            delay(250, () => measure(s.ms, m => {
                s.end()
                r.scenarios[name] = m
                if (!m.valid)
                    r.valid = false
                delay(250, () => runScenarios(r, cb, i + 1))
            }))
        }

        function start() {
            if (running)
                return
            running = true
            instances = 0

            const window = root.Window.window
            const r = {
                count: root.count,
                cellWidth: root.cellWidth,
                cellHeight: root.cellHeight,
                dpr: window ? window.devicePixelRatio : NaN,
                window: window ? `${window.width}x${window.height}` : "?",
                backend: root.GraphicsInfo.api,
                gpuStats: stats.gpu() !== null,
                valid: true,
                scenarios: {}
            }

            // settle the empty scene first, so its memory is the baseline
            delay(500, () => {
                const before = memory()
                const t0 = Date.now()
                instances = root.count
                const syncMs = Date.now() - t0
                whenReady(() => {
                    const readyMs = Date.now() - t0
                    driving = true
                    delay(500, () => {
                        driving = false
                        const after = memory()
                        r.build = {
                            syncMsPerItem: syncMs / root.count,
                            readyMs,
                            ready: readyCount(),
                            gpuMiB: (after.gpuKiB - before.gpuKiB) / 1024,
                            rssMiB: (after.rssKiB - before.rssKiB) / 1024
                        }
                        // instances that failed to build (a required
                        // property not set, say) or never got ready would
                        // measure a smaller scene than asked for
                        if (r.build.ready !== root.count)
                            r.valid = false
                        runScenarios(r, () => {
                            result = r
                            running = false
                            root.finished(r)
                        })
                    })
                })
            })
        }
    }

    Connections {
        target: root.Window.window
        function onFrameSwapped() {
            d.frames++
        }
    }

    // the frame driver: a 1 px item kept turning, in a corner
    Rectangle {
        z: 1
        width: 1
        height: 1
        color: "transparent"
        NumberAnimation on rotation {
            running: d.driving
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }

    SequentialAnimation {
        running: d.resizing
        loops: Animation.Infinite

        NumberAnimation { target: d; property: "sizeFactor"; to: 0.85; duration: 500 }
        NumberAnimation { target: d; property: "sizeFactor"; to: 1; duration: 500 }
    }

    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: flow.height

        SequentialAnimation {
            running: d.scrolling
            loops: Animation.Infinite

            NumberAnimation {
                target: flick
                property: "contentY"
                to: Math.max(0, flick.contentHeight - flick.height)
                duration: 1500
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: flick
                property: "contentY"
                to: 0
                duration: 1500
                easing.type: Easing.InOutQuad
            }
        }

        Flow {
            id: flow

            width: flick.width
            padding: root.spacing
            spacing: root.spacing

            Repeater {
                id: cells

                model: d.instances
                delegate: root.delegate
            }
        }
    }
}
