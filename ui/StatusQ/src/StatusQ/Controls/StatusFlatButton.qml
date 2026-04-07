pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

StatusBaseButton {
    normalColor: "transparent"

    hoverColor: {
        switch(type) {
        case StatusBaseButton.Type.Primary:
            return Theme.palette.primaryColor2
        case StatusBaseButton.Type.Warning:
            return Theme.palette.warningColor3
        case StatusBaseButton.Type.Danger:
            return Theme.palette.dangerColor3
        case StatusBaseButton.Type.Success:
            return Theme.palette.successColor2
        default:
            return Theme.palette.primaryColor3
        }
    }

    disabledColor: "transparent"

    textColor: {
        switch(type) {
        case StatusBaseButton.Type.Primary:
            return Theme.palette.primaryColor1
        case StatusBaseButton.Type.Warning:
            return Theme.palette.warningColor1
        case StatusBaseButton.Type.Danger:
            return Theme.palette.dangerColor1
        case StatusBaseButton.Type.Success:
            return Theme.palette.successColor1
        default:
            return Theme.palette.primaryColor1
        }
    }

    disabledTextColor: Theme.palette.baseColor1

    borderColor: (type === StatusBaseButton.Type.Normal || hovered) && !loading && interactive ? "transparent"
                                                                                               : Theme.palette.baseColor2
}
