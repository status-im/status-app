import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

/**
  * The share picker's tab switcher: All (text) + Contacts / Groups /
  * Communities (icons). One highlight pill slides under the tabs; the host
  * binds `position` to the swipe progress so the pill moves with the pages.
  */
Control {
    id: root

    enum Tab { All, Contacts, Groups, Communities }

    property int currentIndex: 0
    property real position: root.currentIndex

    padding: Theme.halfPadding / 2

    background: Rectangle {
        color: Theme.palette.statusSwitchTab.barBackgroundColor
        radius: Theme.radius
    }

    contentItem: Item {
        id: track

        implicitHeight: 32

        readonly property real tabWidth: (width - Theme.halfPadding / 2 * 3) / 4
        readonly property real tabStride: tabWidth + Theme.halfPadding / 2

        Rectangle {
            objectName: "shareTabPill"
            width: track.tabWidth
            height: 32
            radius: Theme.radius
            color: Theme.palette.statusSwitchTab.buttonBackgroundColor
            x: Math.max(0, Math.min(3, root.position)) * track.tabStride
        }

        component TabItem: TabButton {
            id: tab

            required property int index
            property string iconName

            x: index * track.tabStride
            width: track.tabWidth
            height: 32
            padding: 0
            checkable: false
            checked: root.currentIndex === index
            onClicked: root.currentIndex = index

            background: null
            contentItem: Item {
                StatusBaseText {
                    anchors.centerIn: parent
                    visible: tab.iconName === ""
                    text: tab.text
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                    color: tab.checked ? Theme.palette.statusSwitchTab.selectedTextColor
                                       : Theme.palette.statusSwitchTab.textColor
                }
                StatusIcon {
                    anchors.centerIn: parent
                    visible: tab.iconName !== ""
                    width: 24
                    height: 24
                    icon: tab.iconName
                    color: tab.checked ? Theme.palette.statusSwitchTab.selectedTextColor
                                       : Theme.palette.statusSwitchTab.textColor
                }
            }
        }

        TabItem { objectName: "shareTabAll"; index: 0; text: qsTr("All") }
        TabItem { objectName: "shareTabContacts"; index: 1; iconName: "contact" }
        TabItem { objectName: "shareTabGroups"; index: 2; iconName: "group-chat" }
        TabItem { objectName: "shareTabCommunities"; index: 3; iconName: "communities" }
    }
}
