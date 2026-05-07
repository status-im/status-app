import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

/*!
   \qmltype StatusPasswordInput
   \inherits StatusTextField
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief The StatusPasswordInput control provides a generic user password input

   Example of how to use it:

   \qml
        StatusPasswordInput {
            placeholderText: qsTr("Password")
        }
   \endqml

   For a list of available components see StatusQ.
*/

StatusTextField {
    id: root

    property bool hasError

    QtObject {
        id: d

        readonly property int inputTextPadding: root.Theme.defaultPadding
    }

    leftPadding: d.inputTextPadding
    rightPadding: d.inputTextPadding
    implicitWidth: 480
    implicitHeight: 44

    echoMode: TextInput.Password

    background: Rectangle {
        color: Theme.palette.baseColor2
        radius: Theme.radius
        border.width: root.focus || root.hasError ? 1 : 0
        border.color: root.hasError ? Theme.palette.dangerColor1 : Theme.palette.primaryColor1
    }
}
