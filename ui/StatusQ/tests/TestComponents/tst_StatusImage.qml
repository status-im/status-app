import QtQuick
import QtQuick.Layouts
import QtTest

import StatusQ.Components

import StatusQ.TestHelpers

Item {
    id: root

    width: 600
    height: 600

    readonly property string assets: `${Qt.resolvedUrl(".")}../../src/assets/`
    readonly property url largeRaster: root.assets + "png/status-logo-icon.png" // 1024x1024
    readonly property url hugeRaster: root.assets + "png/wallet/placeholders/mainView-light.png" // 2880x1540
    readonly property url smallRaster: root.assets + "png/wallet/wallet-green.png" // 72x72
    readonly property url tinyRaster: root.assets + "png/swap/relay.png" // 40x40, only used by the crop test
    readonly property url multiResRaster: root.assets + "png/tokens/0-native.png" // 40px + @2x + @3x
    readonly property url svgSource: root.assets + "img/icons/action-add.svg"

    Component {
        id: imageComponent

        StatusImage {}
    }

    Component {
        id: roundedImageComponent

        StatusRoundedImage {}
    }

    Component {
        id: preferredSizeLayoutComponent

        RowLayout {
            readonly property alias image: img

            StatusImage {
                id: img

                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                source: root.largeRaster
            }
        }
    }

    Component {
        id: implicitWidthLayoutComponent

        RowLayout {
            readonly property alias image: img

            StatusImage {
                id: img

                Layout.preferredHeight: 20
                source: root.largeRaster
            }
        }
    }

    MonitorQtOutput {
        id: qtOutput
    }

    StatusTestCase {
        name: "StatusImage"

        function init() {
            qtOutput.restartCapturing()
        }

        function cleanup() {
            compare(qtOutput.qtOuput(), "", "no warnings expected")
        }

        function physical(logical, item) {
            return Math.ceil(logical * item.Screen.devicePixelRatio)
        }

        // Decode step boundaries: 16 device px apart up to 128, then 1/8 of the size
        function decodeBucket(devicePx) {
            let boundary = 0
            while (boundary < devicePx)
                boundary += Math.max(16, Math.ceil(boundary / 8))
            return Math.min(boundary, 2048)
        }

        function decoded(logical, item) {
            return decodeBucket(logical * item.Screen.devicePixelRatio)
        }

        function test_rasterDecodedAtRenderedSize() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img), Qt.size(decoded(40, img), decoded(40, img)))
            compare(img.implicitWidth, 40)
        }

        function test_roundedImageDecodedAtRenderedSize() {
            const rounded = createTemporaryObject(roundedImageComponent, root,
                                                  { width: 40, height: 40, "image.source": root.largeRaster })
            tryCompare(rounded.image, "status", Image.Ready)
            compare(ImageInspector.decodedSize(rounded.image),
                    Qt.size(decoded(40, rounded.image), decoded(40, rounded.image)))
        }

        function test_rasterDecodeFitsAspect() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 100, height: 100, source: root.hugeRaster })
            tryCompare(img, "status", Image.Ready)
            const decodedSize = ImageInspector.decodedSize(img)
            compare(decodedSize.width, decoded(100, img))
            verify(decodedSize.height < decodedSize.width)
        }

        // Guards the private QQuickImageBasePrivate::updateDevicePixelRatio override in
        // RenderSizedImage: without it Qt covers the box (upscaling to 400px) and reports
        // the implicit size in decoded pixels.
        function test_privateDprHookActive() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 400, height: 200, source: root.smallRaster })
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img), Qt.size(72, 72))

            img.source = root.largeRaster
            tryCompare(img, "status", Image.Ready)
            // The square source fits the 200 side; one request ratio covers both sides of
            // the box, so that side may land up to a step above its own boundary
            const side = ImageInspector.decodedSize(img).width
            verify(side >= decoded(200, img) && side <= decoded(200, img) * 1.13, `${side}px`)
            compare(img.implicitWidth, 200)
        }

        function test_unsizedRasterDecodesOnce() {
            const img = createTemporaryObject(imageComponent, root, { source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)
            const key = ImageInspector.decodeKey(img)
            waitForRendering(img)
            compare(ImageInspector.decodeKey(img), key)
            compare(img.explicitlySized, false)
        }

        function test_cropNeverUpscalesSmallSource() {
            const first = createTemporaryObject(imageComponent, root,
                                                { width: 64, height: 64, source: root.tinyRaster,
                                                  fillMode: Image.PreserveAspectCrop })
            tryVerify(() => first.status === Image.Ready
                      && ImageInspector.decodedSize(first).width === 40)
            compare(ImageInspector.decodedSize(first), Qt.size(40, 40))

            // Once the native size is known the decode is never upscaled
            const second = createTemporaryObject(imageComponent, root,
                                                 { width: 64, height: 64, source: root.tinyRaster,
                                                   fillMode: Image.PreserveAspectCrop })
            tryCompare(second, "status", Image.Ready)
            compare(ImageInspector.decodedSize(second), Qt.size(40, 40))
        }

        function test_stretchCoversBothSides() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 100, height: 100, source: root.hugeRaster,
                                                fillMode: Image.Stretch })
            tryCompare(img, "status", Image.Ready)
            const size = ImageInspector.decodedSize(img)
            verify(size.width >= decoded(100, img) && size.height >= decoded(100, img),
                   `${size.width}x${size.height}`)
            verify(size.width <= 2880 && size.height <= 1540)
        }

        function test_coverDecodeCappedForExtremeAspect() {
            for (const fillMode of [Image.PreserveAspectCrop, Image.Stretch]) {
                const img = createTemporaryObject(imageComponent, root,
                                                  { width: 4000, height: 1, fillMode: fillMode })
                let largest = 0
                img.paintedGeometryChanged.connect(() => {
                    const size = ImageInspector.decodedSize(img)
                    largest = Math.max(largest, size.width, size.height)
                })
                img.source = root.hugeRaster
                tryCompare(img, "status", Image.Ready)
                waitForRendering(img)
                verify(largest <= 2048, `decoded ${largest}px`)
                verify(ImageInspector.decodedSize(img).width >= 2047,
                       `${ImageInspector.decodedSize(img)}`)
            }
        }

        function test_tiledImageKeepsNativeDecode() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.largeRaster,
                                                fillMode: Image.Tile })
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img), Qt.size(1024, 1024))
        }

        function test_smallRasterNotUpscaled() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 400, height: 400, source: root.smallRaster })
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img), Qt.size(72, 72))
            compare(img.implicitWidth, 72)
        }

        function test_multiResolutionAssetKeepsLogicalSize() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.multiResRaster })
            tryCompare(img, "status", Image.Ready)
            compare(img.implicitWidth, 40)
            // Qt picks the @Nx variant for ceil(dpr)
            verify(ImageInspector.decodedSize(img).width <= 40 * Math.ceil(img.Screen.devicePixelRatio))
        }

        function test_rasterDecodeCapped() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 4000, height: 4000, source: root.hugeRaster })
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img).width, 2048)
        }

        function test_unsizedRasterKeepsNativeSize() {
            const img = createTemporaryObject(imageComponent, root, { source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img), Qt.size(1024, 1024))
            compare(img.width, 1024)
        }

        function test_heightOnlyRasterKeepsAspectWidth() {
            const img = createTemporaryObject(imageComponent, root,
                                              { height: 20, source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)
            compare(img.width, 20)
            compare(ImageInspector.decodedSize(img), Qt.size(decoded(20, img), decoded(20, img)))
        }

        function test_rasterDecodeFollowsResize() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)

            img.width = 200
            img.height = 200
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img).width, decoded(200, img))

            img.width = 40
            img.height = 40
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img).width, decoded(40, img))
        }

        function test_smallImageDecodedNearItsSize() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)
            verify(ImageInspector.decodedSize(img).width <= physical(40, img) + 16,
                   `decoded ${ImageInspector.decodedSize(img).width}px for ${physical(40, img)}px`)
        }

        function test_decodeStepCostsAtMostAQuarter() {
            for (const size of [24, 40, 64, 100, 333, 700]) {
                const img = createTemporaryObject(imageComponent, root,
                                                  { width: size, height: size, source: root.hugeRaster })
                tryCompare(img, "status", Image.Ready)
                const exact = Math.ceil(size * img.Screen.devicePixelRatio)
                const width = ImageInspector.decodedSize(img).width
                if (exact >= 128)
                    verify(width * width <= 1.27 * exact * exact, `${width}px for ${exact}px`)
                else
                    verify(width <= exact + 16, `${width}px for ${exact}px`)
            }
        }

        function test_resizeWithinDecodeStepKeepsDecode() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)
            const key = ImageInspector.decodeKey(img)
            const stepEnd = Math.floor(decoded(40, img) / img.Screen.devicePixelRatio)

            for (let size = 41; size <= stepEnd; ++size) {
                img.width = size
                img.height = size
                compare(ImageInspector.decodeKey(img), key, `re-decoded at ${size}px`)
                compare(img.implicitWidth, size)
            }
        }

        function test_resizeAcrossDecodeStepDecodesOnce() {
            // Wide source in a tall box: only the width constrains the decode
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 400, source: root.hugeRaster })
            tryCompare(img, "status", Image.Ready)
            const keys = [ImageInspector.decodeKey(img)]
            const next = Math.floor(decoded(40, img) / img.Screen.devicePixelRatio) + 1

            const last = Math.floor(decoded(next, img) / img.Screen.devicePixelRatio)
            for (let size = 41; size <= last; ++size) {
                img.width = size
                tryCompare(img, "status", Image.Ready)
                const key = ImageInspector.decodeKey(img)
                if (key !== keys[keys.length - 1])
                    keys.push(key)
            }
            compare(keys.length, 2, "exactly one re-decode when crossing the step")
            compare(ImageInspector.decodedSize(img).width, decoded(next, img))
            compare(img.implicitWidth, last)
        }

        function test_rasterInLayoutDecodedAtPreferredSize() {
            const layout = createTemporaryObject(preferredSizeLayoutComponent, root)
            waitForPolish(layout)
            tryCompare(layout.image, "status", Image.Ready)
            compare(ImageInspector.decodedSize(layout.image).width, decoded(40, layout.image))
        }

        function test_rasterInLayoutSizedByImplicitWidth() {
            const layout = createTemporaryObject(implicitWidthLayoutComponent, root)
            waitForPolish(layout)
            tryCompare(layout.image, "status", Image.Ready)
            compare(layout.image.width, 20)
            compare(layout.image.height, 20)
            compare(ImageInspector.decodedSize(layout.image).width, decoded(20, layout.image))
        }

        function test_svgRenderedAtItemSize() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.svgSource })
            tryCompare(img, "status", Image.Ready)
            compare(img.sourceSize, Qt.size(40, 40))
            compare(img.implicitWidth, 40)
            compare(ImageInspector.decodedSize(img), Qt.size(physical(40, img), physical(40, img)))
        }
    }
}
