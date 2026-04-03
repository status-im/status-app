import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import shared.popups.keycard_new.helpers 1.0

import utils

Control {
    id: root

    required property string keycardState
    required property bool keycardInternalError
    required property bool wrongKeycardProfile
    property var keyPairForProcessing: null

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Image {
            id: image
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        StatusLoadingIndicator {
            id: loading
            Layout.alignment: Qt.AlignCenter
            visible: root.keycardState === Constants.keycard.state.connectingCard
        }

        StatusBaseText {
            id: title
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusBaseText {
            id: message
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Loader {
            id: keyPairLoader
            Layout.fillWidth: true
            visible: false
            active: !!root.keyPairForProcessing
            sourceComponent: KeyPairCompactItem {
                keyPairType: root.keyPairForProcessing.pairType
                keyPairKeyUid: root.keyPairForProcessing.keyUid
                keyPairName: root.keyPairForProcessing.name
                keyPairIcon: root.keyPairForProcessing.icon
                keyPairImage: root.keyPairForProcessing.image
                keyPairDerivedFrom: root.keyPairForProcessing.derivedFrom
                keyPairAccounts: root.keyPairForProcessing.accounts
                keyPairCardLocked: root.keyPairForProcessing.locked

                displayAdditionalInfoForProfileKeypair: false
            }
        }
    }

    states: [
        State {
            name: "waiting-for-reader"
            when: root.keycardState === Constants.keycard.state.waitingForReader
                  || root.keycardState === Constants.keycard.state.noReadersFound
                  || root.keycardState === Constants.keycard.state.unknownReaderState
                  || root.keycardState === ""
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/something-went-wrong")
            }
            PropertyChanges {
                target: title
                text: qsTr("Plug in Keycard reader...")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: "waiting-for-card"
            when: root.keycardState === Constants.keycard.state.waitingForCard
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_insert/insert")
            }
            PropertyChanges {
                target: title
                text: qsTr("Tap or insert Keycard...")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: message
                text: ""
            }
            PropertyChanges {
                target: keyPairLoader
                visible: true
            }
        },
        State {
            name: "reading-card"
            when: !root.keycardInternalError
                  && !root.wrongKeycardProfile
                  && (root.keycardState === Constants.keycard.state.connectingCard
                      || root.keycardState === Constants.keycard.state.ready)
            PropertyChanges {
                target: image
                source: Assets.png("keycard/scanning/scanning")
            }
            PropertyChanges {
                target: title
                text: qsTr("Reading Keycard...")
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.Normal
                color: Theme.palette.baseColor1
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: "empty-keycard"
            when: root.keycardState === Constants.keycard.state.emptyKeycard
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/wrong-profile")
            }
            PropertyChanges {
                target: title
                text: qsTr("Keycard is empty")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("There is no key pair on this Keycard")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: keyPairLoader
                visible: true
            }
        },
        State {
            name: "not-keycard"
            when: root.keycardState === Constants.keycard.state.notKeycard
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/not-keycard")
            }
            PropertyChanges {
                target: title
                text: qsTr("This is not a Keycard")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("The card is not a Keycard, try again with Keycard.")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: keyPairLoader
                visible: true
            }
        },
        State {
            name: "connection-error"
            when: root.keycardState === Constants.keycard.state.connectionError
                  || root.keycardState === Constants.keycard.state.readerConnectionError
                  || root.keycardState === Constants.keycard.state.internalError
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/something-went-wrong")
            }
            PropertyChanges {
                target: title
                text: qsTr("Connection error")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("Something went wrong, please try again")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: "blocked-pin"
            when: root.keycardState === Constants.keycard.state.blockedPIN
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/writing-negative")
            }
            PropertyChanges {
                target: title
                text: qsTr("Keycard locked")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("PIN entered incorrectly too many times")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: "blocked-puk"
            when: root.keycardState === Constants.keycard.state.blockedPUK
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/writing-negative")
            }
            PropertyChanges {
                target: title
                text: qsTr("Keycard locked")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("PUK entered incorrectly too many times")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: "pairing-error"
            when: root.keycardState === Constants.keycard.state.pairingError
                  || root.keycardState === Constants.keycard.state.noAvailablePairingSlots
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/writing-negative")
            }
            PropertyChanges {
                target: title
                text: qsTr("Keycard pairing error")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("Max pairing slots reached for this Keycard")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: "wrong-keycard-profile"
            when: root.wrongKeycardProfile
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/wrong-profile")
            }
            PropertyChanges {
                target: title
                text: qsTr("Wrong Keycard inserted")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("Inserted Keycard does not match the expected key")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: "keycard-internal-error"
            when: root.keycardInternalError
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/wrong-profile")
            }
            PropertyChanges {
                target: title
                text: qsTr("Something went wrong")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("Try again")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: "auth-success"
            when: root.keycardState === Constants.keycard.state.authorized
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/writing-positive")
            }
            PropertyChanges {
                target: title
                text: qsTr("Success")
                color: Theme.palette.directColor1
            }
        }
    ]
}
