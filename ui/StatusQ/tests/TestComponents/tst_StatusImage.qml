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

        function test_rasterDecodedAtRenderedSize() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img), Qt.size(physical(40, img), physical(40, img)))
            compare(img.implicitWidth, 40)
        }

        function test_roundedImageDecodedAtRenderedSize() {
            const rounded = createTemporaryObject(roundedImageComponent, root,
                                                  { width: 40, height: 40, "image.source": root.largeRaster })
            tryCompare(rounded.image, "status", Image.Ready)
            compare(ImageInspector.decodedSize(rounded.image),
                    Qt.size(physical(40, rounded.image), physical(40, rounded.image)))
        }

        function test_rasterDecodeFitsAspect() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 100, height: 100, source: root.hugeRaster })
            tryCompare(img, "status", Image.Ready)
            const decoded = ImageInspector.decodedSize(img)
            compare(decoded.width, physical(100, img))
            verify(decoded.height < decoded.width)
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
            compare(ImageInspector.decodedSize(img), Qt.size(physical(200, img), physical(200, img)))
            compare(img.implicitWidth, 200)
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
            verify(ImageInspector.decodedSize(img).width <= physical(40, img))
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
            compare(ImageInspector.decodedSize(img), Qt.size(physical(20, img), physical(20, img)))
        }

        function test_rasterDecodeFollowsResize() {
            const img = createTemporaryObject(imageComponent, root,
                                              { width: 40, height: 40, source: root.largeRaster })
            tryCompare(img, "status", Image.Ready)

            img.width = 200
            img.height = 200
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img).width, physical(200, img))

            img.width = 40
            img.height = 40
            tryCompare(img, "status", Image.Ready)
            compare(ImageInspector.decodedSize(img).width, physical(40, img))
        }

        function test_rasterInLayoutDecodedAtPreferredSize() {
            const layout = createTemporaryObject(preferredSizeLayoutComponent, root)
            waitForPolish(layout)
            tryCompare(layout.image, "status", Image.Ready)
            compare(ImageInspector.decodedSize(layout.image).width, physical(40, layout.image))
        }

        function test_rasterInLayoutSizedByImplicitWidth() {
            const layout = createTemporaryObject(implicitWidthLayoutComponent, root)
            waitForPolish(layout)
            tryCompare(layout.image, "status", Image.Ready)
            compare(layout.image.width, 20)
            compare(layout.image.height, 20)
            compare(ImageInspector.decodedSize(layout.image).width, physical(20, layout.image))
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
