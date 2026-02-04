import QtQuick
import QtQuick.Layouts
import QtQml

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Onboarding.controls
import AppLayouts.Onboarding.enums

import utils

KeycardBasePage {
    id: root

    required property int keycardState // cf Onboarding.KeycardState
    property bool displayPromoBanner

    property bool unblockWithPukAvailable
    property bool unblockUsingSeedphraseAvailable
    property bool factoryResetAvailable

    signal keycardFactoryResetRequested()
    signal unblockWithSeedphraseRequested()
    signal unblockWithPukRequested()
    signal emptyKeycardDetected()
    signal notEmptyKeycardDetected()

    OnboardingFrame {
        id: promoBanner
        visible: false
        dropShadow: false
        cornerRadius: 12
        width: 600
        leftPadding: 0
        rightPadding: 20
        topPadding: Theme.halfPadding
        bottomPadding: 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.bigPadding

        contentItem: RowLayout {
            spacing: 0
            StatusImage {
                Layout.bottomMargin: -2
                Layout.preferredWidth: 154
                Layout.preferredHeight: 82
                source: Assets.png("onboarding/status_keycard_multiple")
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: -promoBanner.topPadding
                spacing: 2
                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("New to Keycard?")
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.DemiBold
                }
                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("Store and trade your crypto with a simple, secure and slim hardware wallet.")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.additionalTextSize
                    color: Theme.palette.baseColor1
                }
            }
            StatusButton {
                Layout.leftMargin: 20
                Layout.topMargin: -promoBanner.topPadding
                size: StatusBaseButton.Size.Small
                text: qsTr("keycard.tech")
                icon.name: "external-link"
                icon.width: 24
                icon.height: 24
                onClicked: requestOpenLink("https://keycard.tech/")
            }
        }
    }

    buttons: [
        MaybeOutlineButton {
            id: btnUnblockWithPuk
            visible: false
            text: qsTr("Unblock using PUK")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.unblockWithPukRequested()
        },
        MaybeOutlineButton {
            id: btnUnblockWithSeedphrase
            visible: false
            text: qsTr("Unblock with recovery phrase")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.unblockWithSeedphraseRequested()

            /////////////////////////////////////////////////////////////////////////////////
            // # Remove this once we implement unlock via PUK
            /////////////////////////////////////////////////////////////////////////////////
            enabled: false
            MouseArea {
                id: unlockWithSeedphraseArea
                anchors.fill: parent
                hoverEnabled: true
            }
            StatusToolTip {
                text: Constants.keycard.temporarilyUnavailable
                visible: unlockWithSeedphraseArea.containsMouse
            }
            /////////////////////////////////////////////////////////////////////////////////
        },
        MaybeOutlineButton {
            id: btnFactoryReset
            visible: false
            text: qsTr("Factory reset Keycard")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.keycardFactoryResetRequested()
        }
    ]

    states: [
        // normal/intro states
        State {
            name: "plugin"
            when: root.keycardState === Onboarding.KeycardState.PluginReader ||
                  root.keycardState === Onboarding.KeycardState.UnknownReaderState
            PropertyChanges {
                target: root
                title: qsTr("Plug in your Keycard reader")
                image.source: Assets.png("onboarding/keycard/empty")
            }
            PropertyChanges {
                target: promoBanner
                visible: root.displayPromoBanner
            }
        },
        State {
            name: "insert"
            when: root.keycardState === Onboarding.KeycardState.InsertKeycard
            PropertyChanges {
                target: root
                title: qsTr("Insert your Keycard")
                infoText.text: qsTr("Get help via %1 🔗").arg(Utils.getStyledLink("https://keycard.tech", "https://keycard.tech/docs/",
                                                                                infoText.hoveredLink,
                                                                                root.Theme.palette.baseColor1,
                                                                                root.Theme.palette.primaryColor1))
                image.source: Assets.png("onboarding/keycard/insert")
            }
        },
        State {
            name: "reading"
            when: root.keycardState === Onboarding.KeycardState.ReadingKeycard
            PropertyChanges {
                target: root
                title: qsTr("Reading Keycard...")
                image.source: Assets.png("onboarding/keycard/reading")
            }
        },
        // error states
        State {
            name: "notKeycard"
            when: root.keycardState === Onboarding.KeycardState.NotKeycard
            PropertyChanges {
                target: root
                title: qsTr("Oops this isn’t a Keycard")
                subtitle: qsTr("Remove card and insert a Keycard")
                image.source: Assets.png("onboarding/keycard/invalid")
            }
        },
        State {
            name: "noService"
            when: root.keycardState === Onboarding.KeycardState.NoPCSCService
            PropertyChanges {
                target: root
                title: qsTr("Smartcard reader service unavailable")
                subtitle: qsTr("The Smartcard reader service (PCSC service), required for using Keycard, is not currently working. Ensure PCSC is installed and running and try again.")
                image.source: Assets.png("onboarding/keycard/error")
            }
        },
        State {
            name: "occupied"
            when: root.keycardState === Onboarding.KeycardState.MaxPairingSlotsReached
            PropertyChanges {
                target: root
                title: qsTr("All pairing slots occupied")
                subtitle: qsTr("Factory reset this Keycard or insert a different one")
                image.source: Assets.png("onboarding/keycard/error")
            }
            PropertyChanges {
                target: btnFactoryReset
                visible: true
            }
        },
        State {
            name: "blockedPin"
            when: root.keycardState === Onboarding.KeycardState.BlockedPIN
            PropertyChanges {
                target: root
                title: "<font color='%1'>".arg(root.Theme.palette.dangerColor1) + qsTr("Keycard blocked") + "</font>"
                subtitle: qsTr("The Keycard you have inserted is blocked, you will need to unblock it or insert a different one")
                image.source: Assets.png("onboarding/keycard/error")
            }
            PropertyChanges {
                target: btnUnblockWithPuk
                visible: root.unblockWithPukAvailable
            }
            PropertyChanges {
                target: btnUnblockWithSeedphrase
                visible: root.unblockUsingSeedphraseAvailable
            }
            PropertyChanges {
                target: btnFactoryReset
                visible: root.factoryResetAvailable
            }
        },
        State {
            name: "blockedPuk"
            when: root.keycardState === Onboarding.KeycardState.BlockedPUK
            PropertyChanges {
                target: root
                title: "<font color='%1'>".arg(root.Theme.palette.dangerColor1) + qsTr("Keycard blocked") + "</font>"
                subtitle: qsTr("The Keycard you have inserted is blocked, you will need to unblock it, factory reset or insert a different one")
                image.source: Assets.png("onboarding/keycard/error")
            }
            PropertyChanges {
                target: btnUnblockWithSeedphrase
                visible: root.unblockUsingSeedphraseAvailable
            }
            PropertyChanges {
                target: btnFactoryReset
                visible: true
            }
        },
        // exit states
        State {
            name: "empty"
            when: root.keycardState === Onboarding.KeycardState.Empty
            StateChangeScript {
                script: root.emptyKeycardDetected()
            }
        },
        State {
            name: "notEmpty"
            when: root.keycardState === Onboarding.KeycardState.NotEmpty
            StateChangeScript {
                script: root.notEmptyKeycardDetected()
            }
        }
    ]
}
