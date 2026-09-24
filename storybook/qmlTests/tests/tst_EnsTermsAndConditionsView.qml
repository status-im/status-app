import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Profile.views

Item {
    id: root

    width: 800
    height: 700

    Component {
        id: componentUnderTest

        EnsTermsAndConditionsView {
            anchors.fill: parent

            username: "vbfhgg"
            walletAddress: "0x44ddd47a0c7881a5b0fa080a56cbb7701db4bb43"
            pubkey: "0x0400112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
            sntBalance: 100
        }
    }

    TestCase {
        name: "EnsTermsAndConditionsView"
        when: windowShown

        property EnsTermsAndConditionsView controlUnderTest: null
        readonly property real coordinateTolerance: 1

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            controlUnderTest = null
            root.width = 800
        }

        function getRegisterButton() {
            const button = findChild(controlUnderTest, "ensStartTransaction")
            verify(!!button)
            return button
        }

        function test_registerRequiresTermsAndBalance() {
            const checkbox = findChild(controlUnderTest, "ensAgreeTerms")
            const registerButton = getRegisterButton()
            verify(!!checkbox)

            compare(registerButton.enabled, false)

            mouseClick(checkbox)
            tryCompare(checkbox, "checked", true)
            tryCompare(registerButton, "enabled", true)

            controlUnderTest.sntBalance = 5
            compare(registerButton.text, qsTr("Not enough SNT"))
            compare(registerButton.enabled, false)

            controlUnderTest.sntBalance = 10
            compare(registerButton.text, qsTr("Register"))
            tryCompare(registerButton, "enabled", true)
        }

        function test_registerButtonAnchoredBottomRight() {
            const registerButton = getRegisterButton()
            const backButton = findChild(controlUnderTest, "ensBackButton")
            verify(!!backButton)

            const padding = Theme.padding
            const topLeft = registerButton.mapToItem(controlUnderTest, 0, 0)
            const bottomRight = registerButton.mapToItem(controlUnderTest,
                                                        registerButton.width,
                                                        registerButton.height)
            const backBottom = backButton.mapToItem(controlUnderTest, 0, backButton.height).y

            verify(Math.abs(bottomRight.x - (controlUnderTest.width - padding)) <= coordinateTolerance,
                   "right edge " + bottomRight.x + " vs " + (controlUnderTest.width - padding))
            verify(Math.abs(bottomRight.y - backBottom) <= coordinateTolerance,
                   "register bottom " + bottomRight.y + " vs back bottom " + backBottom)
            verify(topLeft.x > controlUnderTest.width / 2)
        }

        function createAtWidth(width, props) {
            if (controlUnderTest)
                controlUnderTest.destroy()
            root.width = width
            controlUnderTest = createTemporaryObject(componentUnderTest, root, props || {})
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function verifyFooterFits() {
            const registerButton = getRegisterButton()
            const backButton = findChild(controlUnderTest, "ensBackButton")
            verify(!!backButton)

            const padding = Theme.padding
            const backRight = backButton.mapToItem(controlUnderTest, backButton.width, 0).x
            const registerLeft = registerButton.mapToItem(controlUnderTest, 0, 0).x
            const registerRight = registerButton.mapToItem(controlUnderTest, registerButton.width, 0).x

            verify(backRight < registerLeft,
                   "back " + backRight + " overlaps register at " + registerLeft)
            verify(registerRight <= controlUnderTest.width - padding + coordinateTolerance,
                   "register clips past " + (controlUnderTest.width - padding))
        }

        function test_footerDoesNotOverlapAtNarrowWidth() {
            createAtWidth(360)
            verifyFooterFits()
        }

        function test_insufficientBalanceFooterFitsAtNarrowWidth() {
            createAtWidth(360, { sntBalance: 5 })
            compare(getRegisterButton().text, qsTr("Not enough SNT"))
            verifyFooterFits()
        }
    }
}
