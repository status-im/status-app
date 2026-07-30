import QtQuick
import QtTest
import QtQml.Models

import StatusQ.Core.Theme

import AppLayouts.Wallet.panels

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest

        StickySendModalHeader {
            stickyHeaderVisible: true

            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            networksModel: ListModel {}
        }
    }

    // Stand-in for the scrollable form content the header blurs. Mirrors the
    // Flickable roles the real blurSource (scrollView.contentItem) exposes:
    // contentY (scrolling), contentHeight/contentWidth (content growth).
    Flickable {
        id: fakeContent
        width: 500
        height: 300
        contentWidth: 500
        contentHeight: 2000
    }

    SignalSpy {
        id: blurRefreshSpy
        signalName: "refreshRequested"
    }

    TestCase {
        name: "StickySendModalHeader"
        when: windowShown

        property StickySendModalHeader controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
        }

        // The frosted backdrop must exist and be blurred, but captured
        // statically (live == false) so it is not re-blurred every frame.
        function test_blur_isStaticNotLive() {
            controlUnderTest.blurSource = fakeContent

            const backdrop = findChild(controlUnderTest, "blurBackdropRect")
            verify(!!backdrop, "frosted backdrop rectangle exists")
            verify(backdrop.visible, "backdrop is visible when content is behind the header")
            verify(backdrop.layer.enabled, "FastBlur layer effect is enabled")

            const src = findChild(controlUnderTest, "blurBackdropSource")
            verify(!!src, "backdrop shader effect source exists")
            compare(src.live, false, "backdrop is static, not re-captured every frame")
            verify(src.sourceItem === fakeContent, "source is wired to the content behind the header")
        }

        // Scrolling the content behind the header (contentY change, e.g. user
        // drag or programmatic sticky-header reveal) must re-capture the backdrop.
        function test_blur_refreshesOnScroll() {
            controlUnderTest.blurSource = fakeContent
            const src = findChild(controlUnderTest, "blurBackdropSource")
            verify(!!src)

            blurRefreshSpy.target = src
            const before = blurRefreshSpy.count

            fakeContent.contentY += 50
            compare(blurRefreshSpy.count, before + 1, "scroll re-captures the frosted backdrop")
        }

        // Content growing/shrinking behind the header (async data arriving, rows
        // appearing) changes the captured region and must re-capture the backdrop.
        function test_blur_refreshesOnContentGrowth() {
            controlUnderTest.blurSource = fakeContent
            const src = findChild(controlUnderTest, "blurBackdropSource")
            verify(!!src)

            blurRefreshSpy.target = src

            let before = blurRefreshSpy.count
            fakeContent.contentHeight += 120
            compare(blurRefreshSpy.count, before + 1, "content height growth re-captures the backdrop")

            before = blurRefreshSpy.count
            fakeContent.contentWidth += 40
            compare(blurRefreshSpy.count, before + 1, "content width change re-captures the backdrop")
        }

        // The header animates its height 0 -> N when it is revealed, so the
        // captured region (bound to the header size) grows over 350ms; a capture
        // taken at the old size is stretched over the new one.
        function test_blur_refreshesOnHeaderResize() {
            controlUnderTest.blurSource = fakeContent
            const src = findChild(controlUnderTest, "blurBackdropSource")
            verify(!!src)

            blurRefreshSpy.target = src

            let before = blurRefreshSpy.count
            controlUnderTest.height = controlUnderTest.height + 30
            verify(blurRefreshSpy.count > before, "height change re-captures the backdrop")

            before = blurRefreshSpy.count
            controlUnderTest.width = controlUnderTest.width + 40
            verify(blurRefreshSpy.count > before, "width change re-captures the backdrop")
        }

        // The content behind the header can be resized without scrolling (window
        // resize); what falls inside the captured region changes with it.
        function test_blur_refreshesOnSourceItemResize() {
            controlUnderTest.blurSource = fakeContent
            const src = findChild(controlUnderTest, "blurBackdropSource")
            verify(!!src)

            blurRefreshSpy.target = src

            let before = blurRefreshSpy.count
            fakeContent.width += 25
            verify(blurRefreshSpy.count > before, "source width change re-captures the backdrop")

            before = blurRefreshSpy.count
            fakeContent.height += 25
            verify(blurRefreshSpy.count > before, "source height change re-captures the backdrop")
        }

        // A theme switch recolors the content behind the header without moving it;
        // the static backdrop must re-capture so it does not show stale colors.
        function test_blur_refreshesOnThemeChange() {
            controlUnderTest.blurSource = fakeContent
            const src = findChild(controlUnderTest, "blurBackdropSource")
            verify(!!src)

            const fg = findChild(controlUnderTest, "sendHeaderForegroundRect")
            verify(!!fg, "foreground rectangle exists")

            blurRefreshSpy.target = src
            const before = blurRefreshSpy.count

            // The backdrop color tracks Theme.palette.baseColor3, so a palette/theme
            // swap changes it; drive it directly to exercise the theme trigger.
            fg.color = "#123456"
            compare(blurRefreshSpy.count, before + 1, "theme/color change re-captures the backdrop")
        }
    }
}
