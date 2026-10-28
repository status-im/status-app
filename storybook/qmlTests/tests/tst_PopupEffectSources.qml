import QtQuick
import QtTest

import Models
import AppLayouts.Chat.popups
import AppLayouts.Wallet.popups

Item {
    id: root
    width: 1000
    height: 800

    Component {
        id: receiveComponent
        ReceiveModal {
            accounts: WalletAccountsModel {}
            selectedAccount: ({
                name: "Wallet",
                emoji: "",
                colorId: "primary",
                address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881",
                mixedcaseAddress: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881"
            })
            switchingAccounsEnabled: false
            qrImageSource: ""
        }
    }

    Component {
        id: pinnedComponent
        PinnedMessagesPopup {
            pinnedMessagesModel: ListModel {}
        }
    }

    Component {
        id: signComponent
        SignTransactionModalBase {
            keyUid: ""
            migratedToColdWallet: false
            formatBigNumber: (number) => number
            fromImageSource: "status"
            toImageSource: "status"
        }
    }

    TestCase {
        name: "PopupEffectSources"
        when: windowShown

        function init() {
            failOnWarning(/Unable to assign .* to QQuickItem/)
            failOnWarning(/QQuickShaderEffectSource::textureProvider/)
        }

        // The popup renders, and renders the same after being reopened.
        function verifyRendersAndReopens(popup) {
            verify(waitForPolish(popup.contentItem))
            const image = grabImage(popup.contentItem)
            verify(image.width > 0 && image.height > 0)
            popup.close()
            tryCompare(popup, "visible", false)
            popup.open()
            tryCompare(popup, "opened", true)
            verify(waitForPolish(popup.contentItem))
            const reopenedImage = grabImage(popup.contentItem)
            compare(reopenedImage.width, image.width)
            compare(reopenedImage.height, image.height)
        }

        // A layer-effect-rounded item: its layer is on, and the popup renders.
        function verifyRoundedLayer(popup, owner) {
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
            verify(owner.layer.enabled)
            verify(!!owner.layer.effect)
            verifyRendersAndReopens(popup)
        }

        function test_receiveQrCorners() {
            const popup = createTemporaryObject(receiveComponent, root)
            verify(!!popup)
            const qrImage = findChild(popup, "qrCodeImage")
            verify(!!qrImage)
            verifyRoundedLayer(popup, qrImage.parent)
        }

        function test_pinnedMessagesCorners() {
            const popup = createTemporaryObject(pinnedComponent, root)
            verify(!!popup)
            verifyRoundedLayer(popup, popup.contentItem)
        }

        function test_signTransactionFromImageCutout() {
            const popup = createTemporaryObject(signComponent, root)
            verify(!!popup)
            verifyRoundedLayer(popup, popup.fromImageSmartIdenticon)
        }
    }
}
