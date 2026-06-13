import QtQuick
import QtQml

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

StatusBaseText {
    id: root
    objectName: "messageTimestamp"
    property double timestamp: 0
    property bool showFullTimestamp

    color: Theme.palette.baseColor1
    font.pixelSize: Theme.asideTextFontSize
    visible: !!text
    text: d.formattedLabel
    Accessible.role: Accessible.StaticText
    Accessible.name: d.formattedLabel

    QtObject {
        id: d
        // initial value
        property string formattedLabel: root.showFullTimestamp ? LocaleUtils.formatDateTime(root.timestamp) : LocaleUtils.formatRelativeTimestamp(root.timestamp)

        // updates
        Binding on formattedLabel {
            when: !root.showFullTimestamp && root.timestamp && root.visible
            value: {
                StatusSharedUpdateTimer.secondsActive
                return LocaleUtils.formatRelativeTimestamp(root.timestamp)
            }
            restoreMode: Binding.RestoreBinding
        }
    }

    StatusToolTip {
        id: tooltip
        visible: hhandler.hovered && !!text
        maxWidth: 350
    }
    HoverHandler {
        id: hhandler
        enabled: !root.showFullTimestamp
        onHoveredChanged: {
            if(hhandler.hovered && root.timestamp) {
                tooltip.text = LocaleUtils.formatDateTime(root.timestamp)
            }
        }
    }
}
