import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Onboarding.enums

OnboardingPage {
    id: root

    required property int syncState // Onboarding.LocalPairingState.xxx

    signal loginToAppRequested()
    signal restartSyncRequested()
    signal loginWithSeedphraseRequested()

    states: [
        State {
            name: "inprogress"
            when: root.syncState === Onboarding.LocalPairingState.Transferring || root.syncState === Onboarding.LocalPairingState.Idle
            PropertyChanges {
                root.title: qsTr("Profile sync in progress...")
            }
            PropertyChanges {
                subtitle.text: qsTr("Your profile data is being synced to this device")
            }
            PropertyChanges {
                iconLoader.sourceComponent: loadingIndicator
            }
            PropertyChanges {
                image.source: Assets.png("onboarding/status_sync_progress")
            }
            PropertyChanges {
                subImageText.text: qsTr("Please keep both devices switched on and connected to the same network until the sync is complete")
                subImageText.visible: true
            }
        },
        State {
            name: "success"
            when: root.syncState === Onboarding.LocalPairingState.Finished
            PropertyChanges {
                root.title: qsTr("Profile synced")
            }
            PropertyChanges {
                subtitle.text: qsTr("Your profile data has been synced to this device")
            }
            PropertyChanges {
                iconLoader.sourceComponent: successIcon
            }
            PropertyChanges {
                image.source: Assets.png("onboarding/status_sync_success")
            }
            PropertyChanges {
                loginButton.visible: true
            }
        },
        State {
            name: "failed"
            when: root.syncState === Onboarding.LocalPairingState.Error
            PropertyChanges {
                root.title: "<font color='%1'>".arg(Theme.palette.dangerColor1) + qsTr("Failed to pair devices") + "</font>"
            }
            PropertyChanges {
                subtitle.text: qsTr("Try again and double-check the instructions")
            }
            PropertyChanges {
                iconLoader.sourceComponent: failedIcon
            }
            PropertyChanges {
                image.source: Assets.png("onboarding/status_sync_failed")
            }
            PropertyChanges {
                tryAgainButton.visible: true
            }
            PropertyChanges {
                loginWithSeedphraseButton.visible: true
            }
        }
    ]

    contentItem: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(400, root.availableWidth)
            spacing: Theme.halfPadding

            Loader {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignHCenter
                id: iconLoader
            }

            StatusBaseText {
                Layout.fillWidth: true
                font.pixelSize: Theme.fontSize(22)
                font.bold: true
                wrapMode: Text.WordWrap
                text: root.title
                horizontalAlignment: Text.AlignHCenter
            }
            StatusBaseText {
                id: subtitle
                Layout.fillWidth: true
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StatusImage {
                id: image
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(224, parent.width)
                Layout.preferredHeight: Math.min(214, height)
                Layout.topMargin: Theme.bigPadding
                Layout.bottomMargin: Theme.bigPadding
                source: Assets.png("onboarding/status_generate_keys")
                mipmap: true
            }

            StatusBaseText {
                id: subImageText
                Layout.fillWidth: true
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                visible: false
            }

            StatusButton {
                objectName: "btnLogin"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 240
                id: loginButton
                text: qsTr("Log in")
                visible: false
                onClicked: root.loginToAppRequested()
            }

            StatusButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 240
                id: tryAgainButton
                text: qsTr("Try to pair again")
                visible: false
                onClicked: root.restartSyncRequested()
            }

            StatusButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 240
                id: loginWithSeedphraseButton
                text: qsTr("Log in via recovery phrase")
                visible: false
                isOutline: true
                onClicked: root.loginWithSeedphraseRequested()
            }
        }
    }

    Component {
        id: loadingIndicator
        Rectangle {
            color: Theme.palette.baseColor2
            radius: width/2
            StatusDotsLoadingIndicator {
                anchors.centerIn: parent
            }
        }
    }

    Component {
        id: successIcon
        StatusRoundIcon {
            asset.name: "check-circle"
            asset.color: Theme.palette.successColor1
            asset.bgColor: Theme.palette.successColor2
        }
    }

    Component {
        id: failedIcon
        StatusRoundIcon {
            asset.name: "close-circle"
            asset.color: Theme.palette.dangerColor1
            asset.bgColor: Theme.palette.dangerColor3
        }
    }
}
