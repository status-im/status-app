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

    signal infoButtonClicked
    signal shareOwnProfileRequested

    padding: Theme.halfPadding
    rightPadding: Theme.padding
    topPadding: Theme.smallPadding

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

        StatusIconTabButton {
            objectName: "shareProfileButton"
            icon.name: "add-contact"
            icon.color: Theme.palette.directColor1
            checkable: false
            onClicked: root.shareOwnProfileRequested()

            StatusToolTip {
                text: qsTr("Invite contacts")
                visible: parent.hovered
                orientation: StatusToolTip.Orientation.Bottom
                y: parent.height + Theme.padding
            }
        }
    }
}
