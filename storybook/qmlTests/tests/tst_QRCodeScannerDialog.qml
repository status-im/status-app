import QtQuick
import QtTest

import StatusQ.Components

import shared.popups

// The dialog's content must stay inside it when the window (and so the dialog,
// capped at 80% of the window height) gets short.
Item {
    id: root

    width: 1200
    height: 1000

    Component {
        id: componentUnderTest

        QRCodeScannerDialog {}
    }

    property QRCodeScannerDialog controlUnderTest: null

    SignalSpy {
        id: tagSpy
        target: root.controlUnderTest
        signalName: "tagFound"
    }

    TestCase {
        name: "QRCodeScannerDialog"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function cleanup() {
            root.height = 1000
        }

        function rows() {
            const r = findChild(controlUnderTest.contentItem, "qrScannerInfoRows")
            verify(!!r)
            return r
        }

        // The info rows are fully visible without scrolling.
        function verifyContentFits() {
            const view = controlUnderTest.contentItem
            const r = rows()
            verify(r.height > 0)
            const bottom = r.mapToItem(view, 0, r.height).y
            verify(bottom <= view.height + 0.5,
                   `rows end at ${bottom}, content is ${view.height} tall`)
        }

        // A reused dialog (kept instead of destroyed on close) scans again
        // after reopening: each opening is a fresh session.
        function test_reopenStartsAFreshSession() {
            const address = "0x1234567890abcdef1234567890abcdef12345678"
            tagSpy.clear()
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            const scanner = findChild(controlUnderTest.contentItem, "qrCodeScanner")
            verify(!!scanner)

            // what a successful camera scan leaves behind
            scanner.state = StatusQrCodeScanner.State.Success
            scanner.validTagFound(address)
            tryCompare(tagSpy, "count", 1, 2000)
            tryCompare(controlUnderTest, "opened", false)

            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            compare(scanner.state, StatusQrCodeScanner.State.None)
            scanner.validTagFound(address) // the same code again
            tryCompare(tagSpy, "count", 2, 2000)
        }

        function test_contentFitsInTallWindow() {
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            verifyContentFits()
        }

        function test_contentFitsInShortWindow_data() {
            // 680: the app's minimum window height (ThemeUtils.minimumDesktopSize)
            return [{ tag: "700", height: 700 }, { tag: "680", height: 680 }]
        }

        function test_contentFitsInShortWindow(data) {
            root.height = data.height // still landscape: a centered dialog, not a sheet
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            verify(!controlUnderTest.bottomSheet)
            tryVerify(() => controlUnderTest.height <= data.height * 0.8 + 1)
            verifyContentFits()
        }

        // Below what the scanner can shrink to, the content scrolls instead of
        // spilling out of the dialog.
        function test_contentScrollsInTinyWindow_data() {
            // Below the app's minimum (Storybook can get there)
            return [{ tag: "560", height: 560 }, { tag: "380", height: 380 }]
        }

        function test_contentScrollsInTinyWindow(data) {
            root.height = data.height
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            const view = controlUnderTest.contentItem
            const r = rows()
            tryVerify(() => view.contentHeight > view.height)
            verify(r.mapToItem(view.contentItem, 0, r.height).y <= view.contentHeight + 0.5)
            const scanner = findChild(view, "qrCodeScanner")
            verify(scanner.height >= 200, `scanner squeezed to ${scanner.height}`)
        }

        function test_contentFitsWhenWindowShrinksWhileOpen() {
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            root.height = 680
            tryVerify(() => controlUnderTest.height <= 680 * 0.8 + 1)
            verifyContentFits()
        }
    }
}
