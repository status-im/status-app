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

    readonly property bool removeSeedphrase: cbRemove.checked

    title: qsTr("Keep or delete recovery phrase")

    contentItem: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(440, root.availableWidth)
            spacing: Theme.xlPadding

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Decide whether you want to keep the recovery phrase in your Status app for future access or remove it permanently.")
                wrapMode: Text.WordWrap
            }

            StatusImage {
                id: image
                Layout.preferredWidth: 296
                Layout.preferredHeight: 260
                Layout.alignment: Qt.AlignHCenter
                mipmap: true
                source: Assets.png("onboarding/status_login_seedphrase")
            }

            StatusCheckBox {
                objectName: "cbRemove"
                Layout.fillWidth: true
                id: cbRemove
                text: qsTr("Permanently remove your recovery phrase from the Status app — you will not be able to view it again")
            }
        }
    }
}
