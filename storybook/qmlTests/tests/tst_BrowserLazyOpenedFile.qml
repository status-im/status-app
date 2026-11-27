import QtQuick
import QtTest

import AppLayouts.Browser.adapters

import "helpers"

/// A Preview Tab made in the background, such as a restored Opened File,
/// builds its view and opens its file only when it is shown.
Item {
    id: root

    width: 400
    height: 400

    Component {
        id: lazyViewComponent

        LazyWebViewAdapter {
            adapterPath: Qt.resolvedUrl("helpers/FakeWebViewAdapter.qml")

            profileParams: ProfileParams {
                userId: "user-1"
                userAgent: ""
                scripts: []
                offTheRecord: true
                localPreview: true
            }
            bookmarksStore: null
            localAccountSettings: QtObject {}
            webChannel: null
            devToolsEnabled: false
            enableJsLogs: false
        }
    }

    TestCase {
        name: "BrowserLazyOpenedFile"
        when: windowShown

        readonly property string fileUrl: "file:///docs/a b.pdf"

        function test_aFileWaitsUntilItsTabIsShown() {
            const view = createTemporaryObject(lazyViewComponent, root)

            view.loadFileUrl(fileUrl, fileUrl)

            verify(!view.adapterItem, "no view is built for a Tab nobody looks at")
            compare(String(view.url), fileUrl)

            view.ensureLoaded()

            verify(!!view.adapterItem)
            compare(view.adapterItem.loadedFiles, [[fileUrl, fileUrl]])
        }

        function test_aShownTabOpensItsFileAtOnce() {
            const view = createTemporaryObject(lazyViewComponent, root)
            view.ensureLoaded()

            view.loadFileUrl(fileUrl, fileUrl)

            compare(view.adapterItem.loadedFiles, [[fileUrl, fileUrl]])
        }
    }
}
