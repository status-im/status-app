import QtQuick
import QtQuick.Window

import StatusQ.Components
import StatusQ.Components.private
import StatusQ.Core
import StatusQ.Core.Theme

import shared.panels
import utils

Item {
    id: root

    property int verticalPadding: 0
    property int imageWidth: 350
    property url source
    property bool isActiveChannel: false
    property bool playing: Window.window.active

    property bool isAnimated: !!source && source.toString().endsWith('.gif')
    // The rounded image: a StatusRoundedImage, or a RoundedAnimatedImage for
    // a gif. Both decode at a bounded size (a chat can hold dozens of photos
    // and a full decode of each exhausts memory).
    readonly property Item imageAlias: imageLoader.item
    property bool allCornersRounded: false
    property bool isOnline: true // TODO: mark as required when migrating to 5.15 or above
    property bool imageLoaded: d.imageStatus === Image.Ready
    property bool asynchronous: true
    // GIFs only loop properly with the frame cache on
    property bool cacheImage: false
    property bool leftTail: true

    signal clicked(var image, var mouse)

    width: loadingImageLoader.active ? loadingImageLoader.width : imageBox.width
    height: loadingImageLoader.active ? loadingImageLoader.height : imageBox.height

    onIsOnlineChanged: {
        if (!isOnline)
            return

        if (d.imageStatus === Image.Error) {
            d.reloadImage()
        }
    }

    QtObject {
        id: d

        readonly property int imageStatus: root.imageAlias ? root.imageAlias.status : Image.Loading
        // A gif's decode width, in pixels: in 128px steps so a layout-driven
        // imageWidth doesn't re-decode every visible gif on rotation. A
        // still decodes for imageWidth in StatusImage's own steps.
        readonly property int decodeWidth: Math.ceil(root.imageWidth * Screen.devicePixelRatio / 128) * 128

        // the bubble's tail is the small corner
        readonly property real bottomLeftRadius: root.leftTail && !root.allCornersRounded ? 4 : 16
        readonly property real bottomRightRadius: !root.leftTail && !root.allCornersRounded ? 4 : 16

        function reloadImage() {
            const image = root.imageAlias
            image.source = ""
            image.source = Qt.binding(() => root.source)
        }

        function scheduleRetry(status) {
            if (status === Image.Error && !retryTimer.running) {
                retryTimer.interval = retryTimer.initialInterval
                retryTimer.start()
            }
        }
    }

    Timer {
        id: retryTimer

        readonly property int initialInterval: 10 * 1000 // 10s

        onTriggered: {
            if (d.imageStatus === Image.Error && root.isOnline) {
                d.reloadImage()
                interval *= 2
                restart()
            }
        }
    }

    Item {
        id: imageBox

        width: root.imageAlias ? root.imageAlias.width : 0
        height: root.imageAlias ? root.imageAlias.paintedHeight : 0

        Loader {
            id: imageLoader
            asynchronous: root.asynchronous
            sourceComponent: root.isAnimated ? animatedImageComponent : stillImageComponent
        }

        StatusMouseArea {
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            anchors.fill: parent
            onClicked: (mouse) => root.clicked(root.imageAlias, mouse)
        }
    }

    // Rounded in the pass drawing the image's own texture, fitted by width:
    // the box has the image's aspect ratio. Only the needed kind of image is
    // built.
    Component {
        id: stillImageComponent

        StatusRoundedImage {
            width: Math.min(implicitWidth, root.imageWidth)
            height: implicitWidth > 0 ? Math.round(width * implicitHeight / implicitWidth) : 0

            radius: 16
            bottomLeftRadius: d.bottomLeftRadius
            bottomRightRadius: d.bottomRightRadius
            unsetBorderWidth: 0

            // the box has the image's aspect ratio to the pixel: filling it
            // leaves no sliver uncovered by the decode's rounded aspect
            fillMode: Image.Stretch
            sourceSize: Qt.size(root.imageWidth, 0)
            asynchronous: root.asynchronous
            cache: root.cacheImage
            source: root.source

            onStatusChanged: d.scheduleRetry(status)
            Component.onDestruction: source = ""
        }
    }

    Component {
        id: animatedImageComponent

        RoundedAnimatedImage {
            width: Math.min(implicitWidth, root.imageWidth)
            height: implicitWidth > 0 ? Math.round(width * implicitHeight / implicitWidth) : 0

            radius: 16
            bottomLeftRadius: d.bottomLeftRadius
            bottomRightRadius: d.bottomRightRadius

            playing: root.playing
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(d.decodeWidth, d.decodeWidth)
            asynchronous: root.asynchronous
            cache: root.cacheImage
            source: root.source

            onStatusChanged: d.scheduleRetry(status)
            Component.onDestruction: source = ""
        }
    }

    Loader {
        id: loadingImageLoader
        active: d.imageStatus === Image.Loading || d.imageStatus === Image.Error
        visible: active
        width: active ? 300 : 0
        height: width

        sourceComponent: Rectangle {
            anchors.fill: parent
            border.width: 1
            border.color: Theme.palette.border
            radius: Theme.radius

            StyledText {
                anchors.centerIn: parent
                text: d.imageStatus === Image.Error?
                        qsTr("Error loading the image") :
                        qsTr("Loading image...")
                color: d.imageStatus === Image.Error?
                        Theme.palette.dangerColor1 :
                        Theme.palette.textColor
                font.pixelSize: Theme.primaryTextFontSize
            }
        }
    }
}
