import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Core.Utils as CoreUtils

import shared
import utils

StatusDialog {
    id: root

    property StatusMessageDetails messageDetails
    property string compressedPubKey
    property double timestamp: 0

    signal accepted
    signal declined

    anchors.centerIn: parent
    width: 638
    padding: Theme.bigPadding

    title: qsTr("Review Contact Request")
    RowLayout {
        id: messageRow
        spacing: 8
        width: parent.width

        Item {
            Layout.preferredWidth: root.messageDetails.sender.profileImage.assetSettings.width
            Layout.preferredHeight: profileImage.height
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: -Theme.halfPadding
            Layout.topMargin: 2

            StatusSmartIdenticon {
                id: profileImage
                name: root.messageDetails.sender.displayName
                asset: root.messageDetails.sender.profileImage.assetSettings
            }
        }

        ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true

            StatusMessageHeader {
                sender: root.messageDetails.sender
                amISender: root.messageDetails.amISender
                messageOriginInfo: root.messageDetails.messageOriginInfo
                tertiaryDetail: root.compressedPubKey
                timestamp: root.timestamp
            }

            RowLayout {
                spacing: 2
                Layout.fillWidth: true

                StatusBaseText {
                    text: CoreUtils.Utils.stripHtmlTags(root.messageDetails.messageText)
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.primaryTextFontSize
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.rightMargin: -Theme.halfPadding
                }
            }
        }
    }
    footer: StatusDialogFooter {
        bottomPadding: root.padding + root.parent.SafeArea.margins.bottom
        rightButtons: ObjectModel {
            StatusButton {
                text: qsTr("Accept Contact Request")
                onClicked: {
                    root.accepted()
                    root.close()
                }
            }
            StatusButton {
                type: StatusBaseButton.Type.Danger
                text: qsTr("Reject Contact Request")
                onClicked: {
                    root.declined()
                    root.close()
                }
            }
        }
    }
}
