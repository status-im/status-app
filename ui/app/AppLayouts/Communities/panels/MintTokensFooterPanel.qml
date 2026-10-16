import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Popups
import StatusQ.Controls
import StatusQ.Core.Theme

import utils

Control {
    id: root

    property string communityName

    property alias airdropEnabled: airdropButton.enabled
    property alias retailEnabled: retailButton.enabled
    property alias remotelyDestructEnabled: remotelyDestructButton.enabled
    property alias burnEnabled: burnButton.enabled
    property alias sendOwnershipEnabled: sendOwnershipButton.enabled

    property alias airdropVisible: airdropButton.visible
    property alias remotelyDestructVisible: remotelyDestructButton.visible
    property alias burnVisible: burnButton.visible
    property alias sendOwnershipVisible: sendOwnershipButton.visible

    signal airdropClicked
    signal retailClicked
    signal remotelyDestructClicked
    signal burnClicked
    signal sendOwnershipClicked

    height: 61 // by design
    spacing: Theme.padding

    contentItem: ColumnLayout {
        spacing: 0

        StatusModalDivider {
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: root.spacing

            Item {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 1
            }

            StatusFlatButton {
                id: sendOwnershipButton
                objectName: "sendOwnerTokenButton"

                Layout.horizontalStretchFactor: 0
                Layout.fillWidth: true

                icon.name: "send"
                text: qsTr("Send Owner token to transfer %1 Community ownership").arg(root.communityName)

                onClicked: root.sendOwnershipClicked()
            }

            StatusFlatButton {
                id: airdropButton
                objectName: "airdropTokenButton"

                Layout.horizontalStretchFactor: 0
                Layout.fillWidth: true

                icon.name: "airdrop"
                text: qsTr("Airdrop")

                onClicked: root.airdropClicked()
            }

            StatusFlatButton {
                id: retailButton

                Layout.horizontalStretchFactor: 0
                Layout.fillWidth: true

                icon.name: "token-sale"
                visible: false // TODO: Milestone 14
                text: qsTr("Retail")

                onClicked: root.retailClicked()
            }

            StatusFlatButton {
                id: remotelyDestructButton
                objectName: "remotelyDestructTokenButton"

                Layout.horizontalStretchFactor: 0
                Layout.fillWidth: true

                icon.name: "remotely-destruct"
                text: qsTr("Remotely destruct")
                type: StatusBaseButton.Type.Danger
                borderColor: "transparent"

                onClicked: root.remotelyDestructClicked()
            }

            StatusFlatButton {
                id: burnButton
                objectName: "burnRemainingTokensButton"

                Layout.horizontalStretchFactor: 0
                Layout.fillWidth: true

                icon.name: "delete"
                text: qsTr("Burn")
                type: StatusBaseButton.Type.Danger
                borderColor: "transparent"

                onClicked: root.burnClicked()
            }

            Item {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 1
            }
        }
    }
}


