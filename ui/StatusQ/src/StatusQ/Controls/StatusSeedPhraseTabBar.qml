pragma ComponentBehavior: Bound

import StatusQ.Controls

StatusSwitchTabBar {
    id: root

    padding: 0

    readonly property var lengths: [12, 18, 24]
    readonly property int selectedLength: {
        if (v12.checked)
            return 12
        if (v18.checked)
            return 18
        return 24
    }

    function selectLength(length: int) {
        if (length === 12)
            v12.checked = true
        else if(length === 18)
            v18.checked = true
        else
            v24.checked = true
    }

    StatusSwitchTabButton {
        id: v12

        verticalPadding: 0
        text: qsTr("12 word")
        objectName: "12SeedButton"
    }

    StatusSwitchTabButton {
        id: v18

        verticalPadding: 0
        text: qsTr("18 word")
        objectName: "18SeedButton"
    }

    StatusSwitchTabButton {
        id: v24

        verticalPadding: 0
        text: qsTr("24 word")
        objectName: "24SeedButton"
    }
}
