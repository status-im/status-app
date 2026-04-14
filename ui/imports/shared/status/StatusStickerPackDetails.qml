import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import shared.panels

Control {
    id: root

    property string packThumb: "QmfZrHmLR5VvkXSDbArDR3TX6j4FgpDcrvNz2fHSJk1VvG"
    property string packName: "Status Cat"
    property string packAuthor: "cryptoworld1373"
    property int packNameFontSize: Theme.primaryTextFontSize

    padding: Theme.padding

    contentItem: RowLayout {
        spacing: root.spacing

        RoundedImage {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            source: root.packThumb
        }

        ColumnLayout {
            Layout.fillWidth: true
            StatusBaseText {
                Layout.fillWidth: true
                text: root.packName
                font.weight: Font.Medium
                font.pixelSize: root.packNameFontSize
            }
            StatusBaseText {
                Layout.fillWidth: true
                color: Theme.palette.secondaryText
                text: root.packAuthor
                font.pixelSize: Theme.primaryTextFontSize
            }
        }
    }
}
