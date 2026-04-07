pragma ComponentBehavior: Bound

import QtQuick
import QtQml

import "internal"

DoubleFlickable {
    readonly property bool flickable1Folded: !d.grid1ContentInViewport
    readonly property bool flickable2Folded: d.grid2HeaderAtEnd || d.model2Blocked

    function flip1Folding() {
        if (d.grid1ContentInViewport) {
            if (d.grid2FullyFilling)
                contentY = flickable1ContentHeight - d.header1Size
            else
                d.model1Blocked = true
        } else {
            d.model1Blocked = false
            contentY = 0
        }
    }

    function flip2Folding() {
        // header at the end (always folded)
        if (d.grid2HeaderAtEnd) {
            contentY = flickable1ContentHeight - d.header1Size -
                    Math.max(0, height - flickable2ContentHeight - d.header1Size)
            return
        }

        // header on top, unfolded
        // explicitly folding both sections
        if (d.grid2HeaderAtTop && !d.model2Blocked) {
            d.model1Blocked = true
            d.model2Blocked = true

            return
        }

        // header on top, folded
        if (d.grid2HeaderAtTop && d.model2Blocked) {
            d.model2Blocked = false

            return
        }

        // header in the middle
        if (d.grid1FullyFilling) { // top section long enough to fill the whole view
            contentY = flickable1ContentHeight + d.header2Size - height
        } else {
            d.model2Blocked = !d.model2Blocked
        }
    }

    // The Flickable component (ListView or GridView) controls y positioning
    // of the header and it cannot be effectively overriden. As a solution to
    // this problem, the header can be reparented to a wrapper compensating
    // for the y offset.
    HeaderWrapper {
        parent: contentItem
        flickable: flickable1
        y: contentY
    }

    HeaderWrapper {
        parent: contentItem
        flickable: flickable2
        y: contentY + d.grid2HeaderOffset
    }

    QtObject {
        id: d

        readonly property real header1Size: flickable1.headerItem
                                            ? flickable1.headerItem.height : 0
        readonly property real header2Size: flickable2.headerItem
                                            ? flickable2.headerItem.height : 0

        readonly property bool grid1ContentInViewport:
            flickable1.y > contentY - Math.min(height, flickable1ContentHeight) + header1Size
        readonly property real grid2HeaderOffset:
            Math.min(Math.max(flickable2.y - contentY, header1Size), height - header2Size)

        readonly property bool grid2HeaderAtTop:
            grid2HeaderOffset === header1Size
        readonly property bool grid2HeaderAtEnd:
            grid2HeaderOffset === height - header2Size

        property bool model1Blocked: false
        property bool model2Blocked: false

        readonly property bool grid1FullyFilling:
            flickable1ContentHeight >= height - header2Size
        readonly property bool grid2FullyFilling:
            flickable2ContentHeight >= height - header1Size

        onGrid1FullyFillingChanged: {
            if (grid1FullyFilling) {
                model2Blocked = false
                contentY = 0
            }
        }

        onGrid2FullyFillingChanged: {
            if (grid2FullyFilling && model1Blocked) {
                model1Blocked = false
                contentY = flickable1ContentHeight - header1Size
            }
        }
    }

    Binding {
        when: d.model1Blocked
        target: flickable1
        property: "model"
        value: null

        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        when: d.model2Blocked
        target: flickable2
        property: "model"
        value: null

        restoreMode: Binding.RestoreBindingOrValue
    }
}

