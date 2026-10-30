import QtQuick
import QtQuick.Window
import QtTest

import StatusQ.Components

/*
 Checks what the tile shader actually draws. The offscreen QPA platform has no
 RHI backend to compile and run shaders with, so every test is skipped
 there; run it with a real window (no QT_QPA_PLATFORM=offscreen).
*/
Item {
    id: root
    width: 400
    height: 200

    Component {
        id: tileComp

        Rectangle {
            readonly property alias tile: tile

            width: 240
            height: 80
            color: "#0000ff"

            LoadingSkeletonTile {
                id: tile
                x: 20
                y: 20
                width: 200
                height: 40
                radius: 12
                color: "#404040"
            }
        }
    }

    // two tiles farther apart than the band is wide
    Component {
        id: groupComp

        Rectangle {
            readonly property alias leftTile: leftTile
            readonly property alias rightTile: rightTile

            width: 360
            height: 40
            color: "#0000ff"

            LoadingSkeletonGroup {
                anchors.fill: parent

                LoadingSkeletonTile {
                    id: leftTile
                    x: 0
                    width: 40
                    height: 40
                    color: "#404040"
                }
                LoadingSkeletonTile {
                    id: rightTile
                    x: 320
                    width: 40
                    height: 40
                    color: "#404040"
                }
            }
        }
    }

    // many running tiles, to give the render thread work while they are removed
    Component {
        id: gridComp

        Loader {
            active: false
            sourceComponent: Grid {
                columns: 12

                Repeater {
                    model: 120

                    LoadingSkeletonTile {
                        width: 30
                        height: 16
                    }
                }
            }
        }
    }

    SignalSpy {
        id: frameSpy
        target: root.Window.window
        signalName: "frameSwapped"
    }

    TestCase {
        name: "LoadingSkeletonTileRendering"
        when: windowShown

        function init() {
            if (Qt.platform.pluginName === "offscreen")
                skip("shaders are not run on the offscreen platform")
        }

        function brightness(c) {
            return c.r + c.g + c.b
        }

        function fuzzyCompareColor(actual, expected, message) {
            const tolerance = 2 / 255
            verify(Math.abs(actual.r - expected.r) <= tolerance
                   && Math.abs(actual.g - expected.g) <= tolerance
                   && Math.abs(actual.b - expected.b) <= tolerance,
                   `${message}: got ${actual}, expected ${expected}`)
        }

        // darkest and brightest pixel along the middle row, edges excluded
        function middleRowExtremes(image, scale) {
            const row = Math.floor(image.height / 2)
            const step = Math.max(1, Math.round(scale))
            let darkest = null
            let brightest = null
            for (let x = 2 * step; x < image.width - 2 * step; x += step) {
                const c = image.pixel(x, row)
                if (!darkest || brightness(c) < brightness(darkest))
                    darkest = c
                if (!brightest || brightness(c) > brightness(brightest))
                    brightest = c
            }
            return { darkest, brightest }
        }

        function test_draws_rounded_tile_with_moving_band() {
            const frame = createTemporaryObject(tileComp, root)
            verify(!!frame)
            const tile = frame.tile

            waitForRendering(frame)

            const image = grabImage(tile)
            const scale = image.width / tile.width
            fuzzyCompareColor(image.pixel(0, 0), Qt.color("#0000ff"),
                              "the rounded corner must leave the background visible")
            fuzzyCompareColor(middleRowExtremes(image, scale).darkest,
                              Qt.color("#404040"),
                              "the body outside the band must be the base color")

            // the band sweeps on the render thread; sample frames until it
            // crosses the middle row
            tryVerify(() => {
                const e = middleRowExtremes(grabImage(tile), scale)
                return brightness(e.brightest) > brightness(e.darkest) + 0.03
            }, 3000, "the sweep band must brighten the tile in some frame")
        }

        function test_band_sweeps_across_group_tiles_in_turn() {
            const frame = createTemporaryObject(groupComp, root)
            verify(!!frame)
            const tiles = [frame.leftTile, frame.rightTile]
            waitForRendering(frame)

            const base = brightness(Qt.color("#404040"))
            let seen = [false, false]
            let bothInOneFrame = false

            // one band crosses both tiles per loop, so over a loop each tile
            // lights up, never together
            tryVerify(() => {
                const image = grabImage(frame)
                const scale = image.width / frame.width
                const row = Math.floor(image.height / 2)
                const lit = tiles.map(tile => {
                    for (let x = tile.x + 2; x < tile.x + tile.width - 2; ++x) {
                        if (brightness(image.pixel(Math.round(x * scale), row))
                                > base + 0.03)
                            return true
                    }
                    return false
                })
                seen = seen.map((s, i) => s || lit[i])
                bothInOneFrame = bothInOneFrame || (lit[0] && lit[1])
                return seen[0] && seen[1]
            }, 3000, "the band must light each tile in some frame")
            verify(!bothInOneFrame,
                   "the band must not light tiles far apart in the same frame")
        }

        // QTBUG-151922: UniformAnimator crashed the render thread here
        function test_tiles_can_leave_the_window_while_sweeping() {
            const loader = createTemporaryObject(gridComp, root)
            verify(!!loader)

            for (let i = 0; i < 40; ++i) {
                loader.active = true
                wait(150)
                loader.active = false
                wait(10)
            }
        }

        function test_requests_frames_only_while_visible() {
            const frame = createTemporaryObject(tileComp, root)
            verify(!!frame)
            waitForRendering(frame)

            frameSpy.clear()
            tryVerify(() => frameSpy.count > 3, 2000,
                      "a visible tile must keep the window rendering")

            frame.tile.visible = false
            // let the frames already in flight finish
            wait(100)
            frameSpy.clear()
            wait(300)
            verify(frameSpy.count <= 2,
                   `a hidden tile must not request frames, got ${frameSpy.count}`)
        }
    }
}
