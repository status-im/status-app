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

        function verifyMask(popup, maskName, owner) {
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
            tryVerify(() => owner.children.some(item => item.objectName === maskName))
            const mask = owner.children.find(item => item.objectName === maskName)
            verify(!!mask)
            compare(mask.parent, owner)
            verify(mask.layer.enabled)
            verify(!mask.visible)
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

        function test_receiveMask() {
            const popup = createTemporaryObject(receiveComponent, root)
            verify(!!popup)
            const qrImage = findChild(popup, "qrCodeImage")
            verify(!!qrImage)
            verifyMask(popup, "receiveModalQrMask", qrImage.parent)
        }

        function test_pinnedMessagesMask() {
            const popup = createTemporaryObject(pinnedComponent, root)
            verify(!!popup)
            verifyMask(popup, "pinnedMessagesMask", popup.contentItem)
        }

        function test_signTransactionMask() {
            const popup = createTemporaryObject(signComponent, root)
            verify(!!popup)
            verifyMask(popup, "signTransactionFromImageMask", popup.fromImageSmartIdenticon)
        }
    }
}
