import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels

Control {
    id: root

    property alias nameLabel: nameInput.label
    property alias descriptionLabel: descriptionTextInput.label

    readonly property alias isNameValid: nameInput.valid
    readonly property alias isNameDirty: nameInput.input.dirty
    readonly property alias isDescriptionValid: descriptionTextInput.valid
    readonly property alias isDescriptionDirty: descriptionTextInput.input.dirty
    readonly property alias isLogoSelected: logoPicker.hasSelectedImage
    readonly property alias isBannerSelected: bannerPicker.hasSelectedImage
    readonly property alias areTagsSelected: tagsPicker.hasSelectedTags

    property alias name: nameInput.text
    property alias description: descriptionTextInput.text
    property alias color: colorPicker.color
    property alias tags: tagsPicker.tags
    property alias selectedTags: tagsPicker.selectedTags
    property alias options: options

    property alias logoImageData: logoPicker.imageData
    property alias logoImagePath: logoPicker.source
    property alias logoCropRect: logoPicker.cropRect
    property alias bannerImageData: bannerPicker.imageData
    property alias bannerPath: bannerPicker.source
    property alias bannerCropRect: bannerPicker.cropRect

    function validate(isDevBuild = false) {
        if (!nameInput.validate(true))
            nameInput.input.dirty = true
        if (!descriptionTextInput.validate(true))
            descriptionTextInput.input.dirty = true
        if (!isDevBuild) {
            logoPicker.validate()
            bannerPicker.validate()
            tagsPicker.validate()
        }

        return nameInput.valid && descriptionTextInput.valid &&
                (isDevBuild ? true : logoPicker.hasSelectedImage && bannerPicker.hasSelectedImage && tagsPicker.hasSelectedTags)
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding

        NameInput {
            id: nameInput
            input.edit.objectName: "communityNameInput"
            Layout.fillWidth: true
            input.tabNavItem: descriptionTextInput.input.edit
            Component.onCompleted: nameInput.input.forceActiveFocus()
        }

        DescriptionInput {
            id: descriptionTextInput
            input.edit.objectName: "communityDescriptionInput"
            input.tabNavItem: nameInput.input.edit
            Layout.fillWidth: true
        }

        LogoPicker {
            id: logoPicker
            objectName: "communityLogoPicker"
            onHasSelectedImageChanged: validate()
            Layout.fillWidth: true
        }

        BannerPicker {
            id: bannerPicker
            objectName: "communityBannerPicker"
            onHasSelectedImageChanged: validate()
            Layout.fillWidth: true
            Layout.topMargin: -8 //Closer by design
        }

        ColorPicker {
            id: colorPicker
            objectName: "communityColorPicker"
            onPick: Global.openPopup(pickColorComponent)
            Layout.fillWidth: true
            Layout.topMargin: 2

            Component {
                id: pickColorComponent

                StatusAdaptiveStackDialog {
                    id: pickColorDialog

                    anchors.centerIn: parent
                    implicitWidth: 640
                    maximumWidthOverride: 640
                    showStackBackButton: false
                    destroyOnClose: true
                    replaceItem: ColorPanel {
                        clip: true
                        Component.onCompleted: color = colorPicker.color
                        onAccepted: {
                            colorPicker.color = color;
                            pickColorDialog.close();
                        }
                    }
                }
            }
        }

        TagsPicker {
            id: tagsPicker
            objectName: "communityTagsPicker"
            onPick: Global.openPopup(pickTagsComponent)
            Layout.fillWidth: true

            Component {
                id: pickTagsComponent

                StatusAdaptiveStackDialog {
                    id: pickTagsDialog

                    anchors.centerIn: parent
                    implicitWidth: 640
                    maximumWidthOverride: 640
                    showStackBackButton: false
                    destroyOnClose: true
                    replaceItem: TagsPanel {
                        Component.onCompleted: {
                            tags = tagsPicker.tags
                            selectedTags = tagsPicker.selectedTags
                        }
                        onAccepted: (selectedTags) => {
                            tagsPicker.selectedTags = selectedTags
                            tagsPicker.validate()
                            pickTagsDialog.close()
                        }
                    }
                }
            }
        }

        StatusModalDivider {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }

        Options {
            id: options
            Layout.fillWidth: true
            Layout.topMargin: -parent.spacing
            Layout.bottomMargin: 4
        }
    }
}
