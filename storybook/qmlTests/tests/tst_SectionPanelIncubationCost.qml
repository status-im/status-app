import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Layout

/*
   What the unparented phase actually costs.

   A panel constructed as a property value has no visual parent, so it reports
   its *content's* implicit size until the chrome adopts it. What that costs
   depends entirely on the content:

     * content with no implicit size (a bare ListView) reports 0x0, so nothing
       is laid out and nothing is built - the phase is nearly free, and binding
       the panel's geometry actually makes it build MORE work up front;
     * content with a large implicit size (a Column/Layout over a full list, as
       ChatView's contact column is) reports that size and builds against it,
       which is the case the ChatView remedy was written for.

   So "pre-size the panel while it is unparented" is not a universal win: it
   pins the panel to the right box, which is what makes the later handoff free
   (see tst_SectionPanelGeometryRemedies.qml), but it also front-loads a
   screenful of content into the incubation.
*/
Item {
    id: root

    width: 390
    height: 844

    property int delegatesCreated: 0

    Component {
        id: heavyList
        ListView {
            model: 500
            delegate: Item {
                width: ListView.view.width
                height: 40
                Component.onCompleted: root.delegatesCreated++
            }
        }
    }

    // Content whose implicit size *is* its whole content, like a Column over a
    // list - this is the shape ChatView's contact column had.
    Component {
        id: heavyColumn
        Column {
            Repeater {
                model: 500
                delegate: Item {
                    width: 300
                    height: 40
                    Component.onCompleted: root.delegatesCreated++
                }
            }
        }
    }

    Component { id: unboundLoader; Loader { asynchronous: true } }
    Component {
        id: boundLoader
        Loader {
            asynchronous: true
            width: root.width
            height: root.height
        }
    }

    Component {
        id: chromeComponent
        StatusSectionLayout { anchors.fill: parent; currentIndex: 1 }
    }

    TestCase {
        name: "SectionPanelIncubationCost"
        when: windowShown

        function init() { root.delegatesCreated = 0 }

        function measure(loaderComponent, contentComponent, tag) {
            const chrome = createTemporaryObject(chromeComponent, root)
            waitForRendering(chrome); wait(20)
            root.delegatesCreated = 0

            const panel = createTemporaryObject(loaderComponent, root,
                                                {sourceComponent: contentComponent})
            tryVerify(() => panel.status === Loader.Ready, 5000)
            waitForRendering(chrome); wait(50)
            const detachedSize = panel.width + "x" + panel.height
            const builtDetached = root.delegatesCreated

            chrome.centerPanel = panel
            waitForRendering(chrome); wait(50)
            console.info(tag, "| size while unparented:", detachedSize,
                         "| built while unparented:", builtDetached,
                         "| built in total:", root.delegatesCreated,
                         "| final size:", panel.width + "x" + panel.height)
            return builtDetached
        }

        // A ListView has no implicit size, so an unbound loader sits at 0x0 and
        // builds essentially nothing while unparented.
        function test_unboundLoaderOverAListBuildsNothingWhileUnparented() {
            const n = measure(unboundLoader, heavyList, "LIST unbound")
            verify(n <= 2, "expected ~nothing to be built at 0x0, got " + n)
        }

        // Pre-sizing it front-loads a screenful into the incubation.
        function test_boundLoaderOverAListBuildsAScreenfulWhileUnparented() {
            const n = measure(boundLoader, heavyList, "LIST bound")
            verify(n > 2 && n < 100, "expected a screenful, got " + n)
        }

        // Content that reports its whole size implicitly builds all of it
        // regardless - the case the ChatView remedy exists for.
        function test_columnContentBuildsEverythingWhileUnparented() {
            const n = measure(unboundLoader, heavyColumn, "COLUMN unbound")
            verify(n >= 500, "expected the whole column, got " + n)
        }
    }
}
