import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

ColumnLayout {
    id: root

    spacing: Constants.settingsSection.itemSpacing

    Image {
        Layout.alignment: Qt.AlignCenter
        Layout.preferredHeight: 240
        Layout.preferredWidth: 350
        fillMode: Image.PreserveAspectFit
        antialiasing: true
        source: Assets.png("keycard/card_insert/insert")
        mipmap: true
        cache: false
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.halfPadding
    }

    StatusBaseText {
        objectName: "settings_Keycard_MainView_Description"
        Layout.alignment: Qt.AlignCenter
        font.pixelSize: Theme.fontSize(18)
        color: Theme.palette.directColor1
        text: qsTr("Secure your funds. Keep your profile safe.")
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.halfPadding
    }

    StatusButton {
        objectName: "settings_Keycard_MainView_GetKeycardButton"
        Layout.alignment: Qt.AlignHCenter
        type: StatusBaseButton.Type.Primary
        text: qsTr("Get Keycard")
        onClicked: Global.requestOpenLink(Constants.keycard.general.purchasePage)
    }
}
