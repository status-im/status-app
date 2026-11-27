import QtQuick
import QtTest

import AppLayouts.Browser

Item {
    id: root

    Component {
        id: deliveryComponent

        OpenedFileDelivery {}
    }

    Component {
        id: browserComponent

        QtObject {
            property var opened: []

            function openOpenedFile(fileUrl, refused) {
                opened.push({ url: fileUrl, refused: refused })
            }
        }
    }

    // What the browser section shows in privacy mode: no way to open a file.
    Component {
        id: privacyWallComponent

        QtObject {}
    }

    TestCase {
        name: "OpenedFileDelivery"

        property var released: []
        property var messages: []
        property int browserShown: 0

        function createDelivery(browserEnabled, browser) {
            released = []
            messages = []
            browserShown = 0
            const delivery = createTemporaryObject(deliveryComponent, root, {
                browserEnabled: browserEnabled
            })
            delivery.browserFn = () => browser
            delivery.showBrowserFn = () => browserShown++
            delivery.releaseFn = fileUrl => released.push(fileUrl)
            delivery.notifyFn = message => messages.push(message)
            return delivery
        }

        function test_aFileOpensInTheBrowser() {
            const browser = createTemporaryObject(browserComponent, root)
            const delivery = createDelivery(true, browser)

            delivery.deliver("file:///tmp/a.pdf", false)

            tryCompare(browser.opened, "length", 1)
            compare(browser.opened[0].url, "file:///tmp/a.pdf")
            compare(browserShown, 1)
            compare(released, [])
            compare(messages, [])
        }

        function test_aFileIsReleasedWhenTheBrowserIsOff() {
            const delivery = createDelivery(false, null)

            delivery.deliver("file:///tmp/a.pdf", false)

            compare(released, ["file:///tmp/a.pdf"])
            compare(messages.length, 1)
            compare(browserShown, 0)
        }

        function test_aFileIsReleasedBehindThePrivacyWall() {
            const wall = createTemporaryObject(privacyWallComponent, root)
            const delivery = createDelivery(true, wall)

            delivery.deliver("content://com.example.files/doc/1", false)

            tryVerify(() => released.length === 1)
            compare(released, ["content://com.example.files/doc/1"])
            compare(messages.length, 1)
        }
    }
}
