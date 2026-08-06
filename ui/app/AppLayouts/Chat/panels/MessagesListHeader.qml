import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

// The Messages list headline row: title + invite / start-chat / search buttons.
// Used by ContactsColumnView and, in disabled form, by the section loading
// skeleton so the real header shows while the section incubates.
RowLayout {
    id: root

    property bool createChatOpened: false
    property alias searchChecked: searchBtn.checked
    property bool searchVisible: true
    // Search only acts on the loaded chat list; while the section loads,
    // its slot shows a loading tile instead of the button
    property bool searchLoading: false

    signal shareOwnProfileRequested()
    signal startChatClicked()

    component HeaderButton: StatusFlatButton {
        icon.color: hovered || checked ? Theme.palette.primaryColor1 : Theme.palette.directColor1
        isRoundIcon: true
        tooltip.orientation: StatusToolTip.Orientation.Bottom
        tooltip.y: parent.height + Theme.padding
    }

    StatusNavigationPanelHeadline {
        objectName: "ContactsColumnView_MessagesHeadline"
        text: qsTr("Messages")
    }

    Item {
        Layout.fillWidth: true
    }

    HeaderButton {
        objectName: "shareProfileButton"
        icon.name: "add-contact"
        tooltip.text: qsTr("Invite contacts")
        onClicked: root.shareOwnProfileRequested()
    }

    HeaderButton {
        objectName: "startChatButton"
        icon.name: "chat-commands"
        checkable: true
        checked: root.createChatOpened
        tooltip.text: qsTr("Start chat")
        onClicked: root.startChatClicked()
    }

    HeaderButton {
        id: searchBtn
        objectName: "searchButton"
        icon.name: "search"
        tooltip.text: qsTr("Search")
        checkable: true
        visible: root.searchVisible && !root.searchLoading
    }

    LoadingSkeletonGroup {
        visible: root.searchLoading
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32

        LoadingSkeletonTile {
            anchors.fill: parent
            radius: width / 2
        }
    }
}
