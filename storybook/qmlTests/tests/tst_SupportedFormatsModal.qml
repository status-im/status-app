import QtQuick
import QtTest

import AppLayouts.Browser.popups

/**
 * SupportedFormatsModal renders the report it is handed: one row per format,
 * each saying where that format opens. The report itself is asserted in
 * tst_BrowserFormatSupportContext.
 */
Item {
    id: root
    width: 600
    height: 600

    readonly property var testSections: [
        {
            title: "Audio and video",
            formats: [
                { name: "Alpha", detail: ".alpha", supported: true },
                { name: "Beta", detail: ".beta", supported: false }
            ]
        },
        {
            title: "Documents and images",
            formats: [
                { name: "Gamma", detail: ".gamma", supported: true }
            ]
        }
    ]

    Component {
        id: modalComponent

        SupportedFormatsModal {
            sections: root.testSections
        }
    }

    TestCase {
        name: "SupportedFormatsModal"
        when: windowShown

        function statusOf(modal, name) {
            const row = findChild(modal.contentItem, "supportedFormatRow_" + name)
            verify(!!row, "row for " + name)
            const status = findChild(row, "supportedFormatStatus")
            verify(!!status, "status for " + name)
            return status.text
        }

        function test_everyFormatSaysWhereItOpens() {
            const modal = createTemporaryObject(modalComponent, root)
            modal.open()
            waitForRendering(root)

            compare(statusOf(modal, "Alpha"), statusOf(modal, "Gamma"))
            verify(statusOf(modal, "Alpha") !== statusOf(modal, "Beta"))
        }
    }
}
