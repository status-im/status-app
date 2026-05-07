import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Utils
import StatusQ.Core.Theme

/*!
    \qmltype StatusImageCrop
    \inherits Item
    \inqmlmodule StatusQ.Controls
    \since StatusQ.Controls 0.1
    \brief Draw a crop-window onto an image. Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-item.html}{Item}.

    Sizing

    User resizes the control as needed. Control adapts and centers the crop
    window inside the available space

    Performance

    The \c StatusImageCrop uses Canvas to draw the overlay in multiple steps.
    Drawing with canvas is inefficient therefore keep the usage to a minimum,
    as in the required space

    API

    The setCropRect is the only way to set the content shown in the crop window.

    /note "Fit window" used here reffer to optimum zoom to fit all the content
        in the view window; produces window borders if AR of the image is different
        than the window. This ia opposite to "Fill window" reffers to optimum zoom
        to fill all the view; parts of the content won't be visible if AR of the
        image is different than the AR of window
    /note The math is based on pixels so no subpixel accuracy. Didn't find it necessary for the current needs
    /note windowRect aspect ratio and cropRect aspect ratio are keept in sync

    Example of two controls; top WindowStyle.Rounded, bottom WindowStyle.Rectangular
    \image eg-StatusImageCrop.png

    Example of how to use it:

    \qml
        StatusImageCrop {
            anchors.fill: parent

            width: 100
            height: 100 * aspectRatio
            source: "qrc:/demoapp/data/logo-test-image.png"
            windowStyle: StatusImageCrop.WindowStyle.Rounded
        }
    \endqml

    For a list of components available see StatusQ.
*/
Item {
    id: root

    implicitWidth: 400
    implicitHeight: 400 / aspectRatio

    /*!
       \qmlproperty url StatusImageCrop::source
       Path to the image to be cropped
    */
    /*required*/ property alias source: mainImage.source

    enum WindowStyle {
        Rounded,
        Rectangular
    }
    /*!
        \qmlproperty WindowStyle StatusImageCrop::windowStyle
        Crop window styles
        \value Rounded ellipses bounded by cropRect rectangle
        \value Rectangular with rounded corners specified by radius
    */
    property int windowStyle: StatusImageCrop.WindowStyle.Rectangular
    /*!
        \qmlproperty int StatusImageCrop::radius
        Valid only when windowStyle is Rounded
    */
    property int radius: 8
    /*!
        \qmlproperty color StatusImageCrop::wallColor
        Color used outside the crop-rect. Tells user which part won't be available after cropping
    */
    property color wallColor: StatusColors.black
    /*!
        \qmlproperty real StatusImageCrop::wallTransparency
        Transparency outside the crop-rect 0.0 - 1.0 (inclusive). Tells user which part won't
        be available after cropping
    */
    property real wallTransparency: 0.7

    /*!
        \qmlproperty bool StatusImageCrop::allowZoomToFitAllContent

        \c true to limit the content to fit at minimum zoom; that's it, the user will see the entire image
            in the crop window, in case of aspect-ratio mismatch, allowing transparent/no-content borders in the crop window.
        \c false to limit the content to fill at minimum zoom; that's it, the user will see only part of the image
            in the crop window in case of aspect-ratio mismatch. This way, we don't allow transparent/no-content space
    */
    property bool allowZoomToFitAllContent: false
    /*!
        \qmlproperty real StatusImageCrop::minZoomScale
        Minimum allowed zoom. This is 1 if \c allowZoomToFitAllContent is true else depends on the
        source aspect ratio.
    */
    readonly property real minZoomScale: allowZoomToFitAllContent ? 1 : d.zoomToFill
    /*!
        \qmlproperty real StatusImageCrop::maxZoomScale
        Don't allow to zoom in more than maxZoomScale factor
    */
    property real maxZoomScale: 10

    /*!
        \qmlproperty rect StatusImageCrop::cropRect
        The content shown in the crop window. Values are expected to be in image coordinates.
        The crop-window aspect-ratio is adjusted to match the cropRect value.
        The default value shows an 1.0 AR to Fit Window
        e.g. to set the crop window to show and match image's AR use Qt.rect(0, 0, sourceSize.width, sourceSize.height)
    */
    readonly property rect cropRect: d.cropRect
    /*!
        \qmlproperty real StatusImageCrop::aspectRatio
    */
    readonly property real aspectRatio: d.cropRect.height !== 0 ? d.cropRect.width/d.cropRect.height : 0
    /*!
        \qmlproperty real StatusImageCrop::zoomScale
    */
    readonly property real zoomScale: d.currentZoom(sourceSize, Qt.size(d.cropRect.width, d.cropRect.height))

    /*!
        \qmlproperty size StatusImageCrop::sourceSize

        Image size if one is set. StatusImageCrop::cropRect is relative to the rect with top-corner
        (0,0) and StatusImageCrop::sourceSize

        \sa StatusImageCrop::source
    */
    readonly property alias sourceSize: mainImage.sourceSize
    /*!
        \qmlproperty real StatusImageCrop::scrToImgScale

        Screen crop window to \a cropRect ratio. Can be used to translate from
        screen coordinates into image coordinates e.g. to adjust \a cropRect accordingly

        \note windowRect aspect-ratio and d.cropRect aspect-ratio are the same
        \sa StatusImageCrop::cropRect
    */
    readonly property real scrToImgScale: windowRect.wW/d.cropRect.width

    /*!
        \qmlmethod StatusImageCrop::setCropRect(rect)

        The only way to set StatusImageCrop::cropRect from outside

        The new rect will be adjusted to account for the zoom [1, StatusImageCrop::maxZoomScale]

        \note the source image must be set and \c sourceSize valid otherwise, an error is logged to \c console
        \note If the new rect has a diferent area the crop window will adjust to the new AR
    */
    function setCropRect(newRect /*rect*/) {
        if (newRect.x === 0 && newRect.y === 0 && newRect.width === 0 && newRect.height === 0) { // reset
            d.cropRect = newRect
            return
        }

        if(newRect.width === 0 || newRect.height === 0)
            return
        if(root.sourceSize.width === 0 || root.sourceSize.height === 0)
            console.error("Wrong source size. Ensure source is set")

        let n = newRect
        const s = root.sourceSize
        let nZoom = d.currentZoom(s, Qt.size(n.width, n.height))
        if(nZoom > root.maxZoomScale) {
            nZoom = root.maxZoomScale
            n = root.getZoomRect(nZoom)
        }
        else if(nZoom < root.minZoomScale) {
            nZoom = root.minZoomScale
            n = root.getZoomRect(nZoom)
        }

        // Limit panning
        if((n.width/n.height) < (s.width/s.height)) {
            // Crop window narrower than source
            if(n.x < 0)
                n.x = 0
            const upBoundY = n.height > s.height ? s.height - n.height : 0
            if(n.y < upBoundY)
                n.y = upBoundY
            if((n.x + n.width) > s.width)
                n.x = s.width - n.width
            const loBoundY = n.height > s.height ? 0 : s.height - n.height
            if(n.y > loBoundY)
                n.y = loBoundY
        }
        else {
            // Crop window wider than source
            const leftBoundX = n.width > s.width ? s.width - n.width : 0
            if(n.x < leftBoundX)
                n.x = leftBoundX
            if(n.y < 0)
                n.y = 0
            const rightBoundY = n.width > s.width ? 0 : s.width - n.width
            if(n.x > rightBoundY)
                n.x = rightBoundY
            if((n.y + n.height) > s.height)
                n.y = s.height - n.height
        }
        d.cropRect = n
    }

    function getZoomRect(scale /*real*/) {
        const oldCenter = root.rectCenter(root.cropRect)
        const inflatedRect = root.inflateRectBy(d.minimumCropRect(), 1/scale)
        return root.recenterRect(inflatedRect, oldCenter);
    }

    /*!
        \qmlmethod StatusImageCrop::inflateRectBy(rect target, real scale)
        Inflates the curren \a target rectangle with the \a scale while keeping the center fixed
    */
    function inflateRectBy(target /*rect*/, scale /*real*/) {
        const inflatedWidth = target.width * scale
        const inflatedHeight = target.height * scale
        return Qt.rect(target.x - (inflatedWidth - target.width)/2, target.y - (inflatedHeight - target.height)/2, inflatedWidth, inflatedHeight)
    }

    /*!
        \qmlmethod StatusImageCrop::rectCenter(rect target)
        Returns the center point of the \a target rectangle as a Qt.point
    */
    function rectCenter(target /*rect*/) /*Qt.point*/ {
        return Qt.point(target.x + target.width/2, target.y + target.height/2)
    }

    /*!
        \qmlmethod StatusImageCrop::recenterRect(rect target)
        Move the \a target rectangle's center to a /a newCenter
    */
    function recenterRect(target /*rect*/, newCenter/*point*/) {
        return Qt.rect(newCenter.x - target.width/2 , newCenter.y - target.height/2, target.width, target.height)
    }

    function fillContentInWindow(contentSize /*size*/, windowSize /*size*/) {
        const contentAR = contentSize.width/contentSize.height
        const windowAR = windowSize.width/windowSize.height
        const heightBound = contentAR > windowAR
        if(heightBound) {
            const wWidth = contentSize.height * windowAR
            const horizontalBorder = (contentSize.width - wWidth)/2
            return Qt.rect(horizontalBorder, 0, wWidth, contentSize.height)
        }
        else {
            const wHeight = contentSize.width / windowAR
            const verticalBorder = (contentSize.height - wHeight)/2
            return Qt.rect(0, verticalBorder, contentSize.width, wHeight)
        }
    }

    QtObject {
        id: d

        property rect cropRect
        onCropRectChanged: windowRect.requestPaint()

        readonly property real zoomToFill: {
            const rectangle = root.fillContentInWindow(root.sourceSize, d.cropWindowSize)
            return d.currentZoom(root.sourceSize, Qt.size(rectangle.width, rectangle.height))
        }

        property size cropWindowSize: Qt.size(d.cropRect.width, d.cropRect.height)

        //> 1.0 is the content represented by w fully inscribed in c
        function currentZoom(c /*size*/, w /*size*/) {
            const wScale = c.width/w.width
            const hScale = c.height/w.height
            return Math.max(wScale, hScale)
        }

        //> cropRect for minimum zoom: 1.0
        function minimumCropRect() {
            const sourceAR = root.sourceSize.width/root.sourceSize.height
            const widthBound =  sourceAR > root.aspectRatio
            const minCropSize = widthBound ? Qt.size(root.sourceSize.width, root.sourceSize.width/root.aspectRatio)
                                           : Qt.size(root.sourceSize.height * root.aspectRatio, root.sourceSize.height)
            let res = Qt.rect(widthBound ? 0 : -(root.sourceSize.width - minCropSize.width)/2,    // x
                           widthBound ? -(root.sourceSize.height - minCropSize.height)/2 : 0,  // y
                           minCropSize.width, minCropSize.height)
            return res
        }
    }

    onWindowStyleChanged: windowRect.requestPaint()
    onRadiusChanged: windowRect.requestPaint()
    onSourceSizeChanged: {
        if(d.cropWindowSize.width > 0 && d.cropWindowSize.height > 0)
            d.cropRect = root.fillContentInWindow(sourceSize, d.cropWindowSize)
    }

    Canvas {
        id: windowRect

        anchors.fill: parent

        property bool widthFit: (root.width / root.aspectRatio) <= root.height
        // Window width
        property real wW: widthFit ? root.width : root.height * root.aspectRatio
        // Window height
        property real wH: widthFit ? root.width / root.aspectRatio : root.height

        onPaint: {
            const wSize = Qt.size(wW, wH)
            const contentSize = canvasSize
            const clearSize = Qt.size(Math.ceil(canvasSize.width), Math.ceil(canvasSize.height))
            const r = root.radius

            var ctx = getContext("2d")

            ctx.save()

            ctx.clearRect(0, 0, clearSize.width, clearSize.height)

            // Fill all with wallColor in order to clip the window from it
            ctx.fillStyle = Qt.rgba(root.wallColor.r, root.wallColor.g, root.wallColor.b, root.wallTransparency)
            ctx.fillRect(0, 0, clearSize.width, clearSize.height)

            // Cut opaque new pixels from background
            ctx.globalCompositeOperation = "source-out"

            // Draw the window
            ctx.beginPath()
            const cW = Qt.rect((contentSize.width - wSize.width)/2, (contentSize.height - wSize.height)/2, wSize.width, wSize.height)
            if(root.windowStyle === StatusImageCrop.WindowStyle.Rounded)
                ctx.ellipse(cW.x, cW.y, cW.width, cW.height)
            else if(root.windowStyle === StatusImageCrop.WindowStyle.Rectangular)
                ctx.roundedRect(cW.x, cW.y, cW.width, cW.height, r, r)
            ctx.fill()
            ctx.restore()
        }
    }

    Image {
        id: mainImage

        fillMode: Image.PreserveAspectFit
        autoTransform: true
        z: windowRect.z - 1

        // Transform to keep the center of the image window in x and y coordinates
        transform: [
            Translate {
                readonly property real s: mainImage.scale
                x: -(d.cropRect.x + d.cropRect.width/2)
                y: -(d.cropRect.y + d.cropRect.height/2)
            },
            Scale {
                xScale: root.scrToImgScale
                yScale: root.scrToImgScale
            }
        ]
        // Align window center to window rect
        x: windowRect.x + windowRect.width/2
        y: windowRect.y + windowRect.height/2
        cache: false
    }
}
