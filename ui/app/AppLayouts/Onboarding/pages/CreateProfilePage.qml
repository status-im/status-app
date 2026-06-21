import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups

import AppLayouts.Onboarding.controls

import utils

OnboardingPage {
    id: root

    property bool isKeycardEnabled: true

    title: qsTr("Create profile")

    signal createProfileWithPasswordRequested()
    signal createProfileWithSeedphraseRequested()
    signal createProfileWithEmptyKeycardRequested()

    contentItem: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(380, root.availableWidth)
            spacing: Theme.bigPadding

            StatusBaseText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Theme.fontSize(22)
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            StatusBaseText {
                Layout.fillWidth: true
                Layout.topMargin: -Theme.padding
                text: qsTr("How would you like to start using Status?")
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            OnboardingFrame {
                Layout.fillWidth: true
                contentItem: ColumnLayout {
                    spacing: 20
                    StatusImage {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(164, parent.width)
                        Layout.preferredHeight: Math.min(164, height)
                        source: Assets.png("onboarding/status_key")
                        mipmap: true
                    }
                    StatusBaseText {
                        Layout.fillWidth: true
                        text: qsTr("Start fresh")
                        font.pixelSize: Theme.secondaryAdditionalTextSize
                        font.bold: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StatusBaseText {
                        Layout.fillWidth: true
                        Layout.topMargin: -Theme.padding
                        text: qsTr("Create a new profile from scratch")
                        font.pixelSize: Theme.additionalTextSize
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.palette.baseColor1
                    }
                    StatusButton {
                        objectName: "btnCreateWithPassword"
                        Layout.fillWidth: true
                        text: qsTr("Let’s go!")
                        font.pixelSize: Theme.additionalTextSize
                        onClicked: root.createProfileWithPasswordRequested()
                    }
                }
            }

            OnboardingButtonFrame {
                Layout.fillWidth: true
                id: buttonFrame
                contentItem: ColumnLayout {
                    spacing: 0
                    ListItemButton {
                        objectName: "btnCreateWithSeedPhrase"
                        Layout.fillWidth: true
                        text: qsTr("Use a recovery phrase")
                        subTitle: qsTr("If you already have an Ethereum wallet")
                        icon.source: Assets.png("onboarding/create_profile_seed")
                        onClicked: root.createProfileWithSeedphraseRequested()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.palette.statusMenu.separatorColor
                visible: root.isKeycardEnabled
            }

            OnboardingButtonFrame {
                Layout.fillWidth: true
                contentItem: ColumnLayout {
                    spacing: 0
                    ListItemButton {
                        objectName: "btnCreateWithEmptyKeycard"
                        Layout.fillWidth: true
                        text: qsTr("Use Keycard")
                        subTitle: qsTr("Reveal what you have on Keycard first")
                        icon.source: Assets.png("onboarding/create_profile_keycard")
                        onClicked: root.createProfileWithEmptyKeycardRequested()
                        visible: root.isKeycardEnabled
                    }
                }
            }
        }
    }
}
