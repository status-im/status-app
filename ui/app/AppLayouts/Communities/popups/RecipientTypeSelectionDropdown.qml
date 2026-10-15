import QtQuick
import QtQuick.Layouts

import StatusQ.Controls


StatusDropdown {
    id: root

    signal ethAddressesSelected
    signal communityMembersSelected

    width: 289
    padding: 8
    leftPadding: 16

    ColumnLayout {
        spacing: 8

        StatusIconTextButton {
            objectName: "airdropEthAddressesOption"
            Layout.preferredHeight: 36
            Layout.fillWidth: true

            spacing: 9
            statusIcon: "address"
            icon.width: 15
            icon.height: 15
            text: qsTr("ETH adresses")

            onClicked: root.ethAddressesSelected()
        }

        StatusIconTextButton {
            Layout.preferredHeight: 36
            Layout.fillWidth: true

            spacing: 9
            statusIcon: "profile"
            icon.width: 15
            icon.height: 15
            text: qsTr("Community members")

            onClicked: root.communityMembersSelected()
        }
    }
}
