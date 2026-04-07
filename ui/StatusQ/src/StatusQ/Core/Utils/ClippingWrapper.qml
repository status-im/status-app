pragma ComponentBehavior: Bound

import QtQuick

/*!
   \qmltype ClippingWrapper
   \inherits Item
   \inqmlmodule StatusQ.Core.Utils
   \since StatusQ.Core.Utils 0.1
   \brief A component allowing to clip a nested component with a specified margins.
   It doesn't affect any visual margins or paddings, but moves bounds of clipping
   by a given clipXXXMargin.
*/
Item {
    id: root

    default property alias data: content.data

    property real clipTopMargin: 0
    property real clipBottomMargin: 0
    property real clipLeftMargin: 0
    property real clipRightMargin: 0

    Item {
        anchors.fill: parent

        anchors.topMargin: -root.clipTopMargin
        anchors.bottomMargin: -root.clipBottomMargin
        anchors.leftMargin: -root.clipLeftMargin
        anchors.rightMargin: -root.clipRightMargin

        clip: true

        Item {
            id: content

            anchors.fill: parent

            anchors.topMargin: root.clipTopMargin
            anchors.bottomMargin: root.clipBottomMargin
            anchors.leftMargin: root.clipLeftMargin
            anchors.rightMargin: root.clipRightMargin
        }
    }
}
