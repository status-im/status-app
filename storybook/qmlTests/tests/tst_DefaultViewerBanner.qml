import QtQuick
import QtTest

import AppLayouts.Browser.panels

Item {
    id: root

    width: 600
    height: 200

    Component {
        id: bannerComponent

        DefaultViewerBanner {
            width: 600
            typeName: "PDFs"
        }
    }

    Component {
        id: signalSpy
        SignalSpy {}
    }

    TestCase {
        name: "DefaultViewerBanner"
        when: windowShown

        function spy(target, signalName) {
            return createTemporaryObject(signalSpy, root, { target, signalName })
        }

        function test_choosingAsksTheSystem() {
            const banner = createTemporaryObject(bannerComponent, root)
            const accepted = spy(banner, "acceptRequested")
            const acknowledged = spy(banner, "acknowledged")
            mouseClick(findChild(banner, "defaultViewerAcceptButton"))
            compare(accepted.count, 1)
            compare(acknowledged.count, 0)
        }

        function test_hintsAtAnotherAppOnTopOnlyWhenAndroidAsks() {
            const banner = createTemporaryObject(bannerComponent, root)
            verify(findChild(banner, "defaultViewerHint").visible)
            banner.otherApp = "Drive"
            verify(!findChild(banner, "defaultViewerHint").visible)
            banner.otherApp = ""
            banner.confirmed = true
            verify(!findChild(banner, "defaultViewerHint").visible)
        }

        function test_aConfirmationIsOnlyAcknowledged() {
            const banner = createTemporaryObject(bannerComponent, root, { confirmed: true })
            const accepted = spy(banner, "acceptRequested")
            const acknowledged = spy(banner, "acknowledged")
            verify(!findChild(banner, "defaultViewerNotNowButton").visible)
            mouseClick(findChild(banner, "defaultViewerAcceptButton"))
            compare(acknowledged.count, 1)
            compare(accepted.count, 0)
        }
    }
}
