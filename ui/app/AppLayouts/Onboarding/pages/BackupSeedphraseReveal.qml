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

import shared.controls
import utils

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

    padding: 0

    StackView.onActivated: scrollView.scrollHome()

    StatusScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        flickable.topMargin: Math.max(0, flickable.height - contentHeight) / 2 // centering the content vertically

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(440, scrollView.availableWidth) // don't take full width if not needed
            spacing: Theme.smallPadding

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
                text: qsTr("A 12-word phrase that gives full access to your funds and is the only way to recover them. Make sure nothing can see or record your screen.")
                wrapMode: Text.WordWrap
            }

            A11YInformationTag {
                Layout.fillWidth: true
                visible: !d.seedphraseRevealed
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
                        radius: samples/2 - 1
                        samples: 64
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
                        d.seedphraseRevealed = true
                    }
                }
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Never share your recovery phrase. Anyone asking for it is trying to scam you. To back up your recovery phrase, write it down and store it securely.")
                wrapMode: Text.WordWrap
            }

            StatusButton {
                objectName: "btnConfirm"
                Layout.topMargin: Theme.padding
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

        TextMetrics {
            id: idxMetrics
            font.family: Fonts.monoFont.family
            font.pixelSize: Theme.primaryTextFontSize
            text: "99"
        }
    }
}
