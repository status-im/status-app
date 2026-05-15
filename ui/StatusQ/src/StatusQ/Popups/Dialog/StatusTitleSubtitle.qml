import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: root

    property alias title: title.text
    property alias subtitle: subtitle.text

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 0

        StatusBaseText {
            id: title

            Layout.fillWidth: true

            font {
                pixelSize: Theme.secondaryAdditionalTextSize
                bold: true
            }
            elide: Text.ElideMiddle
            textFormat: Text.PlainText
        }

        StatusBaseText {
            id: subtitle

            Layout.fillWidth: true

            visible: text !== ""
            color: Theme.palette.baseColor1
            elide: Text.ElideMiddle
            textFormat: Text.PlainText
        }
    }
}
