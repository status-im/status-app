import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Onboarding.components

import utils

import shared.popups

OnboardingPage {
    id: root

    required property string mnemonic
    property bool popupMode

    property alias seedphraseRevealed: d.seedphraseRevealed

    title: qsTr("Show recovery phrase")

    signal backupSeedphraseConfirmed()

    QtObject {
        id: d
        property bool seedphraseRevealed
        readonly property var mnemonicWords: Utils.splitWords(root.mnemonic)
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
                text: qsTr("A 12-word phrase that gives full access to your funds and is the only way to recover them.")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: seedGrid.height

                GridLayout {
                    objectName: "seedGrid"
                    id: seedGrid
                    width: parent.width
                    columns: 2
                    columnSpacing: Theme.halfPadding
                    rowSpacing: columnSpacing

                    Repeater {
                        model: d.mnemonicWords
                        delegate: Frame {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            padding: Theme.smallPadding
                            background: Rectangle {
                                radius: Theme.radius
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.palette.baseColor2
                            }
                            contentItem: RowLayout {
                                spacing: Theme.halfPadding
                                StatusBaseText {
                                    Layout.preferredWidth: idxMetrics.advanceWidth
                                    horizontalAlignment: Qt.AlignHCenter
                                    text: index + 1
                                    color: Theme.palette.baseColor1
                                    font: idxMetrics.font
                                }
                                StatusBaseText {
                                    objectName: "seedWordText_" + (index+1)
                                    Layout.fillWidth: true
                                    text: modelData
                                    Accessible.role: Accessible.StaticText
                                    Accessible.name: SQUtils.Utils.formatAccessibleName(modelData, objectName)
                                }
                            }
                        }
                    }
                    layer.enabled: !d.seedphraseRevealed
                    layer.effect: GaussianBlur {
                        radius: 16
                        samples: 33
                        transparentBorder: true
                    }
                }

                StatusButton {
                    objectName: "btnReveal"
                    anchors.centerIn: parent
                    text: qsTr("Reveal recovery phrase")
                    icon.name: "show"
                    type: StatusBaseButton.Type.Primary
                    visible: !d.seedphraseRevealed
                    onClicked: {
                        const services = SystemUtils.activeThirdPartyA11yServices()
                        if (services.length > 0) {
                            a11yWarningPopup.serviceNames = services
                            a11yWarningPopup.open()
                        } else {
                            d.seedphraseRevealed = true
                        }
                    }
                }
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Never share your recovery phrase. If someone asks for it, they’re likely trying to scam you.\n\nTo backup you recovery phrase, write it down and store it securely in a safe place.")
                font.pixelSize: Theme.additionalTextSize
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            StatusButton {
                objectName: "btnConfirm"
                Layout.alignment: Qt.AlignHCenter
                visible: !root.popupMode
                text: qsTr("Confirm recovery phrase")
                enabled: d.seedphraseRevealed
                onClicked: {
                    root.backupSeedphraseConfirmed()
                    d.seedphraseRevealed = false
                }
            }
        }
    }

    AccessibilityWarningPopup {
        id: a11yWarningPopup
        onRevealAccepted: d.seedphraseRevealed = true
    }

    TextMetrics {
        id: idxMetrics
        font.family: Fonts.monoFont.family
        font.pixelSize: Theme.primaryTextFontSize
        text: "99"
    }
}
