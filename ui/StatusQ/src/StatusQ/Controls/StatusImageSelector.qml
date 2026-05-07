import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

/*!
   \qmltype StatusImageSelector
   \inherits Control
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Components 0.1
   \brief The It StatusImageSelector control provides a generic user image selector input

   Example of how the component looks like:
   \image status_image_selector.png

   Example of how to use it:
   \qml
        StatusImageSelector {
            Layout.preferredHeight: 500
            Layout.preferredWidth: 500
            labelText: qsTr("Artwork")
            uploadText: qsTr("Drag and Drop or Upload Artwork")
            additionalText: qsTr("Images only")

            onFileSelected: d.artworkSource = file
        }
   \endqml
   For a list of components available see StatusQ.
*/
Control {
    id: root

    /*!
       \qmlproperty alias StatusImageSelector::labelText.
       This property holds the label text for the file input.
    */
    property alias labelText: label.text

    /*!
       \qmlproperty alias StatusImageSelector::uploadText.
       This property holds the main image upload text value.
    */
    property alias uploadText: uploadText.text

    /*!
       \qmlproperty alias StatusImageSelector::additionalText.
       This property holds an additional text value.
    */
    property alias additionalText: additionalText.text

    /*!
       \qmlproperty var StatusImageSelector::acceptedImageExtensions.
       This property holds the list of possible image file extensions.
    */
    property var acceptedImageExtensions: [".png", ".jpg", ".jpeg"]

    /*!
       \qmlproperty bool StatusImageSelector::preview.
       This property holds if the component's behavior is just preview (true) the image or load (false).
    */
    property bool preview: false

    /*!
       \qmlproperty int StatusImageSelector::headerHeight.
       This property holds the header height value including label heigh  + spacing between label and image rectangle.
    */
    readonly property int headerHeight: label.implicitHeight + rootImageSelector.spacing

    /*!
       \qmlproperty int StatusImageSelector::buttonsInsideOffset.
       This property holds the plus button inside offset value.
    */
    readonly property int buttonsInsideOffset: 10

    /*!
       \qmlproperty alias StatusImageSelector::file.
       This property holds the image file source.
    */
    property alias file: image.source

    /*!
        \qmlsignal StatusImageSelector::fileSelected(url file)
        This signal is emitted when a new file is selected.
    */
    signal fileSelected(url file)

    QtObject {
        id: d

        readonly property int imageSelectorPadding: 75

        function loadFile(fileUrls) {
            if (fileUrls.length > 0) {

                // The first file is the one kept:
                if(d.isValidFile(fileUrls[0])) {
                    image.source = fileUrls[0]
                    uploadTextPanel.visible = false
                    root.fileSelected(fileUrls[0])
                }
            }
        }

        function isValidFile(file) {
            return root.acceptedImageExtensions.some(ext => file.toLowerCase().includes(ext))
        }

        function getExtensionsFilterText() {
            var res = ""
            for(var i = 0; i < root.acceptedImageExtensions.length; i++)
                res += " *" + root.acceptedImageExtensions[i]

            return res
        }
    }

    contentItem: ColumnLayout {
        id: rootImageSelector

        spacing: 16

        StatusBaseText {
            id: label

            elide: Text.ElideRight
            font.pixelSize: Theme.primaryTextFontSize
        }

        Rectangle {
            id: imageSelector

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: Theme.palette.baseColor2

            states: [
                State {
                    when: dropArea.containsDrag
                    PropertyChanges {target: imageSelector; border.color: Theme.palette.primaryColor1 }
                },
                State {
                    when: !dropArea.containsDrag
                    PropertyChanges {target: imageSelector; border.color: Theme.palette.baseColor2 }
                }
            ]

            DropArea {
                id: dropArea

                anchors.fill: parent
                enabled: !root.preview
                onDropped: d.loadFile(drop.urls)
            }

            StatusRoundButton {
                id: addButton

                z: 1
                visible: !preview
                icon.name: "add"
                type: StatusRoundButton.Type.Secondary
                anchors {
                    top: parent.top
                    topMargin: - root.buttonsInsideOffset
                    right: parent.right
                    rightMargin: - root.buttonsInsideOffset
                }

                onClicked: fileDialog.open()
            }

            ColumnLayout {
                id: uploadTextPanel

                width: parent.width
                anchors.centerIn: parent

                StatusIcon {
                    icon: "images_icon"
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 18
                    color: Theme.palette.baseColor1
                    fillMode: Image.PreserveAspectFit
                }

                StatusBaseText {
                    id: uploadText

                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    Layout.topMargin: 5
                    Layout.preferredWidth: parent.width - 2 * d.imageSelectorPadding
                    font.pixelSize: Theme.primaryTextFontSize
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                    horizontalAlignment: Text.AlignHCenter
                }

                StatusBaseText {
                    id: additionalText

                    visible: !!root.additionalText
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    Layout.preferredWidth: parent.width - 2 * d.imageSelectorPadding
                    font.pixelSize: Theme.secondaryTextFontSize
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Image {
                id: image

                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                cache: false
            }
        }
    }

    StatusFileDialog {
        id: fileDialog

        currentFolder: picturesShortcut
        usePhotoLibrary: true
        nameFilters: [ qsTr("Supported image formats (%1)").arg(d.getExtensionsFilterText())]
        onAccepted: d.loadFile(selectedFiles)
    }
}
