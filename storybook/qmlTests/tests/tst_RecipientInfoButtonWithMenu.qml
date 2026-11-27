import QtQuick
import QtTest

import StatusQ

import AppLayouts.Wallet.panels

import utils

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: buttonComponent
        RecipientInfoButtonWithMenu {
            recipientAddress: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40"
            networkName: "Mainnet"
            networkShortName: "eth"
            networkBlockExplorerUrl: "https://etherscan.io"
        }
    }

    SignalSpy { id: openLinkSpy; signalName: "openLink" }
    SignalSpy { id: copyGateSpy; target: Global; signalName: "copyOwnAddressRequested" }
    SignalSpy { id: linkGateSpy; target: Global; signalName: "openOwnAddressLinkRequested" }

    TestCase {
        name: "RecipientInfoButtonWithMenu"
        when: windowShown

        function init() {
            openLinkSpy.clear()
            copyGateSpy.clear()
            linkGateSpy.clear()
            ClipboardUtils.setText("before")
        }

        function openMenu(props) {
            const button = createTemporaryObject(buttonComponent, root, props ?? {})
            openLinkSpy.target = button
            mouseClick(button)
            const menu = findChild(button, "moreMenu")
            tryCompare(menu, "opened", true)
            return menu
        }

        function test_otherRecipient() {
            let menu = openMenu()
            findChild(menu, "externalLink").trigger()
            compare(openLinkSpy.count, 1)
            compare(linkGateSpy.count, 0)

            menu = openMenu()
            mouseClick(findChild(menu, "copyButton"))
            compare(ClipboardUtils.text, "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40")
            compare(copyGateSpy.count, 0)
        }

        // An address that needs a password goes through the gates
        function test_ownRecipient() {
            let menu = openMenu({ revealNeedsPassword: true })
            findChild(menu, "externalLink").trigger()
            compare(openLinkSpy.count, 0)
            compare(linkGateSpy.count, 1)

            menu = openMenu({ revealNeedsPassword: true })
            mouseClick(findChild(menu, "copyButton"))
            compare(copyGateSpy.count, 1)
            compare(ClipboardUtils.text, "before")
        }
    }
}
