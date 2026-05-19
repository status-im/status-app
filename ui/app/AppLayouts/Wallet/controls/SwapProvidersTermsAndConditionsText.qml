import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import utils

RowLayout {
    id: root

    required property string serviceProviderName
    signal linkClicked()
    signal termsAndConditionClicked()

    spacing: 4

    StatusIcon {
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16
        icon: "external-link"
        color: Theme.palette.directColor1
    }
    StatusBaseText {
        font.pixelSize: Theme.additionalTextSize
        text: qsTr("Powered by")
    }
    StatusLinkText {
        Layout.topMargin: 1 // compensate for the underline
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
        Layout.topMargin: 1 // compensate for the underline
        text: qsTr("Terms & Conditions")
        font.weight: Font.Normal
        onClicked: root.termsAndConditionClicked()
    }
}
