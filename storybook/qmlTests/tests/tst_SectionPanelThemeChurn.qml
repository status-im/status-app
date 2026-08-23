import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Core.Theme
import StatusQ.Layout

/*
   Theme is a QQuickAttachedPropertyPropagator: the value an item sees is
   resolved by walking its *visual parent* chain. A panel constructed with no
   visual parent therefore resolves against the engine-level fallback node, not
   against the chrome it will end up in - so every Theme.palette / Theme.padding
   binding in the panel is first evaluated against the wrong values and
   re-evaluated when the chrome adopts it.

   theme.cpp already guards the *unparenting* direction (StatusQ/src/theme.cpp,
   Theme::attachedParentChange: a detached item defers restyling until it lands
   in a window again, so a section switch does not round-trip the subtree
   through Light). These tests cover what is left: the construction direction.
*/
Item {
    id: root

    width: 390
    height: 844

    Theme.style: Theme.Style.Dark

    component ThemedPanel: Rectangle {
        id: p
        readonly property int seenStyle: p.Theme.style
        readonly property color seenColor: p.Theme.palette.primaryColor1
        readonly property real seenPadding: p.Theme.padding
        color: seenColor
    }
    Component { id: themedPanelComponent; ThemedPanel {} }

    Component {
        id: chromeComponent
        StatusSectionLayout { anchors.fill: parent; currentIndex: 1 }
    }

    TestCase {
        name: "SectionPanelThemeChurn"
        when: windowShown

        // Baseline: a panel built directly inside the themed tree sees the
        // final theme immediately.
        function test_panelBuiltInPlaceSeesTheTreeTheme() {
            const chrome = createTemporaryObject(chromeComponent, root)
            waitForRendering(chrome); wait(20)
            const panel = createTemporaryObject(themedPanelComponent, chrome)
            waitForRendering(chrome); wait(30)
            console.info("THEME inPlace style=" + panel.seenStyle
                         + " colour=" + panel.seenColor)
            compare(panel.seenStyle, Theme.Style.Dark)
        }

        // The real shape: constructed unparented, handed to the chrome later.
        function test_panelBuiltUnparentedIsRestyledOnAdoption() {
            const chrome = createTemporaryObject(chromeComponent, root)
            waitForRendering(chrome); wait(20)

            // no visual parent, like `readonly property Item centerPanel:
            // Loader { ... }` in WalletLayout / ChatView
            const panel = themedPanelComponent.createObject(null)
            verify(!!panel)
            waitForRendering(chrome); wait(30)
            const detachedStyle = panel.seenStyle
            const detachedColor = panel.seenColor

            chrome.centerPanel = panel
            waitForRendering(chrome); wait(30)

            console.info("THEME detached style=" + detachedStyle
                         + " colour=" + detachedColor
                         + " -> adopted style=" + panel.seenStyle
                         + " colour=" + panel.seenColor)
            const changed = (detachedStyle !== panel.seenStyle)
                         || (detachedColor.toString() !== panel.seenColor.toString())
            panel.destroy()
            verify(changed,
                   "a panel built unparented resolves the wrong theme and is "
                   + "restyled when the chrome adopts it")
        }
    }
}
