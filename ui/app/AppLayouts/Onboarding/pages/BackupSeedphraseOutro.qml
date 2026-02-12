import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Onboarding.components

OnboardingPage {
    id: root

    signal backupSeedphraseRemovalConfirmed()

    contentItem: ColumnLayout {
        id: layout
        spacing: Theme.xlPadding

        StatusBaseText {
            Layout.fillWidth: true
            text: qsTr("Confirm backup")
            font.pixelSize: Theme.fontSize(22)
            font.bold: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Ensure you have written down your recovery phrase and have a safe place to keep it. Remember, anyone who has your recovery phrase has access to your funds.")
        }

        StatusImage {
            Layout.preferredWidth: 296
            Layout.preferredHeight: 260
            Layout.alignment: Qt.AlignHCenter
            source: Assets.png("keycard/card_inserted/reading")
        }

        StatusCheckBox {
            objectName: "cbAck"
            id: cbAck
            text: qsTr("I understand my recovery phrase will now be removed and I will no longer be able to access it via Status")
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: layout.width
        }

        StatusButton {
            objectName: "btnContinue"
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Continue")
            enabled: cbAck.checked
            onClicked: root.backupSeedphraseRemovalConfirmed()
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
