import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects

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
    // Only the needed kind is built: stills decode at a bounded size (a chat
    // can hold dozens of photos and a full decode of each exhausts memory);
    // gifs need AnimatedImage, which cannot bound its decode.
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
            root.imageAlias.reloadImage()
        }
    }

    QtObject {
        id: d

        readonly property int imageStatus: root.imageAlias ? root.imageAlias.status : Image.Loading

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
                root.imageAlias.reloadImage()
                interval *= 2
                restart()
            }
        }
    }

    Item {
        id: imageBox

        width: root.imageAlias ? root.imageAlias.width : 0
        height: root.imageAlias ? root.imageAlias.paintedHeight : 0

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Item {
                width: imageBox.width
                height: imageBox.height

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: imageBox.width
                    height: imageBox.height
                    radius: 16
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: 32
                    height: 32
                    radius: 4
                    visible: root.leftTail && !allCornersRounded
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 32
                    height: 32
                    radius: 4
                    visible: !root.leftTail && !allCornersRounded
                }
            }
        }

        Loader {
            id: imageLoader
            asynchronous: root.asynchronous
            sourceComponent: root.isAnimated ? animatedComponent : stillComponent
        }

        StatusMouseArea {
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            anchors.fill: parent
            onClicked: (mouse) => root.clicked(root.imageAlias, mouse)
        }
    }

    Component {
        id: stillComponent

        Image {
            id: imageMessage
            width: Math.min(implicitWidth, root.imageWidth)
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Math.ceil(root.imageWidth * Screen.devicePixelRatio)
            asynchronous: true
            mipmap: true
            cache: root.cacheImage
            source: root.source

            onStatusChanged: d.scheduleRetry(status)

            function reloadImage() {
                imageMessage.source = ""
                imageMessage.source = Qt.binding(() => root.source)
            }

            Component.onDestruction: imageMessage.source = ""
        }
    }

    Component {
        id: animatedComponent

        AnimatedImage {
            id: imageMessage
            width: Math.min(implicitWidth, root.imageWidth)
            fillMode: Image.PreserveAspectFit
            source: root.source
            playing: root.playing
            mipmap: true
            cache: root.cacheImage

            onStatusChanged: d.scheduleRetry(status)

            function reloadImage() {
                imageMessage.source = ""
                imageMessage.source = Qt.binding(() => root.source)
            }

            Component.onDestruction: imageMessage.source = ""
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
