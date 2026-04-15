import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import shared.controls
import shared.panels
import utils

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core
import StatusQ.Popups
import StatusQ.Popups.Dialog

StatusDialog {
    id: root
    objectName: "groupChatEdit_main"

    property string activeGroupImageData
    property string activeGroupColor
    property string activeGroupName

    signal updateGroupChatDetails(string groupName, string groupColor, string groupImage)

    title: qsTr("Edit group name and image")
    width: 480
    padding: 0

    QtObject {
        id: d
        readonly property int nameCharLimit: 30 // cf spec: https://github.com/status-im/feature-specs/blob/d66c586f13cb1fa0486544030148df68e06928f0/content/raw/chat/group_chat.md
    }

    onOpened: {
        groupName.input.edit.forceActiveFocus()
        groupName.text = root.activeGroupName.substring(0, d.nameCharLimit)

        colorSelectionGrid.selectedColor = activeGroupColor

        for (let i = 0; i < colorSelectionGrid.model.length; i++) {
            if(colorSelectionGrid.model[i].toString().toUpperCase() === root.activeGroupColor.toUpperCase())
                colorSelectionGrid.selectedColorIndex = i
        }

        imageEditor.dataImage = activeGroupImageData
    }

    StatusScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scrollView.availableWidth
            spacing: 20

            StatusInput {
                id: groupName
                input.edit.objectName: "groupChatEdit_name"
                Layout.fillWidth: true
                label: qsTr("Name the group")
                charLimit: d.nameCharLimit

                validators: [
                    StatusMinLengthValidator {
                        minLength: 1
                        errorMessage: Utils.getErrorMessage(groupName.errors, qsTr("group name"))
                    },
                    StatusRegularExpressionValidator {
                        regularExpression: Constants.regularExpressions.alphanumericalExpanded2
                        errorMessage: Constants.errorMessages.alphanumericalExpandedRegExp
                    }
                ]
            }

            StatusBaseText {
                id: imgText
                text: qsTr("Group image")
            }

            EditCroppedImagePanel {
                id: imageEditor
                objectName: "groupChatEdit_image"
                Layout.preferredWidth: 128
                Layout.preferredHeight: Layout.preferredWidth / aspectRatio
                Layout.alignment: Qt.AlignHCenter

                imageFileDialogTitle: qsTr("Choose an image as logo")
                title: qsTr("Edit group name and image")
                acceptButtonText: qsTr("Use as an icon for this group chat")
            }

            StatusBaseText {
                id: colorText
                text: qsTr("Standard colours")
            }

            StatusColorSelectorGrid {
                id: colorSelectionGrid
                objectName: "groupChatEdit_color"
                Layout.fillWidth: true
                Layout.topMargin: -(parent.spacing / 3)
                diameter: 40
                selectorDiameter: 16
                columns: 6
                selectedColorIndex: -1
            }

            Item {
                id: spacerItem
                height: 10
            }
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusButton {
                id: saveBtn
                objectName: "groupChatEdit_save"
                text: qsTr("Save changes")
                enabled: groupName.text.trim().length > 0 &&
                         ((groupName.text != root.activeGroupName) ||
                          (root.activeGroupColor != colorSelectionGrid.selectedColor) ||
                          (String(imageEditor.source).length > 0))
                onClicked : {
                    updateGroupChatDetails(groupName.text, colorSelectionGrid.selectedColor,
                                           Utils.getImageAndCropInfoJson(imageEditor.source, imageEditor.cropRect))
                }
            }
        }
    }
}
