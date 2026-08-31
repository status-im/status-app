import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import shared
import shared.panels
import shared.views.chat
import shared.controls.chat
import utils

import "../popups"

Item {
    id: root

    property int profileContentWidth

    // ENS usernames for the current chain; expected roles: ensUsername, isPending, chainId.
    property var model

    // Profile fields used to preview how the preferred username appears in chats.
    property string preferredUsername
    property string pubkey
    property string icon

    // Whether the user has any confirmed or pending ENS usernames (gates the chat settings section).
    property bool hasConfirmedEnsUsernames

    signal addBtnClicked()
    signal selectEns(string username, int chainId)

    // Emitted when the user confirms a different preferred username in the popup.
    signal preferredUsernameSelected(string ensUsername)

    Item {
        anchors.top: parent.top
        width: profileContentWidth
        anchors.horizontalCenter: parent.horizontalCenter

        StatusBaseText {
            id: sectionTitle
            text: qsTr("ENS usernames")
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 24
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(20)
            color: Theme.palette.directColor1
        }

        Item {
            id: addUsername
            anchors.top: sectionTitle.bottom
            anchors.topMargin: Theme.bigPadding
            width: addButton.width + usernameText.width + Theme.padding
            height: addButton.height

            StatusRoundButton {
                id: addButton
                width: 40
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                icon.name: "add"
                type: StatusRoundButton.Type.Secondary
            }

            StatusBaseText {
                id: usernameText
                text: qsTr("Add username")
                color: Theme.palette.primaryColor1
                anchors.left: addButton.right
                anchors.leftMargin: Theme.padding
                anchors.verticalCenter: addButton.verticalCenter
                font.pixelSize: Theme.primaryTextFontSize
            }

            StatusMouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: addBtnClicked()
            }
        }


        StatusBaseText {
            id: usernamesLabel
            text: qsTr("Your usernames")
            anchors.left: parent.left
            anchors.top: addUsername.bottom
            anchors.topMargin: 24
            font.pixelSize: Theme.fontSize(16)
            color: Theme.palette.directColor1
        }

        Item {
            id: ensList
            anchors.top: usernamesLabel.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: 200

            StatusListView {
                id: lvEns
                anchors.fill: parent
                model: root.model

                spacing: 10
                delegate: StatusListItem {
                    readonly property int indexOfDomainStart: model.ensUsername.indexOf(".")

                    width: ListView.view.width
                    title: model.ensUsername.substr(0, indexOfDomainStart)
                    subTitle: model.ensUsername.substr(indexOfDomainStart)
                    titleAsideText: model.isPending ? qsTr("(pending)") : ""

                    statusListItemTitle.font.pixelSize: Theme.secondaryAdditionalTextSize
                    statusListItemTitle.font.bold: true

                    asset.isImage: false
                    asset.isLetterIdenticon: true
                    asset.bgColor: Theme.palette.primaryColor1
                    asset.width: 40
                    asset.height: 40

                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]

                    onClicked: {
                        root.selectEns(model.ensUsername, model.chainId)
                    }
                }

            }
        }

        Separator {
            id: separator
            anchors.topMargin: Theme.padding
            anchors.top: ensList.bottom
        }

        StatusBaseText {
            id: chatSettingsLabel
            visible: root.hasConfirmedEnsUsernames
            text: qsTr("Chat settings")
            anchors.left: parent.left
            anchors.top: ensList.bottom
            anchors.topMargin: 24
            font.pixelSize: Theme.fontSize(16)
            color: Theme.palette.directColor1
        }

        Item {
            width: childrenRect.width
            height: childrenRect.height

            id: primaryUsernameItem
            anchors.left: parent.left
            anchors.top: chatSettingsLabel.bottom
            anchors.topMargin: 24

            StatusBaseText {
                id: usernameLabel
                visible: chatSettingsLabel.visible
                text: qsTr("Primary Username")
                font.pixelSize: Theme.secondaryTextFontSize
                font.weight: Font.Bold
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                id: usernameLabel2
                visible: chatSettingsLabel.visible
                text: root.preferredUsername || qsTr("None selected")
                anchors.left: usernameLabel.right
                anchors.leftMargin: Theme.padding
                font.pixelSize: Theme.secondaryTextFontSize
                color: Theme.palette.directColor1
            }

            StatusMouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Global.openPopup(ensPopupComponent)
                }
            }
        }

        StatusMessage {
            id: messagesShownAs

            anchors.top: !visible ? separator.bottom : primaryUsernameItem.bottom
            anchors.topMargin: Theme.padding * 2

            visible: root.hasConfirmedEnsUsernames
                     && root.preferredUsername !== ""

            timestamp: new Date().getTime()
            disableHover: true
            profileClickable: false

            messageDetails: StatusMessageDetails {
                contentType: StatusMessage.ContentType.Text
                messageText: qsTr("Hey!")
                amISender: false
                sender.displayName: root.preferredUsername
                sender.profileImage.assetSettings.isImage: true
                sender.profileImage.assetSettings.color: Utils.colorForPubkey(root.Theme.palette, root.pubkey)
                sender.profileImage.name: root.icon
            }
        }

        StatusBaseText {
            anchors.top: messagesShownAs.bottom
            anchors.left: messagesShownAs.left
            anchors.topMargin: Theme.padding
            text: qsTr("You’re displaying your ENS username in chats")
            font.pixelSize: Theme.fontSize(14)
            color: Theme.palette.baseColor1
        }
    }

    Component {
        id: ensPopupComponent

        ENSPopup {
            preferredUsername: root.preferredUsername
            model: root.model
            destroyOnClose: true

            onPreferredUsernameSelected: (ensUsername) => root.preferredUsernameSelected(ensUsername)
        }
    }
}
