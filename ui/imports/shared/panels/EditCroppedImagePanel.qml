import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import utils
import shared.panels
import shared.popups

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Layout
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

Item {
    id: root

    property alias source: croppedPreview.source
    property alias cropRect: croppedPreview.cropRect
    /*required*/ property alias aspectRatio: imageCropWorkflow.aspectRatio

    property alias roundedImage: imageCropWorkflow.roundedImage

    /*required*/ property alias imageFileDialogTitle: imageCropWorkflow.imageFileDialogTitle
    /*required*/ property alias title: imageCropWorkflow.title
    /*required*/ property alias acceptButtonText: imageCropWorkflow.acceptButtonText
    property alias editButtonVisible: editButton.visible

    property string dataImage: ""

    property Component backgroundComponent

    property bool userSelectedImage: false
    readonly property bool nothingToShow: state === d.noImageState
    property bool isError

    readonly property alias cropWorkflow : imageCropWorkflow

    function cropImage(file) {
        imageCropWorkflow.cropImage(file);
    }

    function chooseImageToCrop() {
        imageCropWorkflow.chooseImageToCrop()
    }

    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight

    objectName: "editCroppedImageItem_" + root.title

    states: [
        State {
            name: d.dataImageState
            when: root.dataImage.length > 0 && !userSelectedImage
        },
        State {
            name: d.noImageState
            when: root.dataImage.length === 0 && !userSelectedImage && !backgroundComponent
        },
        State {
            name: d.imageSelectedState
            when: userSelectedImage
        },
        State {
            name: d.backgroundComponentState
            when: root.dataImage.length === 0 && !userSelectedImage && backgroundComponent
        }
    ]

    QtObject {
        id: d

        readonly property string dataImageState: "dataImage"
        readonly property string noImageState: "noImage"
        readonly property string imageSelectedState: "imageSelected"
        readonly property string backgroundComponentState: "backgroundComponent"
        readonly property int buttonsInsideOffset: 5
    }

    ColumnLayout {
        id: mainLayout

        anchors.fill: parent

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            visible: !imageCropEditor.visible && (root.state !== d.backgroundComponentState)

            StatusRoundedImage {
                anchors.fill: parent

                visible: root.state === d.dataImageState

                image.source: root.dataImage
                showLoadingIndicator: true
                border.width: 1
                border.color: Theme.palette.border
                radius: root.roundedImage ? width/2 : croppedPreview.radius
            }

            StatusImageCrop {
                id: croppedPreview
                anchors.fill: parent

                visible: root.state === d.imageSelectedState
                windowStyle: imageCropWorkflow.windowStyle
                wallColor: Theme.palette.statusAppLayout.backgroundColor
                wallTransparency: 1
                clip:true
            }

            StatusRoundButton {
                id: editButton

                icon.name: "edit_pencil"

                width: 40
                height: 40

                readonly property real rotationRadius: root.roundedImage ? parent.width/2 : imageCropEditor.radius
                transform: [
                    Translate {
                        x: -editButton.width/2 - d.buttonsInsideOffset
                        y: -editButton.height/2 + d.buttonsInsideOffset
                    },
                    Rotation { angle: -editRotationTransform.angle },
                    Rotation {
                        id: editRotationTransform
                        angle: 135
                        origin.x: editButton.rotationRadius
                    },
                    Translate {
                        x: root.roundedImage ? 0 : editButton.parent.width - 2 * editButton.rotationRadius
                        y: editButton.rotationRadius
                    }
                ]
                type: StatusRoundButton.Type.Secondary

                onClicked: chooseImageToCrop()
                // TODO uncomment when status-go supports deleting images:
                // onClicked: imageEditMenu.popup(this, mouse.x, mouse.y)
            }
        }

        Rectangle {
            id: imageCropEditor

            Layout.fillWidth: true
            Layout.fillHeight: true

            visible: root.state === d.noImageState
            radius: roundedImage ? Math.max(width, height)/2 : croppedPreview.radius
            color: Theme.palette.baseColor2

            border.color: Theme.palette.dangerColor1
            border.width: root.isError ? 1 : 0

            StatusRoundButton {
                id: addButton

                icon.name: "add"
                width: 40
                height: 40

                parent: root
                visible: imageCropEditor.visible
                x: imageCropEditor.x + imageCropEditor.width - width/2 - d.buttonsInsideOffset
                y: imageCropEditor.y - height/2 + d.buttonsInsideOffset

                type: StatusRoundButton.Type.Secondary

                onClicked: chooseImageToCrop()
                z: imageCropEditor.z + 1
            }

            ImageCropWorkflow {
                id: imageCropWorkflow

                onImageCropped: function (image, cropRect) {
                    croppedPreview.source = image
                    croppedPreview.setCropRect(cropRect)
                    root.userSelectedImage = true
                }
            }
        }

        Loader {
            id: backgroundLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            visible: root.state === d.backgroundComponentState

            sourceComponent: root.backgroundComponent
        }
    }

    StatusMenu {
        id: imageEditMenu

        StatusAction {
            text: qsTr("Select different image")
            assetSettings.name: "image"
            onTriggered: chooseImageToCrop()
        }

        StatusAction {
            text: qsTr("Remove image")
            type: StatusAction.Danger
            assetSettings.name: "delete"
            onTriggered: {
                root.userSelectedImage = false
                root.dataImage = ""
                root.source = ""
                croppedPreview.setCropRect(Qt.rect(0, 0, 0, 0))
            }
        }
    }
}
