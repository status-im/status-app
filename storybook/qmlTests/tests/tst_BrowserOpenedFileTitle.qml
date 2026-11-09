import QtQuick
import QtTest

import AppLayouts.Browser.adapters

import "helpers"

/// An Opened File's Tab is named by its file while it shows the file: an engine
/// names a content:// image by the last segment of its URI.
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
            localAccountSensitiveSettings: QtObject {}
            webChannel: null
            devToolsEnabled: false
            enableJsLogs: false
        }
    }

    TestCase {
        name: "BrowserOpenedFileTitle"
        when: windowShown

        function makeView(props) {
            const view = createTemporaryObject(lazyViewComponent, root, props ?? {})
            view.ensureLoaded()
            verify(!!view.adapterItem, "the fake adapter must be loaded")
            return { view: view, fake: view.adapterItem }
        }

        function test_anOpenedFileKeepsItsNameWhileShowingIt() {
            const { view, fake } = makeView({
                title: "picture.webp",
                openedFilePath: "content://com.example.files/doc/1"
            })

            fake.title = "primary:Download/picture.webp (640×400)"

            compare(view.title, "picture.webp")
        }

        function test_anOpenedFilesTabTakesThePageTitleOnceItMovesOn() {
            const { view, fake } = makeView({
                title: "picture.webp",
                openedFilePath: "content://com.example.files/doc/2"
            })

            fake.canGoBack = true
            fake.title = "Example Domain"

            compare(view.title, "Example Domain")
        }

        function test_anyOtherTabTakesThePageTitle() {
            const { view, fake } = makeView({ title: "report.pdf" })

            fake.title = "report.pdf (2 pages)"

            compare(view.title, "report.pdf (2 pages)")
        }
    }
}
