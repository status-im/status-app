import QtQuick
import QtQml

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

StatusBaseText {
    id: root
    objectName: "messageTimestamp"
    property double timestamp: 0
    property bool showFullTimestamp

    color: Theme.palette.baseColor1
    font.pixelSize: Theme.tertiaryTextFontSize
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

    // The tooltip only matters on desktop hover; created on demand so message
    // rows don't pay for it (never on touch devices).
    StatusLazyToolTip {
        hoverTarget: root
        hoverEnabled: !root.showFullTimestamp
        maxWidth: 350
        tooltipObjectName: "timestampTooltip"
        textProvider: () => root.timestamp ? LocaleUtils.formatDateTime(root.timestamp) : ""
    }
}
