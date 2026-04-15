import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

Control {
    id: root

    property string name
    property int membersCount
    property url image
    property color color
    property bool amISectionAdmin
    property bool searchActive

    signal infoButtonClicked
    signal shareOwnProfileRequested
    signal searchRequested(bool toggled)

    padding: Theme.halfPadding
    rightPadding: Theme.padding
    topPadding: Theme.smallPadding

    component HeaderButton: StatusFlatButton {
        icon.color: hovered || checked ? Theme.palette.primaryColor1 : Theme.palette.directColor1
        isRoundIcon: true
        tooltip.orientation: StatusToolTip.Orientation.Bottom
        tooltip.y: parent.height + Theme.padding
    }

    contentItem: RowLayout {
        StatusChatInfoButton {
            objectName: "communityHeaderButton"
            Layout.fillWidth: true
            title: root.name
            subTitle: qsTr("%n member(s)", "", root.membersCount)
            asset.name: root.image
            asset.color: root.color
            asset.isImage: true
            type: StatusChatInfoButton.Type.OneToOneChat
            hoverEnabled: root.amISectionAdmin
            onClicked: if(root.amISectionAdmin) root.infoButtonClicked()
        }

        HeaderButton {
            objectName: "shareProfileButton"
            icon.name: "add-contact"
            onClicked: root.shareOwnProfileRequested()
            tooltip.text: qsTr("Invite contacts")
        }

        HeaderButton {
            objectName: "searchButton"
            icon.name: "search"
            checkable: true
            checked: root.searchActive
            onToggled: root.searchRequested(checked)
            tooltip.text: qsTr("Search")
        }
    }
}
