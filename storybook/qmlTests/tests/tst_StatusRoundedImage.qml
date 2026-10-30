import QtQuick
import QtTest

import StatusQ.Components

Item {
    id: root

    width: 200
    height: 200

    // solid red, 64 x 32
    readonly property url redImage: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAWElEQVR4nO3QMREAMBDDsPAn/YWhoR60+7zb7mfTAVoDdIDWAB2gNUAHaA3QAVoDdIDWAB2gNUAHaA3QAVoDdIDWAB2gNUAHaA3QAVoDdIDWAB2gNUAHaA8g8vDiJft7OwAAAABJRU5ErkJggg=="

    Component {
        id: unsizedComponent

        StatusRoundedImage {}
    }

    Component {
        id: imageComponent

        StatusRoundedImage {
            width: 40
            height: 40
            image.source: root.redImage
            image.fillMode: Image.PreserveAspectCrop
        }
    }

    TestCase {
        name: "StatusRoundedImage"
        when: windowShown

        readonly property bool software: root.GraphicsInfo.api === GraphicsInfo.Software

        function createImage(properties) {
            const image = createTemporaryObject(imageComponent, root, properties)
            verify(!!image)
            tryCompare(image.image, "status", Image.Ready)
            return image
        }

        function grab(image) {
            if (software)
                skip("the software renderer draws the image unrounded")
            return grabImage(image)
        }

        function isRed(color) {
            return color.r > 0.9 && color.g < 0.1 && color.b < 0.1
        }

        function isBlue(color) {
            return color.b > 0.9 && color.r < 0.1 && color.g < 0.1
        }

        function test_imageIsTheItemItself() {
            const image = createImage({})

            compare(image.image, image)
            compare(image.source, root.redImage)
            compare(image.fillMode, Image.PreserveAspectCrop)
        }

        function test_neitherLoadingNorErrorOnceReady() {
            const image = createImage({})

            compare(image.isLoading, false)
            compare(image.isError, false)
        }

        function test_anUnsetBorderByDefault() {
            const image = createImage({})

            // as Rectangle's: 1 px, not drawn
            compare(image.border.width, 1)
        }

        function test_noSizeOfItsOwn() {
            const image = createTemporaryObject(unsizedComponent, root)
            verify(!!image)

            compare(image.width, 0)
            compare(image.height, 0)
        }

        function test_insetByTheBorderAsWithinARectangle() {
            const img = grab(createImage({ radius: 0, "border.width": 4,
                                           "border.color": "blue" }))

            verify(isBlue(img.pixel(1, 20)), "the border runs inside the edge")
            verify(isBlue(img.pixel(38, 20)), "the border runs inside the edge")
            verify(isRed(img.pixel(5, 20)), "the image is inside the border")
            verify(isRed(img.pixel(34, 20)), "the image is inside the border")
        }

        function test_aFullCircleByDefault() {
            const img = grab(createImage({}))

            // as within a Rectangle: inset by the unset border's 1 px
            verify(isRed(img.pixel(1, 20)), "the circle reaches the border")
            verify(isRed(img.pixel(20, 1)), "the circle reaches the border")
            verify(!isRed(img.pixel(0, 20)), "the unset border is empty")
            verify(!isRed(img.pixel(3, 3)), "the corner is cut")
        }

        function test_theBackgroundFillsTheUnsetBorder() {
            const img = grab(createImage({ color: "blue" }))

            verify(isBlue(img.pixel(0, 20)), "the background reaches the box's edge")
            verify(isRed(img.pixel(1, 20)), "the image is inset")
        }

        function test_aBorderColorAloneDrawsTheBorder() {
            const img = grab(createImage({ "border.color": "blue" }))

            verify(isBlue(img.pixel(0, 20)), "a 1 px border is drawn")
            verify(isRed(img.pixel(1, 20)), "the image is inside")
        }

        function test_eachCornerHasItsOwnRadius() {
            const img = grab(createImage({ radius: 12, bottomLeftRadius: 0 }))

            verify(isRed(img.pixel(1, 38)), "the square bottom-left corner is drawn")
            verify(!isRed(img.pixel(1, 1)), "the top-left corner is cut")
            verify(!isRed(img.pixel(38, 38)), "the bottom-right corner is cut")
        }

        function test_theBorderRingIsComplete() {
            const img = grab(createImage({ "border.width": 4, "border.color": "blue" }))

            // on the diagonal, inside the outer circle and outside the inner one
            verify(isBlue(img.pixel(7, 7)), "the border shows on the diagonal")
            verify(isBlue(img.pixel(20, 1)), "the border shows on the axis")
            verify(isRed(img.pixel(20, 20)), "the image is drawn inside")
        }

        function test_noSeamBetweenBorderAndImage() {
            const img = grab(createImage({ "border.width": 4, "border.color": "blue" }))

            // on the diagonal, from inside the outer edge into the image: the
            // inner edge of the border mixes blue and red only, nothing behind
            for (let i = 7; i <= 12; i++) {
                const c = img.pixel(i, i)
                verify(c.g < 0.1 && c.a > 0.99, `no seam at (${i}, ${i}): ${c}`)
            }
        }

        function test_theBorderIsDrawnWithNoImage() {
            const image = createTemporaryObject(imageComponent, root,
                                                { "image.source": "", "border.width": 4,
                                                  "border.color": "blue" })
            const img = grab(image)

            verify(isBlue(img.pixel(20, 1)), "the border is drawn")
            verify(!isBlue(img.pixel(20, 20)), "inside is empty")
        }

        function test_loadingIndicatorShowsWhileLoading() {
            const image = createTemporaryObject(imageComponent, root,
                                                { showLoadingIndicator: true,
                                                  "image.source": "" })
            image.isLoading = true

            verify(image.children.some(c => c instanceof Loader && c.active))
        }
    }
}
