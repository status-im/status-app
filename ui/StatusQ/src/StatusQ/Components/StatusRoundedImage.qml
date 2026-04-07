pragma ComponentBehavior: Bound

import QtQuick

/*!
    \qmltype StatusRoundedImage
    \inherits StatusRoundedComponent
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief Specialization of StatusRoundedComponent with a StatusImage as content.

    Example of how to use it:

    \qml
        StatusRoundedImage {
            image.source: "qrc:/demoapp/data/logo-test-image.png"
        }
    \endqml
*/
StatusRoundedComponent {
    id: root

    property alias image: image

    isLoading: image.isLoading
    isError: image.isError
    border.width: 0

    StatusImage {
        id: image

        anchors.fill: parent
        anchors.margins: parent.border.width
    }
}
