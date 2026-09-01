import QtQuick
import QtQuick.Controls

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    // Status UsernameRegistrar contract address.
    property string registrarAddress
    // ENS Registry contract address.
    property string ensRegistryAddress
    // Base Etherscan address URL used to build the "look up" links.
    property string etherscanAddressLink

    title: qsTr("Terms of name registration")
    width: 480
    standardButtons: Dialog.Ok

    StatusScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        Column {
            spacing: Theme.halfPadding
            width: scroll.availableWidth


            StatusBaseText {
                text: qsTr("Funds are deposited for 1 year. Your SNT will be locked, but not spent.")
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("After 1 year, you can release the name and get your deposit back, or take no action to keep the name.")
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("If terms of the contract change — e.g. Status makes contract upgrades — user has the right to release the username regardless of time held.")
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("The contract controller cannot access your deposited funds. They can only be moved back to the address that sent them.")
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("Your address(es) will be publicly associated with your ENS name.")
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("Usernames are created as subdomain nodes of stateofus.eth and are subject to the ENS smart contract terms.")
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("You authorize the contract to transfer SNT on your behalf. This can only occur when you approve a transaction to authorize the transfer.")
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("These terms are guaranteed by the smart contract logic at addresses:")
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                font.weight: Font.Bold
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("%1 (Status UsernameRegistrar).").arg(root.registrarAddress)
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                font.family: Fonts.monoFont.family
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("<a href='%1/%2'>Look up on Etherscan</a>")
                .arg(root.etherscanAddressLink)
                .arg(root.registrarAddress)
                anchors.left: parent.left
                anchors.right: parent.right
                onLinkActivated: (link) => Global.requestOpenLink(link)
                color: Theme.palette.directColor1
                StatusMouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton // we don't want to eat clicks on the Text
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            StatusBaseText {
                text: qsTr("%1 (ENS Registry).").arg(root.ensRegistryAddress)
                wrapMode: Text.WordWrap
                anchors.left: parent.left
                anchors.right: parent.right
                font.family: Fonts.monoFont.family
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                text: qsTr("<a href='%1/%2'>Look up on Etherscan</a>")
                .arg(root.etherscanAddressLink)
                .arg(root.ensRegistryAddress)
                anchors.left: parent.left
                anchors.right: parent.right
                onLinkActivated: (link) => Global.requestOpenLink(link)
                color: Theme.palette.directColor1
                StatusMouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton // we don't want to eat clicks on the Text
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

        }
    }
}
