import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Popups.Dialog

import utils

Item {
    id: root
    objectName: "imageCropWorkflow"

    property var callback: null
    property alias aspectRatio: imageCropper.aspectRatio
    property alias windowStyle: imageCropper.windowStyle
    /*required*/ property string imageFileDialogTitle: ""
    /*required*/ property string title: ""
    /*required*/ property string acceptButtonText: ""
    property bool roundedImage: true

    signal imageCropped(var image, var cropRect)
    signal done()

    function chooseImageToCrop() {
        fileDialog.open()
    }

    function cropImage(imageUrl) {
        imageCropper.source = imageUrl
        imageCropperModal.open()
    }

    StatusFileDialog {
        id: fileDialog

        title: root.imageFileDialogTitle
        currentFolder: root.userSelectedImage ? imageCropper.source.substr(0, imageCropper.source.lastIndexOf("/")) : fileDialog.picturesShortcut
        usePhotoLibrary: true
        nameFilters: [qsTr("Supported image formats (%1)").arg(UrlUtils.validImageNameFilters)]
        onAccepted: {
            if (fileDialog.selectedFiles.length > 0) {
                const url = fileDialog.selectedFile
                if (Utils.isValidDragNDropImage(url))
                    cropImage(url)
                else {
                    errorDialog.fileOpened = url
                    errorDialog.open()
                }
            }
        }
    } // FileDialog

    StatusDialog {
        id: errorDialog

        property string fileOpened

        title: qsTr("Image format not supported")
        width: 480
        contentItem: ColumnLayout {
            StatusBaseText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Format of the image you chose is not supported. Most probably you picked a file that is invalid, corrupted or has a wrong file extension. The requested file was: %1").arg(errorDialog.fileOpened)
            }
            StatusBaseText {
                Layout.fillWidth: true
                font.pixelSize: Theme.additionalTextSize
                text: qsTr("Supported image extensions: %1").arg(UrlUtils.allValidImageExtensions)
            }
        }
        standardButtons: Dialog.Ok
    } // StatusDialog

    StatusModal {
        id: imageCropperModal

        headerSettings.title: root.title
        fullScreenSheet: false

        width: root.roundedImage ? 480 : 580
        topPadding: header.height
        bottomPadding: footer.height

        contentItem: Item {
            implicitWidth: imageCropper.implicitWidth + 2 * (Theme.bigPadding + Theme.halfPadding / 2)
            implicitHeight: imageCropper.implicitHeight + 2 * Theme.bigPadding

            StatusImageCropPanel {
                id: imageCropper
                objectName: "profileImageCropper"

                implicitHeight: root.roundedImage ? 350 : 370

                anchors {
                    fill: parent
                    leftMargin: Theme.bigPadding + Theme.halfPadding / 2
                    rightMargin: Theme.bigPadding + Theme.halfPadding / 2
                    topMargin: Theme.bigPadding
                    bottomMargin: Theme.bigPadding
                }

                margins: root.roundedImage ? 10 : 20
                windowStyle: root.roundedImage ? StatusImageCrop.WindowStyle.Rounded : StatusImageCrop.WindowStyle.Rectangular
                enableCheckers: true
            }
        }

        rightButtons: [
            StatusButton {
                objectName: "imageCropperAcceptButton"
                text: root.acceptButtonText

                enabled: imageCropper.sourceSize.width > 0 && imageCropper.sourceSize.height > 0

                onClicked: {
                    root.imageCropped(imageCropper.source, imageCropper.cropRect)
                    imageCropperModal.close()
                }
            }
        ]
        onClosed: root.done()
    } // StatusModal
} // Item
