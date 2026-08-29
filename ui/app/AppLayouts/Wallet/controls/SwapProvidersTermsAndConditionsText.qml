import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import utils

StatusCenteredFlow {
    id: root

    required property string serviceProviderName
    signal linkClicked()
    signal termsAndConditionClicked()

    spacing: 4

    StatusIcon {
        width: 16
        height: 16
        icon: "external-link"
        color: Theme.palette.directColor1
    }
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
        text: qsTr("View")
    }
    StatusLinkText {
        text: qsTr("Terms & Conditions")
        font.weight: Font.Normal
        onClicked: root.termsAndConditionClicked()
    }
}
