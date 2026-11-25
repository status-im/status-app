import QtQuick
import QtTest

import StatusQ.Layout

// StatusSectionLayout brackets every panel switch with
// panelSwitchStarted/panelSwitchEnded. Landscape shows all panels at once —
// there is no slide — so a currentIndex change must emit the pair
// back-to-back, and the invisible portrait view's own slide must not leak
// extra signals. (The window is 1000px wide: landscape mode.)
Item {
    id: root

    width: 1000
    height: 700

    Component {
        id: layoutComponent

        StatusSectionLayout {
            anchors.fill: parent
            showRightPanel: true
        }
    }

    Component {
        id: initialIndexComponent

        StatusSectionLayout {
            anchors.fill: parent
            initialIndex: StatusSectionLayout.CentralPanel
        }
    }

    Component {
        id: mirrorComponent

        QtObject {
            property StatusSectionLayout source
            readonly property int index: source ? source.currentIndex : -1
        }
    }

    Component {
        id: landscapeComponent

        StatusSectionLayoutLandscape {
            anchors.fill: parent
            showRightPanel: true
        }
    }

    Component {
        id: panelComponent
        Rectangle {
            width: 300
            height: 700
        }
    }

    SignalSpy {
        id: startedSpy
        signalName: "panelSwitchStarted"
    }

    SignalSpy {
        id: endedSpy
        signalName: "panelSwitchEnded"
    }

    TestCase {
        name: "StatusSectionLayout"
        when: windowShown

        property var layout: null

        function init() {
            layout = createTemporaryObject(layoutComponent, root)
            verify(!!layout)
            layout.leftPanel = createTemporaryObject(panelComponent, root)
            layout.centerPanel = createTemporaryObject(panelComponent, root)
            layout.rightPanel = createTemporaryObject(panelComponent, root)
            waitForRendering(layout)

            startedSpy.target = layout
            endedSpy.target = layout
            startedSpy.clear()
            endedSpy.clear()
        }

        function createLandscapeLayout(userUID, sectionName) {
            const item = createTemporaryObject(landscapeComponent, root)
            verify(!!item)
            item.userUID = userUID
            item.sectionName = sectionName
            item.leftPanel = createTemporaryObject(panelComponent, root)
            item.centerPanel = createTemporaryObject(panelComponent, root)
            item.rightPanel = createTemporaryObject(panelComponent, root)
            item.showRightPanel = true
            waitForRendering(item)
            return item
        }

        // The loader holding each orientation's view.
        function loaderOf(typePrefix) {
            return findChild(layout, typePrefix === "StatusSectionLayoutPortrait" ? "portraitLoader"
                                                                              : "landscapeLoader")
        }

        // What LayoutChooser does on rotation: choose the loader, then flip the
        // loaders' visibility.
        function rotate(toPortrait) {
            const portrait = loaderOf("StatusSectionLayoutPortrait")
            const landscape = loaderOf("StatusSectionLayoutLandscape")
            layout.chosenLayout = toPortrait ? portrait : landscape
            landscape.visible = !toPortrait
            portrait.visible = toPortrait
            return portrait
        }

        function isInside(item, ancestor) {
            for (let p = item; p; p = p.parent)
                if (p === ancestor)
                    return true
            return false
        }

        // A view is built the first time its orientation is chosen, not before.
        function test_aViewIsBuiltWhenFirstChosen() {
            const portrait = loaderOf("StatusSectionLayoutPortrait")
            const landscape = loaderOf("StatusSectionLayoutLandscape")
            verify(!!portrait && !!landscape)
            verify(landscape.visible && !!landscape.item, "the 1000px window starts in landscape")
            compare(portrait.item, null, "the portrait view is not built before it is chosen")
            rotate(true)
            verify(!!portrait.item)
        }

        function test_landscapeBackButtonStillFollowsItsLabelByDefault() {
            const backButton = findChild(loaderOf("StatusSectionLayoutLandscape").item, "toolBarBackButton")
            verify(!!backButton)
            verify(!backButton.visible)
            layout.backButtonName = "Settings"
            tryCompare(backButton, "visible", true)
            compare(backButton.text, "Settings")
        }

        // Hiding the section (as AppMain's StackLayout does) destroys nothing.
        function test_hidingTheSectionKeepsTheView() {
            const landscape = loaderOf("StatusSectionLayoutLandscape")
            const view = landscape.item
            verify(!!view)
            layout.visible = false
            compare(landscape.item, view, "the view survives the section being hidden")
            layout.visible = true
            compare(landscape.item, view)
            tryVerify(() => isInside(layout.leftPanel, view))
        }

        // After rotating and rotating back both views exist; the chosen one is
        // visible and owns the panels.
        function test_rotateAndBackKeepsBothViews() {
            const portrait = loaderOf("StatusSectionLayoutPortrait")
            const landscape = loaderOf("StatusSectionLayoutLandscape")
            const landscapeView = landscape.item
            rotate(true)
            const portraitView = portrait.item
            verify(!!portraitView)
            compare(landscape.item, landscapeView, "the landscape view is kept in portrait")
            tryVerify(() => isInside(layout.centerPanel, portraitView), 1000, "portrait owns the panels")

            rotate(false)
            compare(landscape.item, landscapeView)
            compare(portrait.item, portraitView, "the portrait view is kept in landscape")
            verify(landscape.visible && !portrait.visible)
            tryVerify(() => isInside(layout.leftPanel, landscapeView), 1000, "landscape owns the panels again")
            tryVerify(() => isInside(layout.centerPanel, landscapeView))
            tryVerify(() => isInside(layout.rightPanel, landscapeView))
        }

        // Rotating to landscape mid-slide must close the bracket right away:
        // the slide is no longer visible, so there is nothing left to defer
        // panel swaps for.
        function test_rotateToLandscapeMidSlideClosesBracket() {
            const pv = rotate(true).item // start in portrait
            verify(!!pv)
            pv.contentItem.highlightMoveDuration = 60000 // hold the slide

            layout.setCurrentIndex(StatusSectionLayout.RightPanel)
            compare(startedSpy.count, 1)
            compare(endedSpy.count, 0)

            rotate(false) // rotate away mid-slide
            compare(endedSpy.count, 1,
                    "rotating away mid-slide must close the bracket at once")
            wait(100)
            compare(startedSpy.count, 1)
            compare(endedSpy.count, 1)
        }

        // A switch made in landscape is a back-to-back pair; rotating to
        // portrait afterwards builds the view on the kept index, with no slide
        // and so no further bracket.
        function test_rotateToPortraitKeepsTheIndexWithoutASlide() {
            layout.setCurrentIndex(StatusSectionLayout.RightPanel)
            compare(startedSpy.count, 1, "landscape pair")
            compare(endedSpy.count, 1, "landscape pair")

            const pv = rotate(true).item
            verify(!!pv)
            // the right panel's page is the last one in the view
            compare(pv.currentIndex, pv.count - 1)
            compare(layout.currentIndex, StatusSectionLayout.RightPanel)
            wait(100)
            compare(startedSpy.count, 1)
            compare(endedSpy.count, 1)
        }

        function test_landscapeSwitchEmitsPairBackToBack() {
            layout.setCurrentIndex(StatusSectionLayout.RightPanel)

            compare(startedSpy.count, 1,
                    "a landscape switch must emit panelSwitchStarted")
            compare(endedSpy.count, 1,
                    "a landscape switch must emit panelSwitchEnded right after")

            wait(500)
            compare(startedSpy.count, 1)
            compare(endedSpy.count, 1)
        }

        // The portrait view is kept after rotating back, but stays out of Back
        // and panel navigation while hidden.
        function test_keptPortraitViewIsInertInLandscape() {
            layout.setCurrentIndex(StatusSectionLayout.CentralPanel)
            rotate(true)
            rotate(false)
            const pv = loaderOf("StatusSectionLayoutPortrait").item
            verify(!!pv)
            verify(pv.canGoBackInternally)

            verify(!layout.canGoBack)
            verify(!layout.tryGoBack())
            layout.goToNextPanel()
            compare(layout.currentIndex, StatusSectionLayout.CentralPanel)
        }

        function test_landscapeSwitchAfterRoundTripEmitsPair() {
            rotate(true)
            rotate(false)
            startedSpy.clear()
            endedSpy.clear()

            layout.setCurrentIndex(StatusSectionLayout.RightPanel)
            compare(startedSpy.count, 1)
            compare(endedSpy.count, 1)
        }

        function test_currentIndexIsReadOnly() {
            let threw = false
            try {
                layout.currentIndex = StatusSectionLayout.RightPanel
            } catch (e) {
                threw = true
            }
            verify(threw)
            compare(layout.currentIndex, StatusSectionLayout.LeftPanel)
        }

        function test_initialIndexIsTheStartingPanel() {
            const l = createTemporaryObject(initialIndexComponent, root)
            verify(!!l)
            compare(l.currentIndex, StatusSectionLayout.CentralPanel)
            l.setCurrentIndex(StatusSectionLayout.RightPanel)
            compare(l.currentIndex, StatusSectionLayout.RightPanel)
        }

        // Swipes and setCurrentIndex() both reach currentIndex, so a consumer
        // binding on it follows every change.
        function test_consumerBindingFollowsSetterAndSwipes() {
            const mirror = createTemporaryObject(mirrorComponent, root, { source: layout })
            verify(!!mirror)

            layout.setCurrentIndex(StatusSectionLayout.CentralPanel)
            compare(mirror.index, StatusSectionLayout.CentralPanel)

            const pv = rotate(true).item
            verify(!!pv)
            pv.decrementCurrentIndex()
            compare(layout.currentIndex, StatusSectionLayout.LeftPanel)
            compare(mirror.index, StatusSectionLayout.LeftPanel)

            layout.setCurrentIndex(StatusSectionLayout.CentralPanel)
            compare(pv.currentIndex, StatusSectionLayout.CentralPanel)
            compare(mirror.index, StatusSectionLayout.CentralPanel)
        }

        function test_landscapeSplitStateIsIsolatedPerUserAndSection() {
            const settingsA = Qt.createQmlObject(
                'import QtCore; Settings { category: "%1_%2".arg("userA").arg("sectionA"); property int splitWidth: 420 }',
                root)
            const settingsB = Qt.createQmlObject(
                'import QtCore; Settings { category: "%1_%2".arg("userA").arg("sectionB"); property int splitWidth: 300 }',
                root)
            const settingsC = Qt.createQmlObject(
                'import QtCore; Settings { category: "%1_%2".arg("userB").arg("sectionA"); property int splitWidth: 340 }',
                root)

            compare(settingsA.category, "userA_sectionA")
            compare(settingsB.category, "userA_sectionB")
            compare(settingsC.category, "userB_sectionA")
            compare(settingsA.category !== settingsB.category, true)
            compare(settingsA.category !== settingsC.category, true)
            compare(settingsB.category !== settingsC.category, true)

            compare(settingsA.splitWidth, 420)
            compare(settingsB.splitWidth, 300)
            compare(settingsC.splitWidth, 340)
        }
    }
}
