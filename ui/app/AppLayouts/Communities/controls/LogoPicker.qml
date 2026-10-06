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
import StatusQ.Popups
import StatusQ.Controls
import StatusQ.Controls.Validators

Item {
    id: root

    property alias source: editor.source
    property alias cropRect: editor.cropRect
    property alias imageData: editor.dataImage

    readonly property bool hasSelectedImage: localAppSettings.testEnvironment ? true : editor.userSelectedImage

    implicitHeight: layout.implicitHeight

    function validate() {
        editor.isError = !hasSelectedImage
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 16

        StatusBaseText {
            id: label
            Layout.fillWidth: true
            text: qsTr("Community logo")
            color: Theme.palette.directColor1
            horizontalAlignment: Qt.AlignLeft
        }

        EditCroppedImagePanel {
            id: editor

            Layout.preferredWidth: 128
            Layout.preferredHeight: Layout.preferredWidth / aspectRatio
            Layout.alignment: Qt.AlignHCenter

            imageFileDialogTitle: qsTr("Choose an image as logo")
            title: qsTr("Community logo")
            acceptButtonText: qsTr("Make this my Community logo")

            NoImageUploadedPanel {
                anchors.centerIn: parent

                visible: !editor.userSelectedImage && !root.imageData
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            visible: editor.isError
            text: qsTr("Upload a community logo")
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}

