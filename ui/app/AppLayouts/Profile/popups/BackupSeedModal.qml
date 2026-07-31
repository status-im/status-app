import QtQuick
import QtQuick.Controls

import StatusQ.Popups.Dialog

import AppLayouts.Onboarding.pages

StatusAdaptiveStackDialog {
    id: root

    required property string mnemonic

    signal backupSeedphraseFinished(bool removeSeedphrase)

    implicitWidth: 480
    maximumWidthOverride: 480
    maximumHeightOverride: 700
    stackContentImplicitHeight: 560
    initialItem: backupSeedRevealPage

    onAboutToShow: resetStack(StackView.Immediate) // reset if we closed in the middle of the flow

    Component {
        id: backupSeedRevealPage
        BackupSeedphraseReveal {
            readonly property string nextButtonText: qsTr("I've backed up phrase")
            readonly property bool canGoNext: seedphraseRevealed
            readonly property var nextAction: () => { root.stack.push(backupSeedVerifyPage) }
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
            readonly property var nextAction: () => { root.stack.push(backupSeedOutroPage) }

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
