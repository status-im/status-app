import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import utils

import "../stores"

Item {
    id: root

    property AddAccountStore store

    property bool isKeycardEnabled: true

    signal continueOnKeycard()

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.padding

        StatusListItem {
            title: qsTr("Add new master key")
            enabled: false
        }

        StatusListItem {
            objectName: "AddAccountPopup-ImportUsingSeedPhrase"
            title: qsTr("Import using recovery phrase")
            asset {
                name: "key_pair_seed_phrase"
                color: Theme.palette.primaryColor1
                bgColor: Theme.palette.primaryColor3
            }
            components: [
                StatusIcon {
                    icon: "tiny/chevron-right"
                    color: Theme.palette.baseColor1
                }
            ]

            onClicked: {
                root.store.cleanSeedPhrase()
                root.store.currentState.doPrimaryAction()
            }
        }

        StatusListItem {
            objectName: "AddAccountPopup-ImportPrivateKey"
            title: qsTr("Import private key")
            asset {
                name: "objects"
                color: Theme.palette.primaryColor1
                bgColor: Theme.palette.primaryColor3
            }
            components: [
                StatusIcon {
                    icon: "tiny/chevron-right"
                    color: Theme.palette.baseColor1
                }
            ]

            onClicked: {
                root.store.cleanPrivateKey()
                root.store.currentState.doSecondaryAction()
            }
        }

        StatusListItem {
            objectName: "AddAccountPopup-GenerateNewMasterKey"
            title: qsTr("Generate new master key")
            asset {
                name: "objects"
                color: Theme.palette.primaryColor1
                bgColor: Theme.palette.primaryColor3
            }
            components: [
                StatusIcon {
                    icon: "tiny/chevron-right"
                    color: Theme.palette.baseColor1
                }
            ]

            onClicked: {
                root.store.resetStoreValues()
                root.store.currentState.doTertiaryAction()
            }
        }

        StatusModalDivider {
            width: parent.width
        }

        StatusListItem {
            title: qsTr("Use Keycard")
            enabled: root.isKeycardEnabled
            sensor.enabled: false
            sensor.hoverEnabled: false
            statusListItemIcon.enabled: false
            statusListItemIcon.hoverEnabled: false
            asset {
                name: "keycard"
                color: Theme.palette.primaryColor1
                bgColor: Theme.palette.primaryColor3
            }
            components: [
                StatusButton {
                    objectName: "AddAccountPopup-GoToKeycardSettings"
                    text: qsTr("Continue in Keycard settings")
                    onClicked: {
                        root.continueOnKeycard()
                        Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.keycardNew)
                    }
                }
            ]
        }
    }
}
