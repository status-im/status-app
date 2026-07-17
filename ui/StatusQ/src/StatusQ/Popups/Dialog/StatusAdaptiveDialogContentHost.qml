import QtQuick
import QtQuick.Controls

import StatusQ.Controls

// Hosts the dialog content component and applies the scroll rules from the dialog spec.
// Consumers provide the body only; the base dialog sets this control's paddings/insets.
// The host owns the single visible scrollbar and configures scroll behavior, whether
// the loaded body is regular content or resolves to a Flickable/ListView viewport.
Control {
    id: root

    required property Component contentComponent
    property real flickableTopPadding: 0
    property real flickableBottomPadding: 0

    // Natural height requested by the loaded content before the dialog applies its max-height cap.
    readonly property real naturalHeight: d.loadedContentNaturalHeight

    objectName: "statusAdaptiveDialogContentHost"
    clip: true
    padding: 0

    QtObject {
        id: d

        readonly property var loadedContentItem: contentLoader.item
        readonly property var contentFlickable: resolveFlickable(loadedContentItem)
        readonly property bool contentIsFlickable: !!contentFlickable
        readonly property var activeFlickable: contentIsFlickable ? contentFlickable : scrollFlickable
        readonly property var contentVerticalScrollBar: loadedContentItem
                                                        && loadedContentItem.statusAdaptiveDialogContentVerticalScrollBar
                                                        ? loadedContentItem.statusAdaptiveDialogContentVerticalScrollBar
                                                        : null
        readonly property real loadedContentImplicitHeight: loadedContentItem ? loadedContentItem["implicitHeight"] ?? 0 : 0
        readonly property real loadedContentHeight: contentFlickable ? contentFlickable.contentHeight : 0
        readonly property real loadedContentNaturalHeight: loadedContentItem ? Math.max(loadedContentImplicitHeight, contentIsFlickable ? loadedContentHeight : 0) : 0
        readonly property real activeContentExtent: activeFlickable ? activeFlickable.contentHeight
                                                                      + activeFlickable.topMargin
                                                                      + activeFlickable.bottomMargin : 0
        readonly property bool contentOverflows: activeFlickable ? activeContentExtent > activeFlickable.height : false

        function resolveFlickable(item) {
            if (!item)
                return null;

            if (item instanceof Flickable)
                return item;

            if (item.contentItem instanceof Flickable)
                return item.contentItem;

            return null;
        }
    }

    contentItem: Item {
        id: contentViewport

        objectName: "statusAdaptiveDialogContentViewport"
        clip: true

        Flickable {
            id: scrollFlickable

            objectName: "statusAdaptiveDialogScrollFlickable"
            anchors.fill: parent
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentWidth: width
            contentHeight: d.contentIsFlickable ? 0 : d.loadedContentNaturalHeight
            topMargin: root.flickableTopPadding
            bottomMargin: root.flickableBottomPadding
            flickableDirection: Flickable.VerticalFlick
            visible: !!d.loadedContentItem && !d.contentIsFlickable
            enabled: visible
            interactive: visible && d.contentOverflows
        }

        Loader {
            id: contentLoader

            active: !!root.contentComponent
            sourceComponent: root.contentComponent
            visible: false

            onLoaded: {
                item.x = 0;
                item.y = 0;

                if (d.contentIsFlickable) {
                    const flickable = d.contentFlickable;

                    item.parent = contentViewport;
                    item.width = Qt.binding(() => contentViewport.width);
                    item.height = Qt.binding(() => contentViewport.height);
                    flickable.boundsBehavior = Flickable.StopAtBounds;
                    flickable.flickableDirection = Flickable.VerticalFlick;
                    flickable.contentWidth = Qt.binding(() => contentViewport.width);
                    flickable.topMargin = Qt.binding(() => root.flickableTopPadding);
                    flickable.bottomMargin = Qt.binding(() => root.flickableBottomPadding);
                    flickable.interactive = Qt.binding(() => d.contentOverflows);
                    if (d.contentVerticalScrollBar)
                        d.contentVerticalScrollBar.policy = ScrollBar.AlwaysOff;
                } else {
                    item.parent = scrollFlickable.contentItem;
                    item.width = Qt.binding(() => scrollFlickable.width);
                    item.height = Qt.binding(() => Math.max(d.loadedContentImplicitHeight,
                                                            scrollFlickable.height
                                                            - root.flickableTopPadding
                                                            - root.flickableBottomPadding));
                }
            }
        }
    }

    StatusScrollBar {
        objectName: "statusAdaptiveDialogContentScrollBar"

        width: Math.max(root.rightPadding / 2, 8)
        anchors.top: contentViewport.top
        anchors.bottom: contentViewport.bottom
        anchors.right: root.right
        anchors.rightMargin: Math.max(0, (root.rightPadding - width) / 2)
        orientation: Qt.Vertical
        policy: ScrollBar.AsNeeded
        position: d.activeFlickable ? d.activeFlickable.visibleArea.yPosition : 0
        size: d.activeFlickable ? d.activeFlickable.visibleArea.heightRatio : 1
        active: d.activeFlickable && d.activeFlickable.moving
        visible: d.activeFlickable && resolveVisibility(policy, d.activeFlickable.height, d.activeContentExtent)

        onPositionChanged: {
            if (pressed && d.activeFlickable)
                d.activeFlickable.contentY = -d.activeFlickable.topMargin
                                             + position * Math.max(0, d.activeContentExtent - d.activeFlickable.height);
        }
    }
}
