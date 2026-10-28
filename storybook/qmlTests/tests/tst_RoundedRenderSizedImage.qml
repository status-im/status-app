import QtQuick
import QtTest

import StatusQ.Components.private

Item {
    id: root

    width: 200
    height: 200

    // solid red, 64 x 32
    readonly property url redImage: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAWElEQVR4nO3QMREAMBDDsPAn/YWhoR60+7zb7mfTAVoDdIDWAB2gNUAHaA3QAVoDdIDWAB2gNUAHaA3QAVoDdIDWAB2gNUAHaA3QAVoDdIDWAB2gNUAHaA8g8vDiJft7OwAAAABJRU5ErkJggg=="

    Component {
        id: imageComponent

        RoundedRenderSizedImage {
            width: 64
            height: 64
            source: root.redImage
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
        }
    }

    TestCase {
        name: "RoundedRenderSizedImage"
        when: windowShown

        readonly property bool software: root.GraphicsInfo.api === GraphicsInfo.Software

        function createImage(properties) {
            const image = createTemporaryObject(imageComponent, root, properties)
            verify(!!image)
            tryCompare(image, "status", Image.Ready)
            return image
        }

        function grab(image) {
            if (software)
                skip("the rounded node is not used by the software renderer")
            return grabImage(image)
        }

        function isRed(color) {
            return color.r > 0.9 && color.g < 0.1 && color.b < 0.1
        }

        function isGreen(color) {
            return color.g > 0.9 && color.r < 0.1 && color.b < 0.1
        }

        function isBlue(color) {
            return color.b > 0.9 && color.r < 0.1 && color.g < 0.1
        }

        // the border runs inside the item, as a Rectangle's: a 72 px item at
        // (4, 4), so the 64 px image inside its 4 px border is at (8, 8)
        function grabBordered(properties) {
            return grabScene(Object.assign({ x: 4, y: 4, width: 72, height: 72,
                                             "border.width": 4, "border.color": "blue" },
                                           properties))
        }

        function grabScene(properties) {
            const image = createTemporaryObject(imageComponent, root,
                                                Object.assign({ x: 8, y: 8 }, properties))
            verify(!!image)
            if (image.source.toString() !== "")
                tryCompare(image, "status", Image.Ready)
            if (software)
                skip("the rounded node is not used by the software renderer")
            return grabImage(root)
        }

        function test_cornersAreRoundedAndTheRestIsDrawn() {
            const img = grab(createImage({ radius: 16 }))

            verify(!isRed(img.pixel(1, 1)), "top-left corner is cut")
            verify(!isRed(img.pixel(62, 1)), "top-right corner is cut")
            verify(!isRed(img.pixel(1, 62)), "bottom-left corner is cut")
            verify(!isRed(img.pixel(62, 62)), "bottom-right corner is cut")
            verify(isRed(img.pixel(32, 32)), "centre is drawn")
            verify(isRed(img.pixel(32, 1)), "straight edge is drawn")
            verify(isRed(img.pixel(1, 32)), "straight edge is drawn")
        }

        function test_eachCornerHasItsOwnRadius() {
            const image = createImage({ radius: 16, bottomLeftRadius: 0 })
            compare(image.topLeftRadius, 16)
            const img = grab(image)

            verify(isRed(img.pixel(1, 62)), "square bottom-left corner is drawn")
            verify(!isRed(img.pixel(62, 62)), "bottom-right corner is still cut")
        }

        function test_radiusIsClampedToHalfTheShorterSide() {
            const img = grab(createImage({ height: 32, radius: 1000 }))

            verify(isRed(img.pixel(1, 16)), "left end is a half circle, not empty")
            verify(isRed(img.pixel(32, 1)), "straight top edge is drawn")
            verify(!isRed(img.pixel(1, 1)), "corner is cut")
        }

        function test_fitRoundsTheLetterboxedImage() {
            const image = createImage({ fillMode: Image.PreserveAspectFit, radius: 8 })
            compare(image.paintedHeight, 32)
            const img = grab(image)

            verify(!isRed(img.pixel(32, 8)), "letterbox stays empty")
            verify(isRed(img.pixel(32, 32)), "image is drawn")
            verify(!isRed(img.pixel(1, 17)), "corner of the painted image is cut")
            verify(isRed(img.pixel(1, 32)), "side of the painted image is drawn")
        }

        function test_cutoutCutsACircle() {
            const img = grab(createImage({ cutoutCenter: Qt.point(64, 32), cutoutRadius: 20 }))

            verify(!isRed(img.pixel(60, 32)), "inside the circle is cut")
            verify(!isRed(img.pixel(50, 32)), "inside the circle is cut")
            verify(isRed(img.pixel(40, 32)), "outside the circle is drawn")
            verify(isRed(img.pixel(62, 2)), "the corner outside the circle is drawn")
        }

        function test_tiledImageIsRounded() {
            const img = grab(createImage({ fillMode: Image.Tile, radius: 16 }))

            verify(!isRed(img.pixel(1, 1)), "the corner is cut")
            verify(isRed(img.pixel(32, 32)), "the tiles are drawn")
            verify(isRed(img.pixel(62, 40)), "the tiles are drawn")
        }

        function test_borderIsDrawnAroundTheShape() {
            // the radius is the outer edge's, as Rectangle's: 16 outside, 12 inside
            const img = grabBordered({ radius: 16 })

            verify(isBlue(img.pixel(40, 6)), "the border runs along the top, around the image")
            verify(isBlue(img.pixel(74, 40)), "the border runs along the right, around the image")
            verify(!isBlue(img.pixel(40, 2)) && !isRed(img.pixel(40, 2)), "nothing beyond it")
            verify(isRed(img.pixel(40, 40)), "the image is drawn inside")
            verify(!isBlue(img.pixel(5, 5)), "the outer corner is rounded")
            verify(isBlue(img.pixel(10, 10)), "the inner corner is rounded less")
        }

        function test_squareCornersStaySquareWithABorder() {
            const img = grabBordered({ radius: 0 })

            verify(isBlue(img.pixel(4, 4)), "the outer corner is square")
            // its first pixel is half under the border
            verify(isRed(img.pixel(9, 9)), "the image's corner is drawn")
        }

        function test_noSeamBetweenBorderAndImage() {
            const img = grabBordered({ radius: 36 })

            // the diagonal from the border into the image: blue and red
            // only, nothing behind
            for (let i = 16; i <= 22; i++) {
                const c = img.pixel(i, i)
                verify(c.g < 0.1 && c.a > 0.99, `no seam at (${i}, ${i}): ${c}`)
            }
        }

        function test_borderAloneWithNoImage() {
            const img = grabBordered({ source: "", radius: 16 })

            verify(isBlue(img.pixel(40, 6)), "the border is drawn")
            verify(!isBlue(img.pixel(40, 40)) && !isRed(img.pixel(40, 40)), "inside is empty")
        }

        function test_cutoutCutsTheBorderToo() {
            // at (72, 40) in the scene
            const img = grabBordered({ cutoutCenter: Qt.point(68, 36), cutoutRadius: 16 })

            verify(!isBlue(img.pixel(74, 40)), "the border is cut")
            verify(isBlue(img.pixel(74, 12)), "the border outside the circle is drawn")
        }

        function test_backgroundIsDrawnUnderTheImage() {
            // a 2:1 image fitted into the 64 x 64 item: letterboxed
            const img = grabBordered({ fillMode: Image.PreserveAspectFit, radius: 8,
                                       roundedArea: RoundedRenderSizedImage.ItemArea,
                                       backgroundColor: "lime" })

            verify(isGreen(img.pixel(40, 16)), "the letterbox shows the background")
            verify(isRed(img.pixel(40, 40)), "the image is over it")
            verify(isBlue(img.pixel(40, 6)), "the border is around it")
        }

        function test_backgroundAloneWithNoImage() {
            const img = grabBordered({ source: "", "border.width": 0, backgroundColor: "lime",
                                       radius: 16 })

            verify(isGreen(img.pixel(40, 40)), "the background is drawn")
            verify(!isGreen(img.pixel(5, 5)), "rounded")
        }

        function test_theUnsetBorderIsTheBackgrounds() {
            // as a Rectangle's: 1 px wide until set, and not drawn; the item
            // at (8, 8)
            const img = grabScene({ backgroundColor: "lime", unsetBorderWidth: 1 })

            verify(isGreen(img.pixel(8, 40)), "the background fills the band")
            verify(isRed(img.pixel(9, 40)), "the image is inside it")
            verify(!isGreen(img.pixel(7, 40)), "nothing outside the item")
        }

        function test_mirroredImageIsRounded() {
            const img = grab(createImage({ radius: 16, mirror: true, mirrorVertically: true }))

            verify(!isRed(img.pixel(1, 1)), "the corner is cut")
            verify(isRed(img.pixel(32, 32)), "the image is drawn")
        }

        // a 2:1 image fitted into 128 x 128: painted 128 x 64 at y 32
        function test_itemAreaClipsTheLetterboxedImageToTheBox() {
            const props = { width: 128, height: 128, radius: 64,
                            fillMode: Image.PreserveAspectFit }
            const painted = grab(createImage(props))
            props.roundedArea = RoundedRenderSizedImage.ItemArea
            const box = grab(createImage(props))

            // inside the box's circle, outside the painted image's stadium
            verify(!isRed(painted.pixel(5, 42)), "the painted image's end is rounded")
            verify(isRed(box.pixel(5, 42)), "the box's circle leaves it drawn")
            verify(!isRed(box.pixel(1, 33)), "the box's circle cuts the corner")
            verify(!isRed(box.pixel(64, 16)), "the letterbox stays empty")
        }
    }
}
