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

    // The clock dependency of the relative label, named so it can be asserted on:
    // formatRelativeTimestamp is day-granular ("Today 14:23"), so it may only be
    // re-evaluated when the local day changes. Bound to the shared timer's
    // per-second counter instead, it re-formats every visible row once a second
    // forever, for a value that cannot move. Binding re-evaluation is invisible
    // from QML, so this property is what a test can hold on to.
    readonly property int clockTick: StatusSharedUpdateTimer.daysActive

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
                root.clockTick
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
