pragma ComponentBehavior: Bound

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

StatusListItem {
    id: statusContactRequestsListItem

    implicitHeight: 64
    implicitWidth: 288

    color: sensor.containsMouse ? Theme.palette.baseColor2 : "transparent"

    property int requestsCount: 0

    components: [
        StatusBadge {
            visible:  statusContactRequestsListItem.requestsCount > 0
            value: statusContactRequestsListItem.requestsCount
            anchors.verticalCenter: parent.verticalCenter
            border.width: 4
            border.color: color
        },
        StatusIcon {
            icon: "next"
            color: Theme.palette.baseColor1
        }
    ]
}
