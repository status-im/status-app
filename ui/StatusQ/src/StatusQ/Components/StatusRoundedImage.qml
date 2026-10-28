import QtQuick

import StatusQ.Components.private
import StatusQ.Core.Theme

/*!
    \qmltype StatusRoundedImage
    \inherits RoundedRenderSizedImage
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief An image with rounded corners, over a background and within a border.

    The image rounds itself and draws the background and the border in the
    same pass (RoundedRenderSizedImage): no layer, and no seam between the
    image and the border. \c color, \c border.width, \c border.color,
    \c radius and the per-corner radii are those of a Rectangle: the border
    is 1 px and black by default, drawn only once set, and the image is inset
    by its width either way. The radius is half the width by default. It is
    an Image decoded for its size, as StatusImage, with \c isLoading and
    \c isError; \c image is the item itself.

    It has no size of its own: as an Image's, its implicit size is the
    image's, and none while there is no image (loading, error, no source).
    Size it, with \c Layout.preferredWidth and \c Layout.preferredHeight in a
    layout.

    Children are not clipped to the rounded shape. \c image.cutoutRadius cuts
    the image, the background and the border. The software renderer draws
    the plain image, with no background or border.

    Example of how to use it:

    \qml
        StatusRoundedImage {
            width: 40
            height: 40
            image.source: "qrc:/demoapp/data/logo-test-image.png"
        }
    \endqml
*/
RoundedRenderSizedImage {
    id: root

    /*!
        \qmlproperty RoundedRenderSizedImage StatusRoundedImage::image

        The item itself.
    */
    property alias image: root

    /*!
        \qmlproperty color StatusRoundedImage::color

        The background, under the image. Transparent by default.
    */
    property alias color: root.backgroundColor

    /*!
        \qmlproperty bool StatusRoundedImage::showLoadingIndicator

        Set to \c true to enable the Loading animation.
        Set to \c false to disable the Loading animation.
        \note  When enabled, the animation will be shown only when isLoading is \c true and
        isError is \c false.
    */
    property bool showLoadingIndicator: false

    /*!
        \qmlproperty bool StatusRoundedImage::isLoading

        \c true while the image is loading, unless set otherwise.
    */
    property bool isLoading: status === Image.Loading

    /*!
        \qmlproperty bool StatusRoundedImage::isError

        \c true when the image failed to load, unless set otherwise.
    */
    property bool isError: status === Image.Error

    // as Rectangle's: an unset border is 1 px, insetting the image
    unsetBorderWidth: 1

    // the box is rounded, a letterboxed image clipped to it
    roundedArea: RoundedRenderSizedImage.ItemArea
    radius: width / 2

    // as StatusImage: decoded for the rendered size
    fillMode: Image.PreserveAspectFit
    sourceSize: {
        if (vector)
            return Qt.size(width, height)
        const renderSized = fillMode === Image.PreserveAspectFit
                          || fillMode === Image.PreserveAspectCrop
                          || fillMode === Image.Stretch
        if (renderSized && explicitlySized)
            return Qt.size(Math.ceil(width), Math.ceil(height))
        return undefined
    }

    Loader {
        anchors.centerIn: parent
        active: root.showLoadingIndicator && !root.isError && root.isLoading
        sourceComponent: StatusLoadingIndicator {
            color: Theme.palette.directColor6
        }
    }
}
