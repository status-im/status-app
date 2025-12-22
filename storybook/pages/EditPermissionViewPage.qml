import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Communities.views

import Storybook
import Models

import SortFilterProxyModel

SplitView {
    orientation: Qt.Vertical
    SplitView.fillWidth: true

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        EditPermissionView {
            id: editPermissionView

            anchors.fill: parent

            isEditState: isEditStateCheckBox.checked
            isPrivate: isPrivateCheckBox.checked
            permissionDuplicated: isPermissionDuplicatedCheckBox.checked
            permissionTypeLimitReached: isLimitReachedCheckBox.checked
            saveInProgress: isSavingInProgressCheckBox.checked
            errorSaving: errorSavingCheckBox.checked ? "Wrong permission data" : ""

            assetsModel: AssetsModel {}
            collectiblesModel: CollectiblesModel {}
            channelsModel: SortFilterProxyModel {
                sourceModel: ChannelsModel {}
                proxyRoles: [
                    JoinRole {
                        name: "key"
                        roleNames: ["itemId"]
                    },
                    JoinRole {
                        name: "text"
                        roleNames: ["name"]
                    }
                ]
            }
            communityDetails: QtObject {
                readonly property string id: "id_sox"
                readonly property string name: "Socks"
                readonly property string image: ModelsData.icons.socks
                readonly property string color: "red"
                readonly property bool owner: isOwnerCheckBox.checked
            }

            onCreatePermissionClicked: {
                logs.logEvent("EditPermissionView::onCreatePermissionClicked")
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 160

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            RowLayout {
                Layout.fillWidth: true

                CheckBox {
                    id: isOwnerCheckBox

                    text: "Is owner"
                }

                CheckBox {
                    id: isEditStateCheckBox

                    text: "Is edit state"
                }

                CheckBox {
                    id: isPrivateCheckBox

                    text: "Is private"
                }

                CheckBox {
                    id: isPermissionDuplicatedCheckBox

                    text: "Is permission duplicated"
                }

                CheckBox {
                    id: isLimitReachedCheckBox

                    text: "Is limit reached"
                }

                CheckBox {
                    id: isSavingInProgressCheckBox

                    text: "Is saving in progress"
                }

                CheckBox {
                    id: errorSavingCheckBox

                    text: "Error saving"
                }
            }

            Button {
                text: "Reset changes"

                onClicked: editPermissionView.resetChanges()
            }

            Label {
                text: "Is dirty: " + editPermissionView.dirty
            }
        }
    }
}

// category: Views
// status: good
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22253%3A486103&t=JrCIfks1zVzsk3vn-0
