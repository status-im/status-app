pragma ComponentBehavior: Bound

import QtQuick

import AppLayouts.Onboarding.pages
import AppLayouts.Onboarding.enums

OnboardingStackView {
    id: root

    enum Type {
        NewProfile,
        KeycardRecovery,
        Login
    }

    required property int type

    // functions
    required property var passwordStrengthScoreFunction // (string) => int
    required property var isSeedPhraseValid // (string) => bool
    required property var isSeedPhraseDuplicate // (string) => bool

    signal seedphraseSubmitted(string seedphrase)
    signal setPasswordRequested(string password)
    signal importLocalBackupRequested(url importFilePath)
    signal finished

    initialItem: type === UseRecoveryPhraseFlow.Type.KeycardRecovery ? conversionAckPage : seedPhrasePage

    Component {
        id: conversionAckPage
        ConvertKeycardAccountAcksPage {
            onContinueRequested: root.push(seedPhrasePage)
        }
    }

    Component {
        id: seedPhrasePage
        SeedphrasePage {
            title: {
                switch (root.type) {
                case UseRecoveryPhraseFlow.Type.NewProfile:
                    return qsTr("Create profile using a recovery phrase")
                case UseRecoveryPhraseFlow.Type.KeycardRecovery:
                    return qsTr("Enter recovery phrase of lost Keycard")
                case UseRecoveryPhraseFlow.Type.Login:
                    return qsTr("Log in with your Status recovery phrase")
                }

                return ""
            }

            onSeedphraseProvided: seedPhrase => {
                const seedPhraseStr = seedPhrase.join(" ")
                const valid = root.isSeedPhraseValid(seedPhraseStr)

                if (root.type === UseRecoveryPhraseFlow.Type.KeycardRecovery) {
                    setSeedPhraseError(valid ? "" : qsTr("Recovery phrase doesn’t match the profile of an existing Keycard user on this device"))
                } else {  // different error messages when trying to import a duplicate seedphrase
                    const isDuplicate = root.isSeedPhraseDuplicate(seedPhraseStr)

                    if (valid && isDuplicate) {
                        setSeedPhraseError(qsTr("The entered recovery phrase is already added"))
                    } else if (!valid) {
                        setSeedPhraseError(qsTr("Invalid recovery phrase"))
                    } else {
                        setSeedPhraseError("")
                    }
                }
            }

            onSeedphraseSubmitted: function(seedphrase) {
                root.seedphraseSubmitted(seedphrase)
                root.push(createPasswordPage)
            }
        }
    }

    Component {
        id: createPasswordPage

        CreatePasswordPage {
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction

            onSetPasswordRequested: function(password) {
                root.setPasswordRequested(password)
                if (root.type === UseRecoveryPhraseFlow.Type.Login)
                    root.push(importLocalBackupPage)
                else
                    root.finished()
            }
        }
    }

    Component {
        id: importLocalBackupPage
        ImportLocalBackupPage {
            onImportLocalBackupRequested: function(importFilePath) {
                root.importLocalBackupRequested(importFilePath)
                root.finished()
            }
            onSkipRequested: root.finished()
        }
    }
}
