pragma ComponentBehavior: Bound

import QtQuick

import StatusQ

// Convenience text renderer. Chat messages compose the optional support
// directly, keeping their original ChatTextItem instance.
ChatTextItem {
    id: root

    property list<chatTextSegment> sourceSegments
    property var links: ({})

    segments: support.item ? support.item.segments : root.sourceSegments

    Loader {
        id: support
        active: Object.keys(root.links).length > 0
        sourceComponent: StatusInlineLinkSupport {
            textItem: root
            sourceSegments: root.sourceSegments
            links: root.links
        }
    }
}
