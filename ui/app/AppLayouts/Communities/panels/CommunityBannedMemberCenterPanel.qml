import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Layout

ColumnLayout {
    id: root

    objectName: "communityBannedMemberPanel"

    property string name
    property string chatDateTimeText
    property string listUsersText
    property var messagesModel

    spacing: 0

    // Blur background:
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(
                                    centralPanelData.implicitHeight,
                                    parent.height)

        ColumnLayout {
            id: centralPanelData
            width: parent.width
            layer.enabled: true
            layer.effect: blurEffect

            StatusBaseText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 30
                Layout.bottomMargin: 30
                text: root.chatDateTimeText
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter

                StatusBaseText {
                    text: root.listUsersText
                    font.pixelSize: Theme.additionalTextSize
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height + spacing
                Layout.topMargin: 16
                spacing: 16
                model: root.messagesModel
                delegate: StatusMessage {
                    width: ListView.view.width
                    timestamp: model.timestamp
                    enabled: false
                    messageDetails: StatusMessageDetails {
                        messageText: model.message
                        contentType: model.contentType
                        sender.displayName: model.senderDisplayName
                        sender.isContact: model.isContact
                        sender.trustIndicator: model.trustIndicator
                        sender.profileImage: StatusProfileImageSettings {
                            width: 40
                            height: 40
                            name: model.profileImage || ""
                            color: root.Theme.palette.userCustomizationColors[model.colorId]
                        }
                    }
                }
            }
        }
    }

    // User information content
    Rectangle {
        id: panelBase

        objectName: "userInfoPanelBase"

        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Theme.palette.statusAppLayout.rightPanelBackgroundColor
        gradient: Gradient {
            GradientStop {
                position: 0.000
                color: "transparent"
            }
            GradientStop {
                position: 0.180
                color: panelBase.color
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                StatusSmartIdenticon {
                    Layout.alignment: Qt.AlignVCenter

                    asset {
                        width: 24
                        height: width
                        name: "communities"
                        color: Theme.palette.dangerColor1
                        bgWidth: 22
                        bgHeight: 22
                    }
                }

                StatusBaseText {
                    objectName: "userInfoPanelBaseText"
                    text: qsTr("You've been banned from <b>%1<b>").arg(root.name)
                    color: Theme.palette.dangerColor1
                    font.pixelSize: Theme.secondaryAdditionalTextSize
                }
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }

    Component {
        id: blurEffect

        MultiEffect {
            blurEnabled: true
            blur: 1.0
        }
    }
}
