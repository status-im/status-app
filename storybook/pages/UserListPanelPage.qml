import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Chat.panels

import Models

import utils

SplitView {
    orientation: Qt.Vertical

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        padding: 100

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.color: "gray"
        }

        UserListPanel {
            anchors.fill: parent

            usersModel: UsersModel {}

            label: labelTextField.text
            isAdmin: isAdminCheckBox.checked
            chatType: chatTypeSelector.currentValue
            communityMemberReevaluationStatus:
                communityMemberReevaluationStatusSelector.currentValue
        }
    }

    Pane {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        ColumnLayout {
            RowLayout {
                Label {
                    text: "Label:"
                }

                TextField {
                    Layout.fillWidth: true
                    id: labelTextField

                    text: "Some label here"
                }
            }

            CheckBox {
                id: isAdminCheckBox

                text: "Is admin (allows to remove used from private group chat)"
            }

            RowLayout {
                Label {
                    text: "Chat Type:"
                }

                ComboBox {
                    id: chatTypeSelector

                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Unknown", value: Constants.chatType.unknown },
                        { text: "Category", value: Constants.chatType.category },
                        { text: "One-to-One", value: Constants.chatType.oneToOne },
                        { text: "Public Chat", value: Constants.chatType.publicChat },
                        { text: "Private Group Chat", value: Constants.chatType.privateGroupChat },
                        { text: "Profile", value: Constants.chatType.profile },
                        { text: "Community Chat", value: Constants.chatType.communityChat }
                    ]
                }
            }

            RowLayout {
                Label {
                    text: "Community member reevaluation status:"
                }

                ComboBox {
                    id: communityMemberReevaluationStatusSelector

                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Unknown", value: Constants.CommunityMemberReevaluationStatus.None },
                        { text: "InProgress", value: Constants.CommunityMemberReevaluationStatus.InProgress },
                        { text: "Done", value: Constants.CommunityMemberReevaluationStatus.Done }
                    ]
                }
            }
        }
    }
}

// category: Panels
// status: good
