import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import utils

StatusListItem {
    id: root

    property ButtonGroup buttonGroup
    property alias checked: radioButton.checked
    readonly property alias radioButton: radioButton

    implicitHeight: 44
    leftPadding: 8
    rightPadding: 9
    statusListItemTitle.font.pixelSize: Theme.additionalTextSize

    statusListItemTitleArea.anchors.leftMargin: 8

    asset.bgWidth: 32
    asset.bgHeight: 32

    Binding on asset.color {
        when: !root.enabled
        value: root.Theme.palette.darkGrey
    }

    components: [
        StatusRadioButton {
            id: radioButton

            visible: root.enabled

            // reference to root for better integration with ButtonGroup
            // by accessing main component via ButtonGroup::checkedButton.item
            readonly property alias item: root

            size: StatusRadioButton.Size.Small
            ButtonGroup.group: root.buttonGroup

            rightPadding: 0
        }
    ]

    // using StatusMouseArea instead of build-in 'clicked' signal to avoid
    // intercepting event by the StatusRadioButton
    StatusMouseArea {
        anchors.fill: parent
        onClicked: {
            if (!radioButton.checked)
                radioButton.toggle()
        }
        cursorShape: Qt.PointingHandCursor
    }
}
