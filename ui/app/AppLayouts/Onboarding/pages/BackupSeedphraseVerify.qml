import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Onboarding.components

import shared
import utils

import SortFilterProxyModel

OnboardingPage {
    id: root

    required property string mnemonic
    required property int countToVerify
    property bool popupMode

    readonly property var verificationWordsMap: d.verificationWordsMap
    readonly property bool allValid: seedRepeater.allValid

    signal backupSeedphraseVerified()

    title: qsTr("Confirm recovery phrase")

    QtObject {
        id: d
        readonly property var seedSuggestions: BIP39_en {} // [{seedWord:string}, ...]
        readonly property var verificationWordsMap: { // [{seedWordNumber:int, seedWord:string}, ...]
            const words = Utils.splitWords(root.mnemonic)
            const randomIndexes = SQUtils.Utils.nSamples(root.countToVerify, words.length)
            return randomIndexes.map(i => ({
                                               seedWordNumber: i+1,
                                               seedWord: words[i]
                                           }))
        }
    }

    contentItem: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(440, root.availableWidth)
            spacing: Theme.xlPadding

            StatusBaseText {
                Layout.fillWidth: true
                text: root.title
                visible: !root.popupMode
                font.pixelSize: Theme.fontSize(22)
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Confirm these words from your recovery phrase...")
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.halfPadding
                Repeater {
                    readonly property bool allValid: {
                        for (let i = 0; i < count; i++) {
                            if (!!itemAt(i) && !itemAt(i).valid)
                                return false
                        }
                        return true
                    }

                    id: seedRepeater
                    model: d.verificationWordsMap
                    delegate: RowLayout {
                        required property var modelData
                        required property int index

                        readonly property bool valid: seedInput.valid
                        readonly property alias input: seedInput

                        Layout.fillWidth: true
                        Layout.topMargin: Theme.halfPadding
                        Layout.bottomMargin: Theme.halfPadding
                        spacing: 12
                        StatusBaseText {
                            Layout.preferredWidth: 20
                            text: modelData.seedWordNumber
                            horizontalAlignment: Text.AlignHCenter
                        }
                        SeedphraseVerifyInput {
                            readonly property int seedWordIndex: modelData.seedWordNumber - 1 // 0 based idx in the mnemonic
                            objectName: "seedInput_%1".arg(seedWordIndex)
                            Layout.fillWidth: true
                            id: seedInput
                            valid: text.trim().toLowerCase() === modelData.seedWord
                            seedSuggestions: d.seedSuggestions
                            Component.onCompleted: if (index === 0) forceActiveFocus()
                            onAccepted: {
                                if (seedRepeater.allValid) { // move to next page
                                    root.backupSeedphraseVerified()
                                } else { // move to next field
                                    const nextItem = seedRepeater.itemAt(index + 1) ?? seedRepeater.itemAt(0)
                                    if (!!nextItem) {
                                        nextItem.input.forceActiveFocus()
                                    }
                                }
                            }
                        }
                        StatusIcon {
                            id: statusIcon
                            width: 20
                            height: 20
                            icon: seedInput.text === "" ? "help" : seedInput.valid ? "checkmark-circle" : "warning"
                            color: seedInput.text === "" ? Theme.palette.baseColor1 : seedInput.valid ? Theme.palette.successColor1
                                                                                                      : Theme.palette.dangerColor1

                            HoverHandler {
                                id: hhandler
                                cursorShape: hovered ? Qt.PointingHandCursor : undefined
                            }
                            TapHandler {
                                onSingleTapped: seedInput.forceActiveFocus()
                            }
                            StatusToolTip {
                                text: seedInput.text === "" ? qsTr("Empty") : seedInput.valid ? qsTr("Correct word") : qsTr("Wrong word")
                                visible: hhandler.hovered && statusIcon.visible
                            }
                        }
                    }
                }
            }

            StatusButton {
                objectName: "btnContinue"
                Layout.alignment: Qt.AlignHCenter
                visible: !root.popupMode
                text: qsTr("Continue")
                enabled: seedRepeater.allValid
                onClicked: root.backupSeedphraseVerified()
            }
        }
    }
}
