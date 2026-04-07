pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

PageIndicator {
    id: root

    QtObject {
        id: d
        function switchToNextOrFirstPage() {
            root.currentIndex = (root.currentIndex + 1) % root.count
        }

        readonly property int pageChangingTimerDuration: 3000
    }

    interactive: true
    currentIndex: -1

    Component.onCompleted: currentIndex = 0 // start switching pages

    delegate: Control {
        id: pageIndicatorDelegate

        implicitWidth: 44
        implicitHeight: 8

        readonly property bool isCurrentPage: index === root.currentIndex

        background: Rectangle {
            color: Theme.palette.baseColor5
            radius: 4
            HoverHandler {
                cursorShape: hovered ? Qt.PointingHandCursor : undefined
            }
        }
        contentItem: Item {
            Rectangle {
                NumberAnimation on width {
                    from: 0
                    to: pageIndicatorDelegate.availableWidth
                    duration: d.pageChangingTimerDuration
                    running: pageIndicatorDelegate.isCurrentPage && visible
                    onStopped: {
                        if (pageIndicatorDelegate.isCurrentPage)
                            d.switchToNextOrFirstPage()
                    }
                }

                height: parent.height
                color: pageIndicatorDelegate.isCurrentPage ?
                           Theme.palette.baseColor1 : StatusColors.transparent
                radius: 4
            }
        }
    }
}
