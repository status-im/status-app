import QtQuick

/*!
    \qmltype StatusAnimatedImage
    \inherits AnimatedImage
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief Draws an animated image. Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-animatedimage.html}{AnimatedImage}.

    This is a plain wrapper for the AnimatedImage QML type. It sets some default property values and
    adds some properties common to other media type wrappers.

    Example of how to use it:

    \qml
        StatusAnimatedImage {
            width: 100
            height: 100
            source: "qrc:/demoapp/data/logo-test-image.gif"
        }
    \endqml

*/
AnimatedImage {
    id: root

    /*!
        \qmlproperty bool StatusAnimatedImage::isLoading

        \c true when the image is currently being loaded (status === AnimatedImage.Loading).
        \c false otherwise.

    */
    readonly property bool isLoading: status === AnimatedImage.Loading
 
    /*!
        \qmlproperty bool StatusAnimatedImage::isError

        \c true when an error occurred while loading the image (status === AnimatedImage.Error).
        \c false otherwise.
        \note  Setting an empty source is not considered an error.

    */
    readonly property bool isError: status === AnimatedImage.Error

    readonly property bool isEmpty: status === AnimatedImage.Null

    fillMode: AnimatedImage.PreserveAspectFit
}
