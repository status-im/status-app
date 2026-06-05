import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Controls

import AppLayouts.Onboarding.pages

StatusDialog {
    id: root

    required property string mnemonic

    readonly property alias stack: stack

    signal backupSeedphraseFinished(bool removeSeedphrase)

    title: stack.currentItem.title

    padding: Theme.halfPadding
    implicitWidth: 480
    implicitHeight: 700
    fillHeightOnBottomSheet: true

    footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusBackButton {
                id: backButton
                visible: stack.depth > 1
                onClicked: stack.popCurrentItem()
            }
        }
        rightButtons: ObjectModel {
            StatusButton {
                text: stack.currentItem.nextButtonText
                enabled: stack.currentItem.canGoNext
                onClicked: stack.currentItem.nextAction()
            }
        }
    }

    onAboutToShow: stack.popToIndex(0, StackView.Immediate) // reset if we closed in the middle of the flow

    StackView {
        id: stack
        anchors.fill: parent
        clip: true
        initialItem: backupSeedRevealPage
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        enabled: backButton.visible
        cursorShape: undefined // fall thru
        onClicked: stack.popCurrentItem()
    }

    Component {
        id: backupSeedRevealPage
        BackupSeedphraseReveal {
            readonly property string nextButtonText: qsTr("I've backed up phrase")
            readonly property bool canGoNext: seedphraseRevealed
            readonly property var nextAction: () => { stack.push(backupSeedVerifyPage) }
            StackView.onVisibleChanged: seedphraseRevealed = false // reset the "Reveal ..." button state

            mnemonic: root.mnemonic
            popupMode: true
        }
    }

    Component {
        id: backupSeedVerifyPage
        BackupSeedphraseVerify {
            readonly property string nextButtonText: qsTr("Continue")
            readonly property bool canGoNext: allValid
            readonly property var nextAction: () => { stack.push(backupSeedOutroPage) }

            mnemonic: root.mnemonic
            countToVerify: 4
            popupMode: true
            onBackupSeedphraseVerified: nextAction() // auto transition; everything valid and Enter/Return hit
        }
    }

    Component {
        id: backupSeedOutroPage
        BackupSeedphraseKeepOrDelete {
            readonly property string nextButtonText: qsTr("Done")
            readonly property bool canGoNext: true
            readonly property var nextAction: () => {
                                                  root.backupSeedphraseFinished(removeSeedphrase)
                                                  root.close()
                                              }
        }
    }
}
