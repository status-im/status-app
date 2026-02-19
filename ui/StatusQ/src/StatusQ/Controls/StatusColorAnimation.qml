import QtQuick

import StatusQ.Core.Theme

/*!
    \qmltype StatusColorAnimation
    \inherits SequentialAnimation
    \inqmlmodule StatusQ.Controls
    \since StatusQ.Controls 0.1
    \brief Animates target property (that shold be a color property) from/to color to target component within set duration.

   Example of how to use it:

   \qml
        StatusBaseText {
            id: animatedText

            onTextChanged: {
                if (text === "") {
                    return
                }
                animate.restart()
            }

            StatusColorAnimation {
                id: animate
                target: animatedText
            }
        }
   \endqml

   For a list of components available see StatusQ.
 */

SequentialAnimation {
    id: root

    required property var target
    property string targetProperty: "color"
    property color fromColor: target.Theme.palette.directColor1
    property color toColor: StatusColors.getColor(fromColor, 0.1)
    property int duration: 500 // in milliseconds

    loops: 3
    alwaysRunToEnd: true

    ColorAnimation {
        target: root.target
        property: root.targetProperty
        from: root.fromColor
        to: root.toColor
        duration: root.duration
    }

    ColorAnimation {
        target: root.target
        property: root.targetProperty
        from: root.toColor
        to: root.fromColor
        duration: root.duration
    }
}
