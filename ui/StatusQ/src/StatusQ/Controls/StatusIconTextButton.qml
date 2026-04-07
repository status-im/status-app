pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

/*!
   \qmltype StatusIconTextButton
   \inherits Item
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief It presents an icon + plain text button. Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-controls2-abstractbutton.html}{AbstractButton}.

   The \c StatusIconTextButton is a clickable icon + text control.

   NOTE: It only contemplates `display` property as `AbstractButton.TextBesideIcon`.

   Example of how the component looks like:
   \image status_icon_text_button.png
   Example of how to use it:
   \qml
        StatusIconTextButton {
            spacing: 0
            statusIcon: "next"
            iconRotation: 180
            icon.width: 12
            icon.height: 12
            text: qsTr("Back")
            onClicked: console.log("Clicked!")
        }
   \endqml
   For a list of components available see StatusQ.
*/
AbstractButton {
    id: root

    /*!
       \qmlproperty string StatusIconTextButton::statusIcon
       This property holds the status icon name.
    */
    property string statusIcon
    /*!
       \qmlproperty int StatusIconTextButton::iconRotation
       This property holds the status icon rotation.
    */
    property int iconRotation
    /*!
       \qmlproperty color StatusIconTextButton::textColor
       This property holds the text color.
    */
    property color textColor: Theme.palette.primaryColor1

    icon.color: Theme.palette.primaryColor1
    icon.height: 24
    icon.width: 24
    font.pixelSize: Theme.additionalTextSize
    contentItem: RowLayout {
         spacing: root.spacing
         StatusIcon {
             Layout.alignment: Qt.AlignVCenter
             icon: root.statusIcon || root.icon.source || root.icon.name
             color: root.icon.color
             width: root.icon.width
             height: root.icon.height
             rotation: root.iconRotation
             visible: status == Image.Ready
         }
         StatusBaseText {
             Layout.alignment: Qt.AlignVCenter
             Layout.fillWidth: true
             text: root.text
             color: root.textColor
             font.pixelSize: root.font.pixelSize
         }
     }

    // TODO: To remove when switch to Qt 5.15
    StatusMouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.NoButton
      hoverEnabled: true
    }
}
