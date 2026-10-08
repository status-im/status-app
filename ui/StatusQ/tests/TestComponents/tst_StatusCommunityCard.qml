import QtQuick
import QtTest

import StatusQ.Components

import StatusQ.TestHelpers

Item {
    id: root

    width: 600
    height: 600

    readonly property url largeRaster: `${Qt.resolvedUrl(".")}../../src/assets/png/status-logo-icon.png` // 1024x1024

    Component {
        id: cardComponent

        StatusCommunityCard {
            banner: root.largeRaster
        }
    }

    MonitorQtOutput {
        id: qtOutput
    }

    StatusTestCase {
        name: "StatusCommunityCard"

        // Absorbs the one-time "Populating font family aliases" warning
        function initTestCase() {
            const text = createTemporaryQmlObject(
                           'import QtQuick; Text { text: "x"; font.family: "Sans Serif" }', root)
            waitForRendering(text)
        }

        function init() {
            qtOutput.restartCapturing()
        }

        function findBanner(item) {
            if (item instanceof Image && item.source === root.largeRaster)
                return item
            for (const child of item.children) {
                const found = findBanner(child)
                if (found)
                    return found
            }
            return null
        }

        function test_bannerDecodedAtRenderedSize() {
            const card = createTemporaryObject(cardComponent, root)
            const banner = findBanner(card)
            verify(!!banner)
            tryCompare(banner, "status", Image.Ready)

            // PreserveAspectCrop covers the banner box: a square source is decoded at the
            // box width rounded up to the next decode step
            const devicePx = banner.width * banner.Screen.devicePixelRatio
            let expected = 0
            while (expected < devicePx)
                expected += Math.max(16, Math.ceil(expected / 8))
            expected = Math.min(expected, 1024) // never above the native size
            compare(ImageInspector.decodedSize(banner), Qt.size(expected, expected))
            compare(qtOutput.qtOuput(), "")
        }
    }
}
