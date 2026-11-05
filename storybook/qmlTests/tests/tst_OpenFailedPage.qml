import QtQuick
import QtTest

import AppLayouts.Browser.views

Item {
    id: root

    width: 420
    height: 320

    Component {
        id: pageComponent

        OpenFailedPage {
            width: 400
            height: 300
        }
    }

    TestCase {
        name: "OpenFailedPage"
        when: windowShown

        function test_namesTheFile() {
            const page = createTemporaryObject(pageComponent, root, { fileName: "report.docx" })
            const name = findChild(page, "openFailedFileName")
            verify(!!name)
            compare(name.text, "report.docx")
            verify(name.visible)
        }

        // A burst overflow has no single file to name.
        function test_hidesTheNameWhenNoneIsKnown() {
            const page = createTemporaryObject(pageComponent, root)
            const name = findChild(page, "openFailedFileName")
            verify(!!name)
            verify(!name.visible)
        }
    }
}
