import QtQuick
import QtTest

import StatusQ.Popups

import AppLayouts.Browser.popups

/**
 * Link/image long-press menu (ADR 0005 "save link"): item sets per URL shape
 * and signal payloads.
 */
Item {
    id: root
    width: 400
    height: 400

    Component {
        id: menuComponent
        BrowserLinkContextMenu {}
    }

    TestCase {
        name: "BrowserLinkContextMenu"
        when: windowShown

        function enabledTexts(menu) {
            const texts = []
            for (let i = 0; i < menu.count; ++i) {
                const item = menu.itemAt(i)
                if (!item || item instanceof StatusMenuSeparator)
                    continue
                if (item.enabled && item.text)
                    texts.push(item.text)
            }
            return texts
        }

        function test_linkOnly_showsLinkActions_noImage() {
            const menu = createTemporaryObject(menuComponent, root, {
                linkUrl: "https://example.com/file.zip",
                imageUrl: ""
            })
            const texts = enabledTexts(menu)
            verify(texts.indexOf(qsTr("Open in new tab")) >= 0)
            verify(texts.indexOf(qsTr("Download link")) >= 0)
            verify(texts.indexOf(qsTr("Download image")) < 0)
        }

        function test_imageOnly_showsImageDownload_noLinkActions() {
            const menu = createTemporaryObject(menuComponent, root, {
                linkUrl: "",
                imageUrl: "https://example.com/photo.png"
            })
            const texts = enabledTexts(menu)
            verify(texts.indexOf(qsTr("Download image")) >= 0)
            verify(texts.indexOf(qsTr("Open in new tab")) < 0)
            verify(texts.indexOf(qsTr("Download link")) < 0)
        }

        function test_linkedImage_showsBothSets() {
            const menu = createTemporaryObject(menuComponent, root, {
                linkUrl: "https://example.com/page",
                imageUrl: "https://example.com/photo.png"
            })
            const texts = enabledTexts(menu)
            verify(texts.indexOf(qsTr("Open in new tab")) >= 0)
            verify(texts.indexOf(qsTr("Download link")) >= 0)
            verify(texts.indexOf(qsTr("Download image")) >= 0)
        }

        function test_signals_carryTheMatchingUrl() {
            const menu = createTemporaryObject(menuComponent, root, {
                linkUrl: "https://example.com/file.zip",
                imageUrl: "https://example.com/photo.png"
            })

            let downloaded = []
            let opened = []
            menu.downloadRequested.connect(u => downloaded.push(String(u)))
            menu.openInNewTabRequested.connect(u => opened.push(String(u)))

            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (!action || !action.enabled)
                    continue
                if (action.text === qsTr("Download link")
                        || action.text === qsTr("Download image")
                        || action.text === qsTr("Open in new tab"))
                    action.trigger()
            }

            compare(opened, ["https://example.com/file.zip"])
            compare(downloaded, ["https://example.com/file.zip", "https://example.com/photo.png"])
        }
    }
}
