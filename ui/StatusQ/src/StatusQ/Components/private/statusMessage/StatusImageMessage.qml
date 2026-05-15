import QtQuick
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: imageContainer

    enum ShapeType {
        ROUNDED = 0,
        LEFT_ROUNDED = 1,
        RIGHT_ROUNDED = 2
    }

    property alias imageAlias: imageMessage

    property bool isAppWindowActive: false
    property url source: ""
    property bool allCornersRounded: false
    property bool isLeftCorner: true
    property int imageWidth: 350
    property int shapeType: -1

    // Switches scaling mode for AnimatedImage:
    // - false (default): PreserveAspectFit → full image visible, may letterbox.
    // - true: PreserveAspectCrop → fills container, may crop edges.
    property bool isFillCropMode: false

    // Determines whether album images respond to user click.
    // - true (default): images are clickable; TapHandlers emit `clicked` on tap.
    // - false: images are display-only with no interaction.
    property bool imageClickable: true

    // Cursor shape used when hovering over clickable album images.
    // - Default: Qt.PointingHandCursor (hand icon).
    // - Common alternatives: Qt.ArrowCursor, Qt.CrossCursor, etc.
    property int imageCursorShape: Qt.PointingHandCursor

    property string loadingImageText: ""
    property string errorLoadingImageText: ""

    signal clicked(var image, var mouse, var imageSource)

    implicitWidth: imageMessage.width
    implicitHeight: imageMessage.paintedHeight

    QtObject {
        id: _internal
        readonly property bool isAnimated: !!source && source.toString().endsWith('.gif')
        property bool pausePlaying: false
    }

    AnimatedImage {
        id: imageMessage
        width: Math.min(sourceSize.width, imageWidth)
        height: imageContainer.isFillCropMode
                   ? width // Fixed box for crop
                   : (sourceSize.width > 0
                      ? Math.round(width * sourceSize.height / sourceSize.width) // Fit by width / Preserve aspect ratio
                      : implicitHeight) // Before image is loaded
        fillMode: imageContainer.isFillCropMode ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        source: imageContainer.source
        playing: _internal.isAnimated && isAppWindowActive && !_internal.pausePlaying
        cache: false

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Item {
                width: imageMessage.width
                height: imageMessage.height

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: imageMessage.width
                    height: imageMessage.height
                    radius: 16
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: 32
                    height: 32
                    radius: 4
                    visible: shapeType === StatusImageMessage.ShapeType.LEFT_ROUNDED //!isLeftCorner && !allCornersRounded
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 32
                    height: 32
                    radius: 4
                    visible: shapeType === StatusImageMessage.ShapeType.RIGHT_ROUNDED  //isLeftCorner && !allCornersRounded
                }
            }
        }

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
            enabled: imageContainer.imageClickable
            cursorShape: imageContainer.imageCursorShape
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            enabled: imageContainer.imageClickable
            onTapped: (eventPoint, button) => {
                if (_internal.isAnimated && button === Qt.LeftButton) {
                    // FIXME the ListView completely removes Items that scroll out of view
                    // so when we scroll backto the image, it gets reloaded and playing is reset
                    _internal.pausePlaying = !_internal.pausePlaying
                    return
                }
                imageContainer.clicked(imageMessage, { button }, imageMessage.source)
            }
            onLongPressed: {
                if (point.device.type !== PointerDevice.TouchScreen)
                    return
                imageContainer.clicked(imageMessage, { button: Qt.RightButton }, imageMessage.source)
            }
        }
    }

    Rectangle {
        id: loadingImage
        visible: imageMessage.status === Image.Loading
                 || imageMessage.status === Image.Error
        width: parent.width
        height: width
        border.width: 1
        border.color: Theme.palette.baseColor2
        radius: 8

        StatusBaseText {
            anchors.centerIn: parent
            text: imageMessage.status === Image.Error ? errorLoadingImageText: loadingImageText
            color: imageMessage.status === Image.Error?
                       Theme.palette.dangerColor1 :
                       Theme.palette.directColor1
            font.pixelSize: Theme.primaryTextFontSize
        }
    }
}
