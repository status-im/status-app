import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import utils
import shared.popups

Popup {
    id: root

    // --- PUBLIC PROPERTIES ---
    property var image
    property url url

    property real minScale: 1.0
    property real maxScale: 10.0

    // --- POPUP CONFIGURATION ---
    modal: true
    background: null
    focus: visible

    margins: Theme.bigPadding

    leftPadding: root.parent?.SafeArea.margins.left ?? 0
    rightPadding: root.parent?.SafeArea.margins.right ?? 0
    topPadding: root.parent?.SafeArea.margins.top ?? 0
    bottomPadding: root.parent?.SafeArea.margins.bottom ?? 0

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent ? parent.width - (root.margins * 2) : Screen.width - (root.margins * 2)
    onWidthChanged: Qt.callLater(() => reset())
    height: parent ? parent.height - (root.margins * 2) : Screen.height - (root.margins * 2)
    onHeightChanged: Qt.callLater(() => reset())

    Overlay.modal: Rectangle {
        color: Theme.palette.backdropColor
    }

    function reset(scale = 1) {
        d.scaleAroundPoint(scale, Qt.point(root.availableWidth/2, root.availableHeight/2))
    }

    readonly property alias iscale: d.iscale
    readonly property alias fitSize: d.fitSize

    QtObject {
        id: d

        property real iscale: 1
        readonly property real minRelativeScale: fitScale > 0 ? Math.min(1, root.minScale / fitScale) : 1
        readonly property real maxRelativeScale: fitScale > 0 ? Math.max(1, root.maxScale / fitScale) : 1
        readonly property real fitScale: {
            const ss = imageItem.sourceSize
            if (!ss.width || !ss.height)
                return 1

            return Math.min(root.availableWidth / ss.width,
                            root.availableHeight / ss.height,
                            1)
        }
        readonly property size fitSize: {
            const ss = imageItem.sourceSize
            return Qt.size(ss.width * d.fitScale, ss.height * d.fitScale)
        }

        function scaleAroundPoint(factor, point) {
            factor = Math.max(d.minRelativeScale, Math.min(d.maxRelativeScale, factor)) // clamp within [minScale,maxScale] relative to the natural image size
            d.iscale = factor
            flickable.resizeContent(d.fitSize.width * d.iscale, d.fitSize.height * d.iscale, point)
            flickable.returnToBounds()
        }

        property var ctxMenu: null
        function openContextMenu(pos) {
            d.ctxMenu?.close() // will run destruction/cleanup
            d.ctxMenu = imageContextMenu.createObject(imageItem)
            d.ctxMenu.popup(pos)
        }
    }

    Flickable {
        id: flickable

        anchors.fill: parent
        clip: true
        enabled: imageItem.valid
        visible: enabled

        leftMargin: Math.max(0, width - contentWidth) / 2 // Centering the content
        topMargin: Math.max(0, height - contentHeight) / 2

        contentWidth: d.fitSize.width
        contentHeight: d.fitSize.height

        rebound: Transition {}
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.horizontal: CustomScrollBar {}
        ScrollBar.vertical: CustomScrollBar {}

        StatusAnimatedImage {
            id: imageItem

            readonly property bool valid: status === AnimatedImage.Ready && !isEmpty

            width: flickable.contentWidth
            height: flickable.contentHeight
            asynchronous: true
            cache: false
            autoTransform: true
            source: root.image?.source ?? root.url
            onSourceChanged: root.reset()
            onValidChanged: {
                playing = valid
                root.reset()
            }

            // handling RMB for context menu
            ContextMenu.onRequested: pos => d.openContextMenu(pos)

            TapHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.TouchScreen
                onDoubleTapped: function(eventPoint, button) {
                    eventPoint.accepted = true
                    root.reset()
                }
            }
        }

        // zoom handler for touch
        PinchHandler {
            id: pinchHandler
            rotationAxis.enabled: false
            target: null
            scaleAxis {
                enabled: true
                onActiveValueChanged: function(delta) {
                    d.ctxMenu?.close()
                    const targetScale = d.iscale * delta
                    d.scaleAroundPoint(targetScale, centroid.position)
                }
            }
        }

        // zoom handler for mouse wheel and touchpad
        WheelHandler {
            id: wheelHandler
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(e) {
                d.ctxMenu?.close()
                const targetScale = d.iscale + (e.angleDelta.y / 120.0)
                d.scaleAroundPoint(targetScale, Qt.point(e.x, e.y))
            }
        }

        // handling touch longpress for context menu
        TapHandler {
            acceptedDevices: PointerDevice.TouchScreen
            onLongPressed: d.openContextMenu(point.position)
        }

        HoverHandler {
            cursorShape: {
                if (wheelHandler.active || pinchHandler.active)
                    return Qt.SizeAllCursor
                if (flickable.moving)
                    return Qt.ClosedHandCursor
                if (d.iscale !== 1)
                    return Qt.OpenHandCursor
            }
        }
    }

    Item {
        anchors.fill: flickable
        visible: flickable.visible

        BackgroundTapZone {
            x: 0
            y: 0
            width: parent.width
            height: flickable.topMargin
        }

        BackgroundTapZone {
            x: 0
            y: parent.height - flickable.topMargin
            width: parent.width
            height: flickable.topMargin
        }

        BackgroundTapZone {
            x: 0
            y: flickable.topMargin
            width: flickable.leftMargin
            height: parent.height - (2 * flickable.topMargin)
        }

        BackgroundTapZone {
            x: parent.width - flickable.leftMargin
            y: flickable.topMargin
            width: flickable.leftMargin
            height: parent.height - (2 * flickable.topMargin)
        }
    }

    Loader {
        anchors.centerIn: parent
        width: Math.min(root.availableWidth, 300)
        height: Math.min(root.availableHeight, 300)
        active: imageItem.isError || imageItem.isEmpty
        sourceComponent: LoadingErrorComponent {
            radius: Theme.radius
            text: qsTr("Failed to load %1").arg(root.url.toString() || qsTr("empty image"))
        }
    }

    Loader {
        anchors.fill: parent
        active: imageItem.isLoading
        sourceComponent: LoadingComponent {
            radius: Theme.radius
        }
    }

    StatusButton {
        anchors.top: parent.top
        anchors.right: parent.right
        type: StatusBaseButton.Type.Primary
        icon.name: "close"
        tooltip.text: qsTr("Close")
        tooltip.orientation: StatusToolTip.Orientation.Bottom
        onClicked: root.close()
    }

    Component {
        id: imageContextMenu

        ImageContextMenu {
            isVideo: false
            imageSource: imageItem.source
            url: root.url
            isGif: imageItem.playing
            onClosed: {
                d.ctxMenu = null
                destroy()
            }
        }
    }

    component CustomScrollBar: StatusScrollBar {
        active: (horizontal ? flickable.movingHorizontally : flickable.movingVertically) || pinchHandler.active || wheelHandler.active
        implicitWidth: Theme.defaultHalfPadding
        implicitHeight: Theme.defaultHalfPadding
    }

    component BackgroundTapZone: Item {
        visible: width > 0 && height > 0

        TapHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.TouchScreen
            onTapped: function(eventPoint, button) {
                eventPoint.accepted = true
                root.close()
            }
        }
    }

    Component.onCompleted: {
        // workaround for QTBUG-142248
        contentItem.Theme.style = Qt.binding(() => root.Theme.style)
        contentItem.Theme.padding = Qt.binding(() => root.Theme.padding)
        contentItem.Theme.fontSizeOffset = Qt.binding(() => root.Theme.fontSizeOffset)
    }
}
