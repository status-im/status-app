pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core

/*!
    \qmltype StatusAnimatedText
    \inherits StatusBaseText
    \inqmlmodule StatusQ.Controls
    \since StatusQ.Controls 0.1
    \brief Displays a status base text with color animation on text change

    A property animation is exposed in case any further change is needed, like setting different
    than the default color for animation. For more context on that refer to `StatusColorAnimation`
    component.

    Example of how to use it:

    \qml
        StatusAnimatedText {
            id: animatedText

            text: "anything"
            color: "red"
            animation.toColor: "blue"
        }
    \endqml

    For a list of components available see StatusQ.
 */

StatusBaseText {
    id: root

    property alias animation: animate  // Expose animation for customization

    wrapMode: Text.WordWrap
    elide: Text.ElideRight

    onTextChanged: {
        if (text === "") {
            return
        }
        animate.restart()
    }

    StatusColorAnimation {
        id: animate
        target: root
        fromColor: root.color
    }
}
