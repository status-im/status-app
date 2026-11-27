import QtQuick

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups

import utils

StatusFlatButton {
    id: root

    /** Input property holding selected recipient address **/
    required property string recipientAddress
    /** Input property holding selected network name **/
    required property string networkName
    /** Input property holding selected network short name **/
    required property string networkShortName
    /** Input property holding selected network explorer url **/
    required property string networkBlockExplorerUrl
    property bool revealNeedsPassword: false

    /** Signal to launch link **/
    signal openLink(string link)

    QtObject {
        id: d

        function getExplorerName() {
            return Utils.getChainExplorerName(root.networkShortName)
        }
    }

    icon.name: "more"
    icon.color: highlighted ? Theme.palette.directColor1 : Theme.palette.directColor5
    highlighted: moreMenu.opened
    onClicked: moreMenu.popup(root, 0, height + 4)

    StatusMenu {
        id: moreMenu
        objectName: "moreMenu"

        StatusAction {
            objectName: "externalLink"
            //: e.g. "View receiver address on Etherscan"
            text:  qsTr("View receiver address on %1").arg(d.getExplorerName())
            icon.name: "external-link"
            onTriggered: {
                const link = "%1/%2/%3".arg(root.networkBlockExplorerUrl).arg(Constants.networkExplorerLinks.addressPath).arg(root.recipientAddress)
                if (root.revealNeedsPassword)
                    Global.openOwnAddressLinkRequested(link)
                else
                    root.openLink(link)
            }
        }
        StatusSuccessAction {
            objectName: "copyButton"
            showSuccess: !root.revealNeedsPassword
            text: qsTr("Copy receiver address")
            successText: qsTr("Copied")
            icon.name: "copy"
            autoDismissMenu: true
            onTriggered: {
                if (!root.revealNeedsPassword) {
                    ClipboardUtils.setText(root.recipientAddress)
                    return
                }
                // Nothing is copied before the password is set, so no "copied" state either
                Global.copyOwnAddressRequested(root.recipientAddress)
                moreMenu.close()
            }
        }
    }
}
