pragma ComponentBehavior: Bound

import QtQuick

/*!
   \qmltype StatusCenteredFlow
   \inherits Item
   \inqmlmodule StatusQ.Core
   \since StatusQ.Core 0.1
   \brief Pure QML wrapper around Flow component allowing center alignment.

   The \c StatusCenteredFlow works similar to standard Flow component with several limitations:

   - Positioner attached property is unavailable for child items
   - Statically declared items are positioned always before items coming from Repeater
   - New items provided by Repeater are located always at the end (inserting to model is not supported)

   Example of how to use it:

   \qml
        StatusCenteredFlow {
            anchors.fill: parent

            Rectangle {
                width: 20
                height: 30
            }
            Rectangle {
                width: 20
                height: 30
            }
        }
   \endqml

   With Repeater:

   \qml
        StatusCenteredFlow {
            anchors.fill: parent

            Repeater {
                model: 10
                delegate: CheckBox { text: "check box " + index }
            }
        }
   \endqml
*/
Item {
    id: root

    property alias spacing: flow.spacing
    property alias padding: flow.padding
    property alias bottomPadding: flow.bottomPadding
    property alias leftPadding: flow.leftPadding
    property alias rightPadding: flow.rightPadding
    property alias topPadding: flow.topPadding

    property bool centered: true

    onCenteredChanged: flow.onPositioningComplete()

    implicitHeight: flow.implicitHeight

    Flow {
        id: flow

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        onPositioningComplete: {
            if (!root.centered || children.length === 0)
                return

            const rows = []
            let row = [children[0]]

            for (let i = 1; i < children.length; i++) {
                const prevChild = children[i - 1]
                const child = children[i]

                if (prevChild.y === child.y) {
                    row.push(child)
                } else {
                    rows.push(row)
                    row = [child]
                }
            }

            rows.push(row)

            rows.map(row => {
                 const firstInRow = row[0]
                 const lastInRow = row[row.length - 1]

                 const beginX = firstInRow.x
                 const endX = lastInRow.x + lastInRow.width

                 const offset = (flow.width - flow.rightPadding - flow.leftPadding - (endX - beginX)) / 2

                 row.map(item => { item.centeredX = item.x + offset })
            })
        }
    }

    Component {
        id: placeholder

        Item {
            property int centeredX: 0
        }
    }

    QtObject {
        id: d

        property var registry: []
    }

    onChildrenChanged: {
        for(let i = 0; i < children.length; i++){
            const child = children[i]

            if (child instanceof Repeater || child === flow
                    || d.registry.indexOf(child) !== -1)
                continue

            d.registry.push(child)

            const placeholderProperties = {
                parent: flow,
                width: Qt.binding(() => child.width),
                height: Qt.binding(() => child.height)
            }

            const placeholderObj = placeholder.createObject(child, placeholderProperties)

            child.x = Qt.binding(() => root.centered ? placeholderObj.centeredX : placeholderObj.x)
            child.y = Qt.binding(() => placeholderObj.y)

            const cleanup = () => { d.registry = d.registry.filter(value => value !== child) }
            child.Component.destruction.connect(cleanup)
        }
    }
}

