import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

/*!
   \qmltype StatusLinkText
   \inherits StatusBaseText
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief Displays text available for mouse interaction and styled as link.

   Example of how to use it:

   \qml
        StatusLinkText {
            text: qsTr("Click me")
            onClicked: console.log("link clicked")
        }
   \endqml

   For a list of components available see StatusQ.
*/

StatusBaseText {
    id: root

    /*!
       \qmlproperty StatusLinkText StatusLinkText::linkColor
       This property holds text color while it's hovered by mouse cursor
    */
    linkColor: Theme.palette.primaryColor1

    /*!
       \qmlproperty StatusLinkText StatusLinkText::normalColor
       This property holds text color in unhovered state
    */
    property color normalColor: Theme.palette.baseColor1

    /*!
       \qmlproperty StatusLinkText StatusLinkText::containsMouse
       This property true whenever text is hovered by mouse cursor
    */
    readonly property alias containsMouse: textMouseArea.containsMouse

    signal clicked(var mouseEvent)

    maximumLineCount: 1
    elide: Text.ElideRight
    color: root.containsMouse ? root.linkColor : root.normalColor
    font.pixelSize: Theme.additionalTextSize
    font.weight: Font.Medium
    font.underline: root.containsMouse

    StatusMouseArea {
        id: textMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouseEvent => root.clicked(mouseEvent)
    }
}
