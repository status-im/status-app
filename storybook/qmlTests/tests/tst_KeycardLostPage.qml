import QtQuick
import QtTest

import AppLayouts.Onboarding.pages

import utils

Item {
    id: root

    width: 800
    height: 700

    Component {
        id: componentUnderTest

        KeycardLostPage {
            width: root.width
            height: root.height
        }
    }

    SignalSpy {
        id: openLinkSpy
        signalName: "requestOpenLink"
    }

    TestCase {
        name: "KeycardLostPage"
        when: windowShown

        function test_buyNewOpensPurchaseLink() {
            const page = createTemporaryObject(componentUnderTest, root)
            verify(!!page)

            openLinkSpy.target = page
            openLinkSpy.clear()

            const buyNew = findChild(page, "keycardLostBuyNew")
            verify(!!buyNew)
            compare(buyNew.title, "Buy new")

            mouseClick(buyNew)
            compare(openLinkSpy.count, 1)
            compare(openLinkSpy.signalArguments[0][0], Constants.keycard.general.purchasePage)
        }
    }
}
