pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

/*!
   \qmltype StatusStepper
   \inherits Item
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief Displays total number of steps which need to be passed, marking each
          completed step based on `completedSteps` property

   Example:

   \qml
    StatusStepper {
        width: 400
        title: "Account %1 of %2".arg(completedSteps).arg(totalSteps)
        totalSteps: 6
        completedSteps: 1
    }
   \endqml

   \image status_stepper.png

   For a list of components available see StatusQ.
*/

Control {
    id: root

    property alias title: title.text
    property int totalSteps: 1
    property int completedSteps: 1

    horizontalPadding: Theme.bigPadding
    verticalPadding: Theme.padding

    QtObject {
        id: d

        readonly property int stepHeight: 4
        readonly property int spaceBetweenSteps: 2
    }

    contentItem: ColumnLayout {
        spacing: 8

        StatusBaseText {
            id: title

            Layout.fillWidth: true
            horizontalAlignment: Qt.AlignHCenter
            color: Theme.palette.baseColor1
            wrapMode: Text.Wrap
        }

        RowLayout {
            spacing: d.spaceBetweenSteps
            uniformCellSizes: true

            Repeater {
                id: repeater
                model: root.totalSteps

                delegate: Rectangle {
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: d.stepHeight

                    radius: d.stepHeight / 2
                    color: index < root.completedSteps ? root.Theme.palette.primaryColor1
                                                       : root.Theme.palette.baseColor2
                }
            }
        }
    }
}
