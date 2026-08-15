import QtQuick

import StatusQ.Components

/*!
  \qmltype NetworkIcon
  \brief A network logo squared off into a rounded rectangle.

  The network assets paint their own circle, so a radius alone leaves it round. Drawing the
  artwork larger than the box and letting the mask crop it is what squares it off; √2 is the
  smallest scale that still covers the corners.
*/
StatusRoundedComponent {
    id: root

    property alias source: image.source

    implicitWidth: 14
    implicitHeight: 14
    radius: 4
    border.width: 0

    isLoading: image.isLoading
    isError: image.isError

    StatusImage {
        id: image

        anchors.centerIn: parent
        width: Math.ceil(parent.width * Math.SQRT2)
        height: width
    }
}
