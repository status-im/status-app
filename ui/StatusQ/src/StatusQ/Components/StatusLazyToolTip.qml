import QtQuick

import StatusQ.Controls

// A StatusToolTip built on the first hover of `hoverTarget` instead of with its owner.
// Components created in bulk (message rows) would otherwise each pay for a tooltip
// nobody may ever see; `textProvider` is pulled when the tooltip shows, keeping the
// text formatting out of creation too.
Loader {
    id: root

    // Hover source; the tooltip is parented to it for positioning
    required property Item hoverTarget

    // Called on hover, returns the tooltip text
    required property var textProvider

    property bool hoverEnabled: true
    property int maxWidth: 800 // StatusToolTip's default

    // Assigned to the created tooltip; callers and tests look it up by name
    property string tooltipObjectName

    active: false

    HoverHandler {
        id: hoverHandler
        parent: root.hoverTarget
        enabled: root.hoverEnabled

        onHoveredChanged: {
            if (!hovered)
                return
            root.active = true
            root.item.text = root.textProvider()
        }
    }

    sourceComponent: StatusToolTip {
        objectName: root.tooltipObjectName
        parent: root.hoverTarget
        maxWidth: root.maxWidth
        visible: hoverHandler.hovered && !!text
    }
}
