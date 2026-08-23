import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Layout

/*
   StatusSectionLayoutPortrait.BaseProxyPanel inserts and removes its page by a
   *fixed* implicitIndex (0 left, 1 centre, 2 right):

       onInViewChanged: {
           if (!inView && !!parent)
               d.items.push(root.takeItem(baseProxyPanel.implicitIndex));
           else if (inView && !parent)
               root.insertItem(implicitIndex, baseProxyPanel)
       }

   SwipeView indices shift as pages come and go, so the fixed index is only
   correct when every lower-numbered page is present. With no left panel the
   right panel's page sits at index 1, and takeItem(2) is out of range: hiding
   the right panel silently left its page in the view.

   Both positions are now looked up over the pages actually in the view. These
   cases guard that.
*/
Item {
    id: root
    width: 390
    height: 844

    Component { id: panelComponent; Rectangle { color: "grey" } }
    Component {
        id: chromeComponent
        StatusSectionLayout { anchors.fill: parent }
    }

    TestCase {
        name: "SectionPanelIndexing"
        when: windowShown

        function isDescendantOf(item, ancestor) {
            let it = item
            while (it) {
                if (it === ancestor) return true
                it = it.parent
            }
            return false
        }

        // Control: with all three pages present the indices line up.
        function test_hidingTheRightPanelRemovesItsPage() {
            const chrome = createTemporaryObject(chromeComponent, root)
            const left = createTemporaryObject(panelComponent, root)
            const center = createTemporaryObject(panelComponent, root)
            const right = createTemporaryObject(panelComponent, root)

            chrome.leftPanel = left
            chrome.centerPanel = center
            chrome.rightPanel = right
            chrome.showRightPanel = true
            waitForRendering(chrome); wait(20)
            chrome.showRightPanel = false
            waitForRendering(chrome); wait(20)
            verify(!isDescendantOf(right, chrome),
                   "with all three pages present the right page is removed")
        }

        // Same operation with no left panel: the right page sits at index 1,
        // not at its implicitIndex of 2. It used to stay in the view.
        function test_hidingTheRightPanelWithNoLeftPanel() {
            const chrome = createTemporaryObject(chromeComponent, root)
            const center = createTemporaryObject(panelComponent, root)
            const right = createTemporaryObject(panelComponent, root)

            chrome.centerPanel = center
            chrome.rightPanel = right
            chrome.showRightPanel = true
            waitForRendering(chrome); wait(20)
            chrome.showRightPanel = false
            waitForRendering(chrome); wait(20)

            console.info("INDEXBUG rightStillInView=", isDescendantOf(right, chrome),
                         "centreStillInView=", isDescendantOf(center, chrome))
            verify(isDescendantOf(center, chrome),
                   "the centre panel must not be the one removed")
            verify(!isDescendantOf(right, chrome),
                   "hiding the right panel should remove its page")
        }
    }
}
