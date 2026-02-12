import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtQml.Models

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    objectName: "dappConfirmDisconnectPopup"

    property string dappName
    property url dappIcon
    property string dappUrl

    implicitWidth: 640

    contentItem: StatusBaseText {
        text: qsTr("Are you sure you want to disconnect %1 from all accounts?").arg(dappUrl ? StringUtils.extractDomainFromLink(dappUrl) : dappName)

        wrapMode: Text.WrapAnywhere
    }

    header: StatusDialogHeader {
        leftComponent: StatusRoundedImage {
            height: 40
            width: height

            image.source: root.dappIcon
        }
        headline.title: qsTr("Disconnect %1").arg(root.dappName)
        headline.subtitle: root.dappUrl ? StringUtils.extractDomainFromLink(root.dappUrl) : ""
        actions.closeButton.visible: true
        actions.closeButton.onClicked: root.close()
    }

    footer: StatusDialogFooter {
        spacing: 16
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: qsTr("Cancel")
                onClicked: root.reject();
            }
            StatusButton {
                type: StatusButton.Danger
                text: qsTr("Disconnect dApp")
                icon.name: "disconnect"
                onClicked: {
                    root.accepted();
                    root.close();
                }
            }
        }
    }
}
