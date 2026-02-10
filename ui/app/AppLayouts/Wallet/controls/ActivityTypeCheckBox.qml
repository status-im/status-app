import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

StatusListItem {
    id: root

    property bool checked: true
    property bool allChecked : false
    property int type
    property ButtonGroup buttonGroup
    property StatusAssetSettings assetSettings: StatusAssetSettings {
        width: 24
        height: 24
        bgWidth: 0
        bgHeight: 0
        bgRadius: 0
        bgColor: root.Theme.palette.primaryColor3
        color: root.Theme.palette.primaryColor1
    }

    signal actionTriggered()

    height: 44
    radius: 0
    leftPadding: 21
    rightPadding: 21
    asset: root.assetSettings
    statusListItemTitle.font.pixelSize: Theme.additionalTextSize
    components: [
        StatusCheckBox {
            id: checkBox
            visible: !root.loading
            tristate: true
            checkable: true
            spacing: 0
            leftPadding: 0
            rightPadding: 0
            checkState: root.allChecked ? Qt.PartiallyChecked : root.checked ? Qt.Checked : Qt.Unchecked
            nextCheckState: () => {
                                root.actionTriggered()
                                return checkState
                            }
            ButtonGroup.group: buttonGroup
        }
    ]
    onClicked: checkBox.nextCheckState()
}
