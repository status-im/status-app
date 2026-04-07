pragma ComponentBehavior: Bound

import QtQuick

/*!
    \qmltype StatusImage
    \inherits Image
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief Draws an image. Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-image.html}{Image}.

    This is a plain wrapper for the Image QML type. It sets some default property values and
    adds some properties common to other media type wrappers.

    Example of how to use it:

    \qml
        StatusImage {
            anchors.fill: parent

            width: 100
            height: 100
            source: "qrc:/demoapp/data/logo-test-image.png"
        }
    \endqml

*/
Image {
    id: root

    /*!
        \qmlproperty bool StatusImage::isLoading

        \c true when the image is currently being loaded (status === Image.Loading).
        \c false otherwise.

    */
    readonly property bool isLoading: status === Image.Loading
    /*!
        \qmlproperty bool StatusImage::isError

        \c true when an error occurred while loading the image (status === Image.Error).
        \c false otherwise.
        \note  Setting an empty source is not considered an error.

    */
    readonly property bool isError: status === Image.Error

    fillMode: Image.PreserveAspectFit
    sourceSize: source.toString().endsWith(".svg") ? Qt.size(width, height) : undefined
}
