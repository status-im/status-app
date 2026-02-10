import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

Action {
    Theme.style: parent?.Theme.style ?? Theme.Style.Light

    id: root

    enum Type {
        Normal,
        Danger,
        Success
    }

    property int type: StatusAction.Type.Normal
    property bool visibleOnDisabled: false

    property StatusAssetSettings assetSettings: StatusAssetSettings {
        width: 18
        height: 18
        rotation: 0
        isLetterIdenticon: false
        imgIsIdenticon: false
        color: root.icon.color
        name: root.icon.name
        hoverColor: root.Theme.palette.statusMenu.hoverBackgroundColor
    }

    property StatusFontSettings fontSettings: StatusFontSettings {}

    icon.color: {
        if (!root.enabled)
            return root.Theme.palette.baseColor1
        if (type === StatusAction.Type.Danger)
            return root.Theme.palette.dangerColor1
        if (type === StatusAction.Type.Success)
            return root.Theme.palette.successColor1
        return root.Theme.palette.primaryColor1
    }
}
