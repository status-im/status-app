import QtQml
import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

import utils

StatusListItem {
    id: root

    property string chainName
    property string iconUrl
    property bool isActive
    property bool isDeactivatable
    property bool showNewIcon: false

    signal setNetworkActive(bool active)
    signal editNetwork()

    statusListItemTitleIcons.active: root.showNewIcon
    statusListItemTitleIcons.anchors.leftMargin: Theme.smallPadding
    statusListItemTitleIcons.sourceComponent: StatusNewTag {
        objectName: "walletNetworkNewIcon_" + root.chainName
        tooltipText: qsTr("%1 chain integrated. You can now view and swap <br>%1 assets, as well as interact with %1 dApps.").arg(root.chainName)
    }

    QtObject {
        id: d

        function toggleActive() {
            if (root.isDeactivatable) {
                root.setNetworkActive(!root.isActive)
            }
        }
    }

    onClicked: d.toggleActive()

    title: chainName
    asset.name: Assets.svg(iconUrl)
    asset.isImage: true
    width: parent.width
    leftPadding: Theme.padding
    rightPadding: Theme.padding
    components: [
        RowLayout {
            spacing: 16
            Item {
                implicitWidth: isActiveSwitch.width
                implicitHeight: isActiveSwitch.height

                StatusSwitch {
                    id: isActiveSwitch
                    objectName: "isActiveSwitch_" + chainName
                    enabled: !root.isActive || root.isDeactivatable
                    checked: root.isActive
                    onToggled:{
                        checked = Qt.binding(() => root.isActive)
                        d.toggleActive()
                    }
                }

                StatusMouseArea {
                    id: inactiveSwitchMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    visible: !isActiveSwitch.enabled
                    hoverEnabled: true
                }

                StatusToolTip {
                    visible: !!inactiveSwitchMouseArea.containsMouse
                    text: qsTr("Required for some Status features")
                }
            }

            StatusFlatButton {
                icon.name: "pencil-outline"
                icon.color: hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1 
                onClicked: root.editNetwork()
            }
        }
    ]
}
