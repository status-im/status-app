import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Popups.Dialog

import utils
import shared.popups

import SortFilterProxyModel

import AppLayouts.Chat.stores

StatusAdaptiveDialog {
    id: root

    property RootStore store
    property string communityId
    property string categoryId
    property string categoryName: ""

    property bool isEdit: false

    readonly property int maxCategoryNameLength: 24

    title: isEdit ? qsTr("Edit category") : qsTr("New category")
    destroyOnClose: true

    onOpened: {
        if(isEdit) {
            root.store.prepareEditCategoryModel(categoryId);
        }
        root.hostedItem?.categoryName.input.edit.forceActiveFocus()
    }

    QtObject {
        id: d
        readonly property bool isFormValid: root.hostedItem?.categoryName.valid
        property var channels: []
        property bool channelsDirty
    }

    contentComponent: ColumnLayout {
        readonly property alias categoryName: nameInput
        spacing: Theme.halfPadding

        StatusInput {
            id: nameInput

            Layout.fillWidth: true

            input.edit.objectName: "createOrEditCommunityCategoryNameInput"
            input.clearable: true
            label: qsTr("Category title")
            charLimit: root.maxCategoryNameLength
            placeholderText: qsTr("Name the category")
            text: root.isEdit ? root.categoryName : ""
            validators: [
                StatusMinLengthValidator {
                    minLength: 1
                    errorMessage: Utils.getErrorMessage(nameInput.errors, qsTr("category name"))
                },
                StatusRegularExpressionValidator {
                    regularExpression: Constants.regularExpressions.alphanumericalExpanded
                    errorMessage: Constants.errorMessages.alphanumericalExpandedRegExp
                }
            ]
        }

        StatusDialogDivider {
            Layout.fillWidth: true
            Layout.topMargin: parent.spacing
        }

        StatusListView {
            id: communityChannelList
            objectName: "createOrEditCommunityCategoryChannelList"

            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight

            model: SortFilterProxyModel {
                sourceModel: root.isEdit ? root.store.chatCommunitySectionModule.editCategoryChannelsModel
                                         : root.store.chatCommunitySectionModule.model
                // filter out channels with categories
                filters: ValueFilter {
                    enabled: !root.isEdit
                    roleName: "categoryId"
                    value: ""
                }
            }

            header: Item {
                width: parent.width
                height: 34
                StatusBaseText {
                    text: qsTr("Channels")
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    font.pixelSize: Theme.primaryTextFontSize
                    color: Theme.palette.baseColor1
                }
            }

            delegate: Loader {
                active: model.type !== Constants.chatType.category
                width: ListView.view.width

                sourceComponent: StatusListItem {
                    readonly property bool checked: channelItemCheckbox.checked
                    objectName: "category_item_name_" + model.name
                    title: "#" + model.name
                    asset.width: 40
                    asset.height: 40
                    asset.emoji: model.emoji
                    asset.color: model.color
                    asset.imgIsIdenticon: false
                    asset.name: model.icon
                    asset.isImage: !!model.icon
                    asset.isLetterIdenticon: true
                    asset.bgColor: model.color
                    onClicked: channelItemCheckbox.click()

                    components: [
                        StatusCheckBox {
                            id: channelItemCheckbox
                            checked: root.isEdit ? model.categoryId === root.categoryId : false
                            onCheckedChanged: {
                                if(checked){
                                    var idx = d.channels.indexOf(model.itemId)
                                    if(idx === -1){
                                        const tmpArray = Array.from(d.channels)
                                        tmpArray.push(model.itemId)
                                        d.channels = tmpArray
                                    }
                                } else {
                                    d.channels = d.channels.filter(el => el !== model.itemId);
                                }
                            }
                            onToggled: d.channelsDirty = true // user change
                        }
                    ]
                }
            }
        }
    }

    Component {
        id: deleteCategoryConfirmationDialogComponent
        ConfirmationDialog {
            btnType: "warn"
            showCancelButton: true
            onClosed: {
                destroy()
            }
            onCancelButtonClicked: {
                close();
            }
            onConfirmButtonClicked: function(){
                const error = root.store.deleteCommunityCategory(root.categoryId);
                if (error) {
                    categoryError.text = error
                    return categoryError.open()
                }
                close();
                root.close()
            }
        }
    }

    footerRightButtons: ObjectModel {
        StatusButton {
            visible: root.isEdit
            type: StatusBaseButton.Type.Danger
            text: qsTr("Delete Category")
            onClicked: {
                deleteCategoryConfirmationDialogComponent.createObject(root).open()
            }
        }
        StatusButton {
            objectName: "createOrEditCommunityCategoryBtn"
            enabled: {
                if (root.isEdit) {
                    if (d.channelsDirty)
                        return d.isFormValid || root.hostedItem?.categoryName.text === root.categoryName
                }
                return d.isFormValid
            }

            text: root.isEdit ? qsTr("Save") : qsTr("Create")
            onClicked: {
                let error = ""
                if (root.isEdit) {
                    error = root.store.editCommunityCategory(root.categoryId, StatusQUtils.Utils.filterXSS(root.hostedItem.categoryName.input.text), JSON.stringify(d.channels));
                } else {
                    error = root.store.createCommunityCategory(StatusQUtils.Utils.filterXSS(root.hostedItem.categoryName.input.text), JSON.stringify(d.channels));
                }

                if (error) {
                    categoryError.text = error
                    return categoryError.open()
                }

                root.close()
            }
        }
    }

    StatusMessageDialog {
        id: categoryError
        title: isEdit ? qsTr("Error editing the category")
                      : qsTr("Error creating the category")
        icon: StatusMessageDialog.StandardIcon.Critical
    }
}
