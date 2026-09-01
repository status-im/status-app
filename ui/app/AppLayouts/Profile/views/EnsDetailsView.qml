import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: root

    property string username: ""
    property bool isLoading

    signal backBtnClicked()
    signal releaseUsernameRequested(string senderAddress)
    signal removeEnsUsernameRequested(int chainId, string username)

    function setDetails(chainId: int, ensName: string, address: string, pubkey: string,
                        isStatus: bool, expirationTime: int, isPreferred: bool) {
        d.chainId = chainId
        d.walletAddress = address
        walletAddressLbl.subTitle = address

        d.key = pubkey
        keyLbl.subTitle = pubkey.substring(0, 20) + "..."
                + pubkey.substring(pubkey.length - 20)

        d.isStatus = isStatus
        releaseBtn.enabled = expirationTime > 0
                             && (Date.now() / 1000) > expirationTime
                             && !isPreferred
        d.expirationTimestamp = expirationTime * 1000
    }

    QtObject {
        id: d

        property double expirationTimestamp: 0
        property string walletAddress: "-"
        property string key: "-"
        property int chainId: -1
        property bool isStatus
    }

    RowLayout {
        id: headerRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 24

        StatusBaseText {
            id: sectionTitle

            Layout.fillWidth: true

            text: username
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(20)
            color: Theme.palette.directColor1
            elide: Text.ElideRight
        }

        Loader {
            id: loadingImg
            active: root.isLoading
            sourceComponent: StatusLoadingIndicator {}
        }
    }

    ColumnLayout {
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 24
        spacing: 24

        StatusDescriptionListItem {
            id: walletAddressLbl

            Layout.fillWidth: true

            title: qsTr("Wallet address")
            visible: !!d.walletAddress && !root.isLoading
            asset.name: "copy"
            tooltip.text: qsTr("Copied to clipboard!")
            iconButton.onClicked: {
                ClipboardUtils.setText(subTitle)
                tooltip.visible = !tooltip.visible
            }
        }
        StatusDescriptionListItem {
            id: keyLbl

            Layout.fillWidth: true

            title: qsTr("Key")
            visible: !!d.key && !root.isLoading
            asset.name: "copy"
            tooltip.text: qsTr("Copied to clipboard!")
            iconButton.onClicked: {
                ClipboardUtils.setText(subTitle)
                tooltip.visible = !tooltip.visible
            }
        }

        Flow {
            id: actionsLayout

            Layout.fillWidth: true

            spacing: root.Theme.padding

            StatusButton {
                id: removeButton
                visible: !root.isLoading
                type: StatusBaseButton.Type.Danger
                text: qsTr("Remove username")
                onClicked: root.removeEnsUsernameRequested(d.chainId, root.username)
            }

            StatusButton {
                id: releaseBtn
                visible: d.isStatus && !root.isLoading
                enabled: false
                text: qsTr("Release username")
                onClicked: root.releaseUsernameRequested(d.walletAddress)
            }
        }

        Text {
            visible: releaseBtn.visible && !releaseBtn.enabled
            Layout.fillWidth: true

            text: {
                if (d.expirationTimestamp === 0)
                    return ""
                const formattedDate = LocaleUtils.formatDate(d.expirationTimestamp, Locale.ShortFormat)
                return qsTr("Username locked. You won't be able to release it until %1").arg(formattedDate)
            }
            color: Theme.palette.darkGrey
        }
    }

    StatusButton {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.padding
        anchors.horizontalCenter: parent.horizontalCenter
        text: qsTr("Back")
        onClicked: backBtnClicked()
    }
}
