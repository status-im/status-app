import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Controls

// Hosts the dialog content component and applies the scroll rules from the dialog spec.
//
// Strategy A — content IS a Flickable (ListView, GridView, …):
//   The item is placed directly in the viewport and given the full content area
//   size. This host owns the visible ScrollBar; the content item must disable any
//   built-in scrollbar it carries (e.g. StatusListView.ScrollBar.vertical: null)
//   to avoid showing two overlapping bars.
//
// Strategy B — content is NOT a Flickable (ColumnLayout, Item, …):
//   The content is placed inside an internal Flickable managed by this host.
//   Scrolling activates automatically when the content's implicit height exceeds
//   the available area.
Item {
    id: root

    required property Component contentComponent

    // Space around the content component. The vertical scrollbar is placed in the right margin.
    property real contentMargin: 0
    // Vertical space above the content component. Defaults to contentMargin.
    property real contentTopMargin: contentMargin
    // Vertical space below the content component. Defaults to contentMargin and may include bottom safe area.
    property real contentBottomMargin: contentMargin

    // Natural height requested by the loaded content before the dialog applies its max-height cap.
    readonly property real naturalHeight: d.loadedContentNaturalHeight

    objectName: "statusAdaptiveDialogContentHost"
    clip: true

    QtObject {
        id: d

        readonly property var loadedContentItem: contentLoader.item
        readonly property bool contentIsFlickable: loadedContentItem instanceof Flickable
        readonly property real loadedContentNaturalHeight: loadedContentItem
                                                           ? Math.max(loadedContentItem.implicitHeight,
                                                                      contentIsFlickable ? loadedContentItem.contentHeight : 0)
                                                           : 0
        readonly property bool contentOverflows: loadedContentNaturalHeight > contentArea.height
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
                item.parent = contentArea;
                item.width = Qt.binding(() => contentArea.width);
                item.height = Qt.binding(() => contentArea.height);
                item.boundsBehavior = Flickable.StopAtBounds;
                item.flickableDirection = Flickable.VerticalFlick;
                item.contentWidth = Qt.binding(() => contentArea.width);
            } else {
                item.parent = scrollFlickable.contentItem;
                item.width = Qt.binding(() => scrollFlickable.width);
                item.height = Qt.binding(() => Math.max(item.implicitHeight, scrollFlickable.height));
            }
        }
    }

    Item {
        id: contentArea

        objectName: "statusAdaptiveDialogContentViewport"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.contentMargin
        anchors.rightMargin: root.contentMargin
        anchors.topMargin: root.contentTopMargin
        anchors.bottomMargin: root.contentBottomMargin
        clip: true
    }

    Flickable {
        id: scrollFlickable

        objectName: "statusAdaptiveDialogScrollFlickable"
        anchors.fill: contentArea
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentWidth: width
        contentHeight: d.contentIsFlickable ? 0 : d.loadedContentNaturalHeight
        flickableDirection: Flickable.VerticalFlick
        visible: !!d.loadedContentItem && !d.contentIsFlickable
        enabled: visible
        interactive: visible && d.contentOverflows
    }

    StatusScrollBar {
        id: contentScrollBar

        objectName: "statusAdaptiveDialogContentScrollBar"

        readonly property var flickable: d.contentIsFlickable && contentLoader.item instanceof Flickable ? contentLoader.item : scrollFlickable

        width: Math.max(root.Theme.halfPadding, 8)
        anchors.top: contentArea.top
        anchors.right: parent.right
        anchors.rightMargin: Math.max(0, (root.contentMargin - width) / 2)
        anchors.bottom: contentArea.bottom
        orientation: Qt.Vertical
        policy: ScrollBar.AsNeeded
        position: flickable ? flickable.visibleArea.yPosition : 0
        size: flickable ? flickable.visibleArea.heightRatio : 1
        active: flickable && flickable.moving
        visible: flickable && flickable.visible && resolveVisibility(policy, flickable.height, flickable.contentHeight)

        onPositionChanged: {
            if (pressed && flickable)
                flickable.contentY = position * Math.max(0, flickable.contentHeight - flickable.height);
        }
    }
}
