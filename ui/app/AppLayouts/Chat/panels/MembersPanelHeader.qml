import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

// The members panel title row — shared between UserListPanel and
// MembersListSkeleton so the loading state renders identically.
Control {
    id: root

    objectName: "membersPanelHeader"

    property alias label: titleText.text
    property alias searchEnabled: searchBtn.enabled
    property alias searchChecked: searchBtn.checked

    padding: 0

    contentItem: RowLayout {
        StatusBaseText {
            id: titleText
            objectName: "membersPanelTitle"
            Layout.fillWidth: true

            opacity: (root.width > 58) ? 1.0 : 0.0
            visible: (opacity > 0.1)
            font.weight: Font.Medium
            wrapMode: Text.Wrap
        }

        StatusFlatButton {
            id: searchBtn
            objectName: "membersSearchButton"
            icon.name: "search"
            isRoundIcon: true
            checkable: true
            textColor: checked || hovered ? Theme.palette.primaryColor1 : Theme.palette.directColor1
            tooltip.text: qsTr("Search")
            tooltip.orientation: StatusToolTip.Orientation.Bottom
        }
    }
}
