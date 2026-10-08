import QtQuick

import StatusQ.Components.private

/*!
    \qmltype StatusImage
    \inherits Image
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief Draws an image. Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-image.html}{Image}.

    This is a plain wrapper for the Image QML type. It sets some default property values and
    adds some properties common to other media type wrappers.

    sourceSize is in logical pixels for raster sources too and follows the item's size, so a
    raster is decoded at the rendered size x device pixel ratio (rounded up to a proportional
    step, never upscaled, capped at 2048px per side) instead of its native resolution, and
    re-decoded when the item is resized past a step. Items sized by their implicit size and
    tiled or padded images decode at native size. Set \c sourceSize explicitly to override.

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
RenderSizedImage {
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
    sourceSize: {
        if (source.toString().endsWith(".svg"))
            return Qt.size(width, height)
        // Tiled and padded images draw at native size; an item sized by its implicit size
        // already shows the native decode
        const renderSized = fillMode === Image.PreserveAspectFit
                          || fillMode === Image.PreserveAspectCrop
                          || fillMode === Image.Stretch
        if (renderSized && explicitlySized)
            return Qt.size(Math.ceil(width), Math.ceil(height))
        return undefined
    }
}
