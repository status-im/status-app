import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import shared.views
import AppLayouts.Profile.stores
import AppLayouts.Profile.views

import utils

import StatusQ
import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    StackLayout {
        id: wrapper
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ChangePasswordView {
            id: passwordView

            contentWidth: panelWidth.value

            sectionTitle: "Password"

            passwordStrengthScoreFunction: (newPass) => Math.min(newPass.length-1, 4)

            privacyStore: PrivacyStore {
                property QtObject privacyModule: QtObject {
                    signal passwordChanged(success: bool, errorMsg: string)
                    signal saveBiometricsRequested(string keyUid, string credential)

                    function changePassword(password, newPassword, rekey = false) {
                        passwordChanged(ctrlChangePassSuccess.checked,
                                        ctrlChangePassSuccess.checked ? "" : "Err changing password")
                    }

                    function isProfileMigratedToDEKEncryption() {
                        return ctrlFastPasswordChange.checked
                    }
                }

                readonly property string keyUid: keyUidInput.text

                function tryStoreToKeyChain(errorDescription) {
                    privacyModule.saveBiometricsRequested(keyUid, passwordInput.text)
                }
            }

            keychain: loader.item
        }
    }

    Loader {
        id: loader

        sourceComponent: useMockedKeychainCheckBox.checked ? mockedKeychainComponent
                                                           : nativeKeychainComponent
    }

    Component {
        id: nativeKeychainComponent

        Keychain {
            service: "StatusStorybook"
        }
    }

    Component {
        id: mockedKeychainComponent

        KeychainMock {
            parent: root
            available: keychainAvailableCheckBox.checked
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 150

        logsView.logText: logs.logText

        ColumnLayout {
            Slider {
                id: panelWidth

                from: 200
                to: 700
                value: 365
            }
            RowLayout {
                Switch {
                    id: ctrlChangePassSuccess
                    text: "Password change will succeed"
                    checked: true
                }
                Switch {
                    id: ctrlFastPasswordChange
                    text: "DEK / fast password change"
                    checked: true
                }
            }

            RowLayout {
                Switch {
                    id: useMockedKeychainCheckBox
                    text: "Use Keychain mock"
                    checked: Qt.platform.os !== "osx"
                }
                Switch {
                    id: keychainAvailableCheckBox
                    text: "Keychain available (mocked only)"
                    enabled: useMockedKeychainCheckBox.checked
                }
            }

            RowLayout {
                Text {
                    text: "KeyUID: "
                }
                TextField {
                    id: keyUidInput
                    text: "0x42"
                }
                Text {
                    text: "Password: "
                }
                TextField {
                    id: passwordInput
                    text: "123456"
                }
            }
        }
    }
}

// category: Views
// status: good
// https://www.figma.com/file/d0G7m8X6ELjQlFOEKQpn1g/Profile-WIP?type=design&node-id=11-115317&mode=design&t=mBpxe2bJKzpseHGN-0
