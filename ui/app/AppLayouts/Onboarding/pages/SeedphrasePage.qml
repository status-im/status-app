import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Onboarding.enums

import shared
import shared.panels
import utils

OnboardingPage {
    id: root

    title: qsTr("Create profile using a recovery phrase")
    property string subtitle: qsTr("Enter your 12, 18 or 24 word recovery phrase")
    property alias btnContinueText: btnContinue.text

    signal seedphraseSubmitted(string seedphrase)
    signal seedphraseProvided(var seedPhrase)

    function setSeedPhraseError(errorMessage: string) : void {
        seedPanel.setError(errorMessage)
    }

    contentItem: StatusScrollView {
        id: scrollView

        contentWidth: availableWidth

        Item {
            width: scrollView.availableWidth
            implicitHeight: content.implicitHeight

            ColumnLayout {
                id: content

                anchors.horizontalCenter: parent.horizontalCenter

                width: Math.min(610, parent.width)
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
                    text: root.subtitle
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                EnterSeedPhrase {
                    id: seedPanel

                    Layout.fillWidth: true
                    flickable: scrollView.flickable

                    dictionary: BIP39_en {}

                    onSeedPhraseAccepted: root.seedphraseSubmitted(seedPhrase.join(" "))
                    onSeedPhraseProvided: seedPhrase => root.seedphraseProvided(seedPhrase)

                }

                StatusButton {
                    id: btnContinue
                    objectName: "btnContinue"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: -Theme.halfPadding
                    enabled: seedPanel.seedPhraseIsValid
                    text: qsTr("Continue")
                    onClicked: root.seedphraseSubmitted(seedPanel.seedPhrase.join(" "))
                }
            }
        }
    }
}
