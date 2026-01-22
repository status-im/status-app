import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Onboarding.controls

import utils

OnboardingPage {
    id: root

    required property bool networkChecksEnabled

    property bool isKeycardEnabled: true

    title: qsTr("Log in")

    signal loginWithSeedphraseRequested()
    signal loginWithSyncingRequested()
    signal loginWithKeycardRequested()

    contentItem: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(380, root.availableWidth)
            spacing: Theme.bigPadding

            StatusBaseText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Theme.fontSize22
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            StatusBaseText {
                Layout.fillWidth: true
                Layout.topMargin: -Theme.padding
                text: qsTr("How would you like to log in to Status?")
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
                        Layout.preferredWidth: Math.min(250, parent.width)
                        Layout.preferredHeight: Math.min(250, height)
                        source: Theme.png("onboarding/status_login_seedphrase")
                        mipmap: true
                    }
                    StatusBaseText {
                        Layout.fillWidth: true
                        text: qsTr("Log in with recovery phrase")
                        font.pixelSize: Theme.secondaryAdditionalTextSize
                        font.bold: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StatusBaseText {
                        Layout.fillWidth: true
                        Layout.topMargin: -Theme.padding
                        text: qsTr("If you have your Status recovery phrase")
                        font.pixelSize: Theme.additionalTextSize
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.palette.baseColor1
                    }
                    StatusButton {
                        objectName: "btnWithSeedphrase"
                        Layout.fillWidth: true
                        text: qsTr("Enter recovery phrase")
                        font.pixelSize: Theme.additionalTextSize
                        onClicked: root.loginWithSeedphraseRequested()
                    }
                }
            }

            OnboardingButtonFrame {
                Layout.fillWidth: true
                id: buttonFrame
                contentItem: ColumnLayout {
                    spacing: 0
                    ListItemButton {
                        objectName: "btnBySyncing"
                        Layout.fillWidth: true
                        text: qsTr("Log in by syncing") // FIXME wording, "Log in by pairing"?
                        subTitle: qsTr("If you have Status on another device")
                        icon.source: Theme.png("onboarding/login_syncing")
                        onClicked: loginWithSyncAck.createObject(root).open()
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: -buttonFrame.padding
                        Layout.rightMargin: -buttonFrame.padding
                        Layout.preferredHeight: 1
                        color: Theme.palette.statusMenu.separatorColor
                        visible: root.isKeycardEnabled
                    }
                    ListItemButton {
                        objectName: "btnWithKeycard"
                        Layout.fillWidth: true
                        text: qsTr("Log in with Keycard")
                        subTitle: qsTr("If your profile keys are stored on a Keycard")
                        icon.source: Theme.png("onboarding/create_profile_keycard")
                        onClicked: root.loginWithKeycardRequested()
                        visible: root.isKeycardEnabled
                    }
                }
            }
        }
    }

    NetworkChecker {
        id: netChecker
        active: root.networkChecksEnabled
    }

    Component {
        id: loginWithSyncAck
        StatusDialog {
            objectName: "loginWithSyncAckPopup"
            id: loginWithSyncAckPopup
            title: qsTr("Log in by syncing")
            width: 480
            padding: 20
            destroyOnClose: true

            LocalNetworkPermission {
                id: localNetworkPermission
                onStatusChanged: {
                    iosLocalNetworkSwitch.checked = (localNetworkPermission.status === LocalNetworkPermission.Granted)
                }
            }

            contentItem: ColumnLayout {
                spacing: 20
                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("To pair your devices and sync your profile, make sure to check and complete the following steps:")
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.padding
                    StatusCheckBox {
                        objectName: "ack1"
                        Layout.fillWidth: true
                        id: ack1
                        text: qsTr("Connect both devices to the same network")
                    }
                    StatusCheckBox {
                        objectName: "ack2"
                        Layout.fillWidth: true
                        id: ack2
                        text: qsTr("Make sure you are logged in on the other device")
                    }
                    StatusCheckBox {
                        objectName: "ack3"
                        Layout.fillWidth: true
                        id: ack3
                        text: qsTr("Disable the firewall and VPN on both devices")
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.padding
                        visible: SQUtils.Utils.isIOS

                        StatusSwitch {
                            objectName: "iosLocalNetworkSwitch"
                            id: iosLocalNetworkSwitch
                            Layout.fillWidth: true
                            text: qsTr("Local network access")
                            enabled: localNetworkPermission.status === LocalNetworkPermission.Unknown
                            Binding {
                                target: iosLocalNetworkSwitch
                                property: "checked"
                                value: localNetworkPermission.status === LocalNetworkPermission.Granted
                                restoreMode: Binding.RestoreBinding
                            }
                            onToggled: {
                                if (checked) {
                                    // The switch should be checked only by the permission request.
                                    checked = false
                                    localNetworkPermission.request()
                                }
                            }
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.baseColor1
                            textFormat: Text.RichText
                            text: qsTr("Enable access to local network to pair with your other device in your network. Local network permissions can be managed in %1iOS Settings → Status → Local Network%2.").arg(`<a href="app-settings:">`).arg(`</a>`)
                            onLinkActivated: (link) => {
                                Qt.openUrlExternally(link)
                            }
                        }
                    }
                }
            }
            footer: StatusDialogFooter {
                spacing: Theme.padding
                rightButtons: ObjectModel {
                    StatusFlatButton {
                        text: qsTr("Cancel")
                        onClicked: close()
                    }
                    StatusButton {
                        objectName: "btnContinue"
                        text: qsTr("Continue")
                        enabled: ack1.checked
                                 && ack2.checked
                                 && ack3.checked
                                 && (!SQUtils.Utils.isIOS || localNetworkPermission.status === LocalNetworkPermission.Granted)
                        onClicked: {
                            if (root.networkChecksEnabled && !netChecker.isOnline) {
                                networkCheckPopup.createObject(root, {netChecker}).open()
                            } else {
                                root.loginWithSyncingRequested()
                            }
                            close()
                        }
                    }
                }
            }
        }
    }



    Component {
        id: networkCheckPopup
        StatusDialog {
            objectName: "networkCheckPopup"
            title: qsTr("Status does not have access to local network")
            width: 480
            padding: 20
            destroyOnClose: true

            required property var netChecker

            contentItem: ColumnLayout {
                spacing: 20
                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("Status must be connected to the local network on this device for you to be able to log in via syncing. To rectify this...")
                }
                OnboardingFrame {
                    Layout.fillWidth: true
                    dropShadow: false
                    cornerRadius: Theme.radius
                    horizontalPadding: 20
                    verticalPadding: 12
                    contentItem: ColumnLayout {
                        spacing: 12
                        StatusBaseText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.baseColor1
                            text: qsTr("1. Open System Settings")
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.baseColor1
                            text: qsTr("2. Click Privacy & Security")
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.baseColor1
                            text: qsTr("3. Click Local Network")
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.baseColor1
                            text: qsTr("4. Find Status")
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.baseColor1
                            text: qsTr("5. Toggle the switch to grant access")
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.baseColor1
                            text: qsTr("6. Click %1 below").arg(`<font color="${Theme.palette.directColor1}">` +
                                                                qsTr("Verify local network access") +
                                                                "</font>")
                        }
                    }
                }
            }
            footer: StatusDialogFooter {
                spacing: Theme.padding
                rightButtons: ObjectModel {
                    StatusFlatButton {
                        text: qsTr("Cancel")
                        onClicked: close()
                    }
                    StatusButton {
                        objectName: "btnVerifyNet"
                        text: loading ? qsTr("Verifying") : qsTr("Verify local network access")
                        loading: netChecker.checking
                        interactive: !loading
                        onClicked: netChecker.checkNetwork()
                    }
                }
            }
            Connections {
                target: netChecker
                function onIsOnlineChanged() {
                    if (netChecker.isOnline) {
                        root.loginWithSyncingRequested()
                        close()
                    }
                }
            }
        }
    }
}
