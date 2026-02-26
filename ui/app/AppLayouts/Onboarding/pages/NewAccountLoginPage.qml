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
    required property bool thirdpartyServicesEnabled

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
                font.pixelSize: Theme.fontSize(22)
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
                        source: Assets.png("onboarding/status_login_seedphrase")
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
                        icon.source: Assets.png("onboarding/login_syncing")
                        onClicked: popupsLoader.goToLoginWithSyncAck()
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
                        icon.source: Assets.png("onboarding/create_profile_keycard")
                        onClicked: root.loginWithKeycardRequested()
                        visible: root.isKeycardEnabled
                    }
                }
            }
        }
    }

    NetworkChecker {
        id: netChecker
        active: root.networkChecksEnabled && root.thirdpartyServicesEnabled
    }

    Loader {
        id: popupsLoader
        property bool waitingForPermission: false
        function goToLoginWithSyncAck() {
            sourceComponent = loginWithSyncAck
            active = true
        }

        function goToLocalNetworkPermissionDenied() {
            sourceComponent = localNetworkPermissionDeniedPopup
            active = true
        }

        function goToNetworkCheck() {
            sourceComponent = networkCheckPopup
            active = true
        }

        function reset() {
            active = false
            sourceComponent = null
            waitingForPermission = false
        }

        active: false
    }

    Component {
        id: loginWithSyncAck
        CommonDialogComponent {
            objectName: "loginWithSyncAckPopup"
            id: loginWithSyncAckPopup
            title: qsTr("Log in by syncing")

            contentItem: ColumnLayout {
                spacing: 20
                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("To pair your devices and sync your profile, make sure:<br><ul><li>Both devices are on the same network</li><li>You're logged in on the other device</li><li>No firewall or VPN is blocking local network access</li></ul>")
                }
            }
            footer: StatusDialogFooter {
                bottomPadding: Theme.padding + loginWithSyncAckPopup.parent.SafeArea.margins.bottom
                spacing: Theme.padding
                rightButtons: ObjectModel {
                    StatusFlatButton {
                        text: qsTr("Cancel")
                        onClicked: close()
                    }
                    StatusButton {
                        id: btnContinue
                        objectName: "btnContinue"
                        
                        function tryAccept() {
                            if (localNetworkPermission.status === LocalNetworkPermission.Unknown) {
                                popupsLoader.waitingForPermission = true
                                localNetworkPermission.request()
                                return
                            }

                            if (localNetworkPermission.status === LocalNetworkPermission.Denied) {
                                popupsLoader.goToLocalNetworkPermissionDenied()
                                return
                            }

                            if (root.networkChecksEnabled && !netChecker.isOnline) {
                                popupsLoader.goToNetworkCheck()
                                return
                            }

                            root.loginWithSyncingRequested()
                            close()
                        }

                        text: popupsLoader.waitingForPermission ? qsTr("Checking access...") : qsTr("Continue")
                        enabled: !popupsLoader.waitingForPermission
                        onClicked: tryAccept()

                        LocalNetworkPermission {
                            id: localNetworkPermission
                            onStatusChanged: btnContinue.tryAccept()
                        }

                        Component.onCompleted: {
                            if (popupsLoader.waitingForPermission) {
                                btnContinue.tryAccept()
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: localNetworkPermissionDeniedPopup
        CommonDialogComponent {
            objectName: "localNetworkPermissionDeniedPopup"
            title: qsTr("Enable local network access to sync devices")

            contentItem: ColumnLayout {
                spacing: 20
                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("Turn on Local network access in your device settings under Settings >> Status >> Local Network.")
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
                        id: btnOpenSettings
                        objectName: "btnOpenSettings"
                        text: qsTr("Open Settings")
                        enabled: true
                        onClicked: {
                            Qt.openUrlExternally("app-settings:")
                            popupsLoader.goToLoginWithSyncAck()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: networkCheckPopup
        CommonDialogComponent {
            objectName: "networkCheckPopup"
            title: qsTr("Status does not have access to local network")

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

    component CommonDialogComponent: StatusDialog {
        width: 480
        padding: 20
        visible: true
        onClosed: () => popupsLoader.reset()
    }
}
