import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import utils

StatusCenteredFlow {
    id: root

    required property string serviceProviderName
    required property string txProviderTool
    signal linkClicked()

    spacing: 4

    StatusBaseText {
        font.pixelSize: Theme.additionalTextSize
        text: qsTr("Powered by")
    }
    StatusLinkText {
        text: "%1.".arg(root.serviceProviderName)
        font.weight: Font.Normal
        textFormat: Text.PlainText
        onClicked: root.linkClicked()
    }
    StatusBaseText {
        font.pixelSize: Theme.additionalTextSize
        text: qsTr("via %1").arg(root.txProviderTool)
    }
}
