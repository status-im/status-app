import QtQuick
import QtTest

import StatusQ 0.1
import StatusQ.Layout

// The boosted incubation controller (externc.cpp) must stay gentle while a
// chrome transition animation runs: StatusSectionLayout brackets its slides
// with panelSwitchStarted/Ended, which push/pop a gentle hint through the
// StatusQ.IncubationHints singleton.
Item {
    id: root

    width: 800
    height: 600

    Component {
        id: chromeComponent

        StatusSectionLayout {}
    }

    TestCase {
        name: "IncubationHints"
        when: windowShown

        function test_pushPopTogglesGentle() {
            verify(!IncubationHints.gentleActive)
            IncubationHints.pushGentle()
            verify(IncubationHints.gentleActive)
            IncubationHints.pushGentle()
            verify(IncubationHints.gentleActive)
            IncubationHints.popGentle()
            verify(IncubationHints.gentleActive,
                   "two pushes need two pops")
            IncubationHints.popGentle()
            verify(!IncubationHints.gentleActive)
            // unbalanced pop must not underflow
            IncubationHints.popGentle()
            verify(!IncubationHints.gentleActive)
            IncubationHints.pushGentle()
            verify(IncubationHints.gentleActive)
            IncubationHints.popGentle()
            verify(!IncubationHints.gentleActive)
        }

        function test_chromeSlideBracketsGentleHint() {
            const chrome = createTemporaryObject(chromeComponent, root)
            verify(!!chrome)
            verify(!IncubationHints.gentleActive)

            chrome.panelSwitchStarted()
            verify(IncubationHints.gentleActive,
                   "a running panel switch must hold a gentle hint")

            chrome.panelSwitchEnded()
            verify(!IncubationHints.gentleActive,
                   "the hint must release when the switch ends")
        }
    }
}
