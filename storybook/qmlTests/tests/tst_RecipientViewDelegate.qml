import QtQuick
import QtTest
import QtQml

import AppLayouts.Wallet.controls

import StatusQ.Core.Theme

import utils

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: testComponent
        RecipientViewDelegate {

        }
    }

    TestCase {
        name: "RecipientViewDelegate"

        when: windowShown

        function test_empty() {
            const delegate = createTemporaryObject(testComponent, root)
            verify(delegate)

            compare(delegate.name, "")
            compare(delegate.address, "")
            compare(delegate.emoji, "")
            compare(delegate.walletColor, "")
            compare(delegate.ens, "")

            compare(delegate.title, "")
            compare(delegate.subTitle, "")
            compare(delegate.statusListItemIcon.item.identiconText.text, "")
        }

        function test_onlyAddress() {
            const delegate = createTemporaryObject(testComponent, root, { address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40" })
            verify(delegate)

            compare(delegate.address, "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40")
            compare(delegate.title, "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40")
            compare(delegate.subTitle, "")
            compare(delegate.statusListItemIcon.item.identiconText.text, "0x")
            compare(delegate.statusListItemIcon.item.identiconText.color, "#000000", "Default address-only color")
        }

        function test_titleAndSubtitle() {
            const delegate = createTemporaryObject(testComponent, root, {
                                                        address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40",
                                                        name: "Adam"
                                                   })
            verify(delegate)

            compare(delegate.name, "Adam")
            compare(delegate.address, "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40")
            compare(delegate.ens, "")

            compare(delegate.title, "Adam")
            compare(delegate.subTitle, "0xC5E4…4e40")
            compare(delegate.statusListItemIcon.item.identiconText.text, "A")

            delegate.name = "Adam Smith"
            compare(delegate.name, "Adam Smith")
            compare(delegate.title, "Adam Smith")
            compare(delegate.subTitle, "0xC5E4…4e40")
            compare(delegate.statusListItemIcon.item.identiconText.text, "AS")

            delegate.ens = "balista.eth"
            compare(delegate.ens, "balista.eth")
            compare(delegate.name, "Adam Smith")
            compare(delegate.title, "Adam Smith")
            compare(delegate.subTitle, "balista.eth")
            compare(delegate.statusListItemIcon.item.identiconText.text, "AS")
        }

        function test_emoji() {
            const delegate = createTemporaryObject(testComponent, root, {
                                                       address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40",
                                                       name: "Adam",
                                                   })
            verify(delegate)

            compare(delegate.title, "Adam")
            compare(delegate.subTitle, "0xC5E4…4e40")
            compare(delegate.emoji, "")
            compare(delegate.statusListItemIcon.item.emoji, "")

            delegate.emoji = "😋"
            compare(delegate.title, "Adam")
            compare(delegate.subTitle, "0xC5E4…4e40")
            compare(delegate.emoji, "😋")
            compare(delegate.statusListItemIcon.item.emoji, "😋")
        }

        function test_color() {
            const delegate = createTemporaryObject(testComponent, root, {
                                                       address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40",
                                                       name: "Adam",
                                                   })
            verify(delegate)

            compare(delegate.title, "Adam")
            compare(delegate.subTitle, "0xC5E4…4e40")
            compare(delegate.asset.color, "#000000")
            compare(delegate.statusListItemIcon.item.identiconText.color, "#000000")

            delegate.walletColor = "#ff0000"
            compare(delegate.asset.color, "#ff0000")
            compare(delegate.statusListItemIcon.item.identiconText.color, "#ff0000")

            delegate.walletColorId = Constants.walletAccountColors.purple
            compare(delegate.asset.color, "#ff0000", "Wallet color takes priority over colorId")
            compare(delegate.statusListItemIcon.item.identiconText.color, "#ff0000")

            delegate.walletColor = ""
            compare(delegate.asset.color, Theme.palette.customisationColors.purple)
            compare(delegate.statusListItemIcon.item.identiconText.color, Theme.palette.customisationColors.purple)

            delegate.name = ""
            compare(delegate.asset.color, Theme.palette.directColor1)
        }

        function test_hover() {
            const delegate = createTemporaryObject(testComponent, root, {
                                                       address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40",
                                                   })
            verify(delegate)

            compare(delegate.sensor.containsMouse, false)
            compare(delegate.title, "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40")
            compare(delegate.subTitle, "")

            mouseMove(delegate, 10, 10)
            compare(delegate.sensor.containsMouse, true)
            compare(delegate.title, "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40")
            compare(delegate.subTitle, "")
            mouseMove(delegate, -10, -10)
            compare(delegate.sensor.containsMouse, false)
        }

        // An own account of a profile without a password stays elided on hover
        function test_hoverKeepsRestrictedAddressElided() {
            const delegate = createTemporaryObject(testComponent, root, {
                                                       name: "Main",
                                                       address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40",
                                                       revealNeedsPassword: true
                                                   })
            verify(delegate)
            mouseMove(delegate, 10, 10)
            compare(delegate.sensor.containsMouse, true)
            compare(delegate.subTitle, "0xC5E4…4e40")
            mouseMove(delegate, -10, -10)
        }

        // Without a name the title shows the address, elided as well
        function test_titleElidedWithoutName() {
            const delegate = createTemporaryObject(testComponent, root, {
                                                       address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40",
                                                       revealNeedsPassword: true
                                                   })
            verify(delegate)
            compare(delegate.title, "0xC5E4…4e40")
        }

        function test_useAddressAsLetterIdenticon() {
            const delegate = createTemporaryObject(testComponent, root, {
                                                       address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40",
                                                       name: "Adam",
                                                       walletColor: "#ff0000"
                                                   })
            verify(delegate)
            verify(!delegate.useAddressAsLetterIdenticon, "Default is disabled")

            compare(delegate.statusListItemIcon.name, "Adam")
            compare(delegate.title, "Adam")
            compare(delegate.subTitle, "0xC5E4…4e40")
            compare(delegate.asset.color, "#ff0000")

            delegate.useAddressAsLetterIdenticon = true

            compare(delegate.statusListItemIcon.name, "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40")
            compare(delegate.title, "Adam")
            compare(delegate.subTitle, "0xC5E4…4e40")
            compare(delegate.asset.color, Theme.palette.directColor1)
        }

        function test_elideAddressInTitle() {
            const delegate = createTemporaryObject(testComponent, root, {
                                                       address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40",
                                                       name: "Adam"
                                                   })
            verify(delegate)
            verify(!delegate.elideAddressInTitle, "Default is disabled")

            compare(delegate.title, "Adam")
            compare(delegate.subTitle, "0xC5E4…4e40")

            delegate.elideAddressInTitle = true

            compare(delegate.title, "Adam", "Elide property doesn't affect title until it is an address")
            compare(delegate.subTitle, "0xC5E4…4e40")

            delegate.name = ""
            compare(delegate.title, "0xC5E4…4e40")
            delegate.elideAddressInTitle = false
            compare(delegate.title, "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40")

        }
    }
}
