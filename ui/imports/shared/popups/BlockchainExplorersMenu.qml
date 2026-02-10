import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups

import utils

StatusMenu {
    id: root

    property var flatNetworks

    signal networkClicked(string shortname, bool isTestnet)

    title: qsTr("View on blockchain explorer")
    assetSettings.name: "link"

    StatusMenuInstantiator {
        id: menuLoader

        model: root.flatNetworks
        menu: root
        delegate: StatusMenuItem {
            action: StatusAction {
                text: Utils.getChainExplorerName(model.shortName)
                assetSettings.name: Assets.svg(model.iconUrl)
                assetSettings.isImage: true
                onTriggered: {
                    root.networkClicked(model.shortName, model.isTest)
                    root.dismiss()
                }
            }
            arrow: StatusIcon {
                anchors.right: parent.right
                anchors.rightMargin: parent.horizontalPadding
                anchors.verticalCenter: parent.verticalCenter
                icon: "external-link"
                color: Theme.palette.primaryColor1
            }
        }
    }
}
