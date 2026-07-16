import QtQuick
import QtTest
import QtQml.Models

import StatusQ.Core.Theme

import AppLayouts.Wallet.views
import AppLayouts.Wallet.controls

Item {
    id: root
    width: 600
    height: 800

    Component {
        id: componentUnderTest

        SendModalFooter {
            id: sendModalFooter
            readonly property SignalSpy reviewSendClickedSpy: SignalSpy {
                target: sendModalFooter
                signalName: "reviewSendClicked"
            }
        }
    }

    ObjectModel {
        id: errorTagsModel
        RouterErrorTag {
            errorTitle: qsTr("Insufficient funds for send transaction")
            buttonText: qsTr("Add assets")
        }
    }

    // Stand-in for the scrollable form content the footer blurs. Mirrors the
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
        name: "SendModalFooter"
        when: windowShown

        property SendModalFooter controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function test_defaulValues() {
            verify(!!controlUnderTest)
            const estTimeLabel = findChild(controlUnderTest, "estTimeLabel")
            verify(!!estTimeLabel)
            const estimatedTimeText = findChild(controlUnderTest, "estimatedTimeText")
            verify(!!estimatedTimeText)
            const estFeesLabel = findChild(controlUnderTest, "estFeesLabel")
            verify(!!estFeesLabel)
            const estimatedFeesText = findChild(controlUnderTest, "estimatedFeesText")
            verify(!!estimatedFeesText)
            const transactionModalFooterButton = findChild(controlUnderTest, "transactionModalFooterButton")
            verify(!!transactionModalFooterButton)

            compare(controlUnderTest.color, Theme.palette.baseColor3)
            verify(controlUnderTest.dropShadowEnabled)

            compare(estTimeLabel.text, qsTr("Est time"))
            compare(estimatedTimeText.text, "--")
            compare(estimatedTimeText.customColor, Theme.palette.directColor5)
            verify(!estimatedTimeText.loading)

            compare(estFeesLabel.text, qsTr("Est fees"))
            compare(estimatedFeesText.text, "--")
            compare(estimatedFeesText.customColor, Theme.palette.directColor5)
            verify(!estimatedFeesText.loading)

            compare(transactionModalFooterButton.text, qsTr("Review Send"))
            verify(!transactionModalFooterButton.enabled)
            compare(transactionModalFooterButton.disabledColor, Theme.palette.directColor8)
        }

        function test_setValues() {
            verify(!!controlUnderTest)
            const estTimeLabel = findChild(controlUnderTest, "estTimeLabel")
            verify(!!estTimeLabel)
            const estimatedTimeText = findChild(controlUnderTest, "estimatedTimeText")
            verify(!!estimatedTimeText)
            const estFeesLabel = findChild(controlUnderTest, "estFeesLabel")
            verify(!!estFeesLabel)
            const estimatedFeesText = findChild(controlUnderTest, "estimatedFeesText")
            verify(!!estimatedFeesText)
            const transactionModalFooterButton = findChild(controlUnderTest, "transactionModalFooterButton")
            verify(!!transactionModalFooterButton)

            controlUnderTest.estimatedTime = "~60s"
            controlUnderTest.estimatedFees = "1.45 EUR"

            compare(estTimeLabel.text, qsTr("Est time"))
            compare(estimatedTimeText.text, "~60s")
            compare(estimatedTimeText.customColor, Theme.palette.directColor1)
            verify(!estimatedTimeText.loading)

            compare(estFeesLabel.text, qsTr("Est fees"))
            compare(estimatedFeesText.text, "1.45 EUR")
            compare(estimatedFeesText.customColor, Theme.palette.directColor1)
            verify(!estimatedFeesText.loading)

            compare(transactionModalFooterButton.text, qsTr("Review Send"))
            verify(transactionModalFooterButton.enabled)
            mouseClick(transactionModalFooterButton)

            controlUnderTest.reviewSendClickedSpy.wait()
        }

        function test_loadingState() {
            verify(!!controlUnderTest)
            const estTimeLabel = findChild(controlUnderTest, "estTimeLabel")
            verify(!!estTimeLabel)
            const estimatedTimeText = findChild(controlUnderTest, "estimatedTimeText")
            verify(!!estimatedTimeText)
            const estFeesLabel = findChild(controlUnderTest, "estFeesLabel")
            verify(!!estFeesLabel)
            const estimatedFeesText = findChild(controlUnderTest, "estimatedFeesText")
            verify(!!estimatedFeesText)
            const transactionModalFooterButton = findChild(controlUnderTest, "transactionModalFooterButton")
            verify(!!transactionModalFooterButton)

            controlUnderTest.loading = true

            compare(estTimeLabel.text, qsTr("Est time"))
            compare(estimatedTimeText.text, "XXXXXXXXXX")
            compare(estimatedTimeText.customColor, Theme.palette.directColor5)
            verify(estimatedTimeText.loading)

            compare(estFeesLabel.text, qsTr("Est fees"))
            compare(estimatedFeesText.text, "XXXXXXXXXX")
            compare(estimatedFeesText.customColor, Theme.palette.directColor5)
            verify(estimatedFeesText.loading)

            compare(transactionModalFooterButton.text, qsTr("Review Send"))
            verify(!transactionModalFooterButton.enabled)
        }

        function test_errorState() {
            verify(!!controlUnderTest)
            const estTimeLabel = findChild(controlUnderTest, "estTimeLabel")
            verify(!!estTimeLabel)
            const estimatedTimeText = findChild(controlUnderTest, "estimatedTimeText")
            verify(!!estimatedTimeText)
            const estFeesLabel = findChild(controlUnderTest, "estFeesLabel")
            verify(!!estFeesLabel)
            const estimatedFeesText = findChild(controlUnderTest, "estimatedFeesText")
            verify(!!estimatedFeesText)
            const transactionModalFooterButton = findChild(controlUnderTest, "transactionModalFooterButton")
            verify(!!transactionModalFooterButton)

            controlUnderTest.error = true

            waitForRendering(controlUnderTest)

            compare(estTimeLabel.text, qsTr("Est time"))
            compare(estimatedTimeText.text, "--")
            compare(estimatedTimeText.customColor, Theme.palette.directColor5)
            verify(!estimatedTimeText.loading)

            compare(estFeesLabel.text, qsTr("Est fees"))
            compare(estimatedFeesText.text, "--")
            tryCompare(estimatedFeesText, "customColor", Theme.palette.dangerColor1)
            verify(!estimatedFeesText.loading)

            compare(transactionModalFooterButton.text, qsTr("Review Send"))
            verify(!transactionModalFooterButton.enabled)

            verify(!controlUnderTest.errorTags)

            controlUnderTest.errorTags = errorTagsModel
            compare(controlUnderTest.errorTags, errorTagsModel)
        }

        // The frosted backdrop must exist and be blurred, but captured
        // statically (live == false) so it is not re-blurred every frame.
        function test_blur_isStaticNotLive() {
            controlUnderTest.blurSource = fakeContent

            const backdrop = findChild(controlUnderTest, "blurBackdropRect")
            verify(!!backdrop, "frosted backdrop rectangle exists")
            verify(backdrop.visible, "backdrop is visible when content is behind the footer")
            verify(backdrop.layer.enabled, "FastBlur layer effect is enabled")

            const src = findChild(controlUnderTest, "blurBackdropSource")
            verify(!!src, "backdrop shader effect source exists")
            compare(src.live, false, "backdrop is static, not re-captured every frame")
            verify(src.sourceItem === fakeContent, "source is wired to the content behind the footer")
        }

        // Scrolling the content behind the footer (contentY change, e.g. user
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

        // Content growing/shrinking behind the footer (async data arriving, rows
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

        // A theme switch recolors the content behind the footer without moving it;
        // the static backdrop must re-capture so it does not show stale colors.
        function test_blur_refreshesOnThemeChange() {
            controlUnderTest.blurSource = fakeContent
            const src = findChild(controlUnderTest, "blurBackdropSource")
            verify(!!src)

            blurRefreshSpy.target = src
            const before = blurRefreshSpy.count

            // root.color tracks Theme.palette.baseColor3, so a palette/theme swap
            // changes it; drive it directly to exercise the theme trigger.
            controlUnderTest.color = "#123456"
            compare(blurRefreshSpy.count, before + 1, "theme/color change re-captures the backdrop")
        }
    }
}
