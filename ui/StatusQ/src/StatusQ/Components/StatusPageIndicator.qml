pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Controls

/*!
   \qmltype StatusPageIndicator
   \inherits Item
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief Displays page indicator, clicking on a certain page number, it becomes selected and `currentIndex` is set accordingly.

   Example:

   \qml
    StatusPageIndicator {
        totalPages: 10
        currentIndex: 5
    }
   \endqml

   \image status_page_indicator.png

   For a list of components available see StatusQ.
*/

Item {
    id: root

    property int totalPages: 0
    property int currentIndex: 0
    property int spacing: 8

    implicitHeight: 38
    implicitWidth: d.maxElements * d.buttonWidth + (d.maxElements - 1) * root.spacing

    onTotalPagesChanged: d.applyChanges()
    onCurrentIndexChanged: d.applyChanges()

    QtObject {
        id: d

        readonly property int maxElements: 7
        readonly property int buttonWidth: 38
        readonly property int buttonsInRow: 3

        property ListModel pages: ListModel {}

        function applyChanges() {
            d.pages.clear()
            let displayFirst = root.totalPages > 0
            if (displayFirst) {
                d.pages.append({"itemIndex": 0, "itemText": (1).toString()})
            }

            let displayLeftDots = root.totalPages > 5 && root.currentIndex - d.buttonsInRow >= 0
            if (displayLeftDots) {
                d.pages.append({"itemIndex": -1, "itemText": "..."})
            }

            if (root.totalPages >= d.buttonsInRow) {
                if (root.totalPages < 4) {
                    d.pages.append({"itemIndex": root.totalPages - 2, "itemText": (root.totalPages - 1).toString()})
                }
                else if (root.totalPages < 5) {
                    d.pages.append({"itemIndex": root.totalPages - 3, "itemText": (root.totalPages - 2).toString()})
                    d.pages.append({"itemIndex": root.totalPages - 2, "itemText": (root.totalPages - 1).toString()})
                }
                else if (root.totalPages < 6) {
                    d.pages.append({"itemIndex": root.totalPages - 4, "itemText": (root.totalPages - 3).toString()})
                    d.pages.append({"itemIndex": root.totalPages - 3, "itemText": (root.totalPages - 2).toString()})
                    d.pages.append({"itemIndex": root.totalPages - 2, "itemText": (root.totalPages - 1).toString()})
                }
                else {
                    if (root.currentIndex == 0) {
                        d.pages.append({"itemIndex": root.currentIndex + 1, "itemText": (root.currentIndex + 2).toString()})
                        d.pages.append({"itemIndex": root.currentIndex + 2, "itemText": (root.currentIndex + 3).toString()})
                    }
                    else if (root.currentIndex == 1) {
                        d.pages.append({"itemIndex": root.currentIndex, "itemText": (root.currentIndex + 1).toString()})
                        d.pages.append({"itemIndex": root.currentIndex + 1, "itemText": (root.currentIndex + 2).toString()})
                    }
                    else if (root.currentIndex == root.totalPages - 1) {
                        d.pages.append({"itemIndex": root.totalPages - 3, "itemText": (root.totalPages - 2).toString()})
                        d.pages.append({"itemIndex": root.totalPages - 2, "itemText": (root.totalPages - 1).toString()})
                    }
                    else if (root.currentIndex == root.totalPages - 2) {
                        d.pages.append({"itemIndex": root.totalPages - 3, "itemText": (root.totalPages - 2).toString()})
                        d.pages.append({"itemIndex": root.totalPages - 2, "itemText": (root.totalPages - 1).toString()})
                    }
                    else {
                        d.pages.append({"itemIndex": root.currentIndex - 1, "itemText": (root.currentIndex).toString()})
                        d.pages.append({"itemIndex": root.currentIndex, "itemText": (root.currentIndex + 1).toString()})
                        d.pages.append({"itemIndex": root.currentIndex + 1, "itemText": (root.currentIndex + 2).toString()})
                    }
                }
            }

            let displayRightDots = root.totalPages > 5  && root.totalPages - root.currentIndex > d.buttonsInRow
            if (displayRightDots) {
                d.pages.append({"itemIndex": -1, "itemText": "..."})
            }

            let displayLast = root.totalPages > 1
            if (displayLast) {
                d.pages.append({"itemIndex": root.totalPages - 1, "itemText": (root.totalPages).toString()})
            }
        }
    }

    ListView {
        id: listView
        anchors.horizontalCenter: parent.horizontalCenter
        width: listView.count * d.buttonWidth + (listView.count - 1) * root.spacing
        orientation: ListView.Horizontal
        spacing: root.spacing
        model: d.pages
        delegate: StatusBaseButton {
            objectName: "Page-%1".arg(itemText)
            text: itemText
            size: StatusBaseButton.Size.Small
            normalColor: itemIndex === root.currentIndex? Theme.palette.primaryColor3 : "transparent"
            hoverColor: itemIndex === root.currentIndex? Theme.palette.primaryColor2 : Theme.palette.primaryColor3
            disabledColor: itemIndex === root.currentIndex? Theme.palette.baseColor2 : "transparent"
            textColor: Theme.palette.primaryColor1
            disabledTextColor: Theme.palette.baseColor1

            onClicked: {
                if (itemIndex === -1) {
                    return
                }
                root.currentIndex = itemIndex
            }
        }
    }
}

