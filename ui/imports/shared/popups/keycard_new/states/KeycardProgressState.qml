import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import utils

Control {
    id: root

    required property string keycardState
    required property bool keycardInternalError
    required property bool wrongKeycard
    required property bool wrongKeycardProfile
    required property bool wrongPin
    required property int remainingAttempts

    required property bool processing
    required property string processingImage
    property string processingTitle: qsTr("Reading...")
    property string processingMessage: ""

    required property bool success
    required property string successImage
    property string successTitle: qsTr("Success")
    property string successMessage: ""

    required property bool failure
    required property string failureImage
    property string failureTitle: qsTr("Something went wrong")
    property string failureMessage: qsTr("Try again")

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
            Layout.alignment: Qt.AlignCenter
            visible: root.processing
                     && root.state !== "waiting-for-reader"
                     && root.state !== "waiting-for-card"
                     && root.state !== "reading-card"
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

        states: [
            State {
                name: "success"
                when: !root.failure
                      && root.success
                PropertyChanges {
                    target: image
                    source: root.successImage
                }
                PropertyChanges {
                    target: title
                    text: root.successTitle
                    color: Theme.palette.directColor1
                }
                PropertyChanges {
                    target: message
                    text: root.successMessage
                    color: Theme.palette.directColor1
                }
            },
            State {
                name: "waiting-for-reader"
                when: !root.failure
                      && (root.keycardState === Constants.keycard.state.waitingForReader
                          || root.keycardState === Constants.keycard.state.noReadersFound
                          || root.keycardState === Constants.keycard.state.unknownReaderState
                          || root.keycardState === "")
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
                when: !root.failure
                      && root.keycardState === Constants.keycard.state.waitingForCard
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
            },
            State {
                name: "reading-card"
                when: !root.failure
                      && !root.keycardInternalError
                      && !root.wrongKeycard
                      && !root.wrongKeycardProfile
                      && (root.keycardState === Constants.keycard.state.connectingCard
                          || root.keycardState === Constants.keycard.state.ready
                          || root.keycardState === Constants.keycard.state.authorized)
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
                name: "not-keycard"
                when: !root.failure
                      && root.keycardState === Constants.keycard.state.notKeycard
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
                    text: qsTr("The card is not a Keycard, try again with Keycard")
                    color: Theme.palette.dangerColor1
                }
            },
            State {
                name: "connection-error"
                when: !root.failure
                      && (root.keycardState === Constants.keycard.state.connectionError
                          || root.keycardState === Constants.keycard.state.readerConnectionError
                          || root.keycardState === Constants.keycard.state.internalError)
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
                name: "wrong-keycard-profile"
                when: root.failure
                      && root.wrongKeycardProfile
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
                name: "wrong-keycard"
                when: root.failure
                      && root.wrongKeycard
                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/wrong_card/wrong-profile")
                }
                PropertyChanges {
                    target: title
                    text: qsTr("It's a different Keycard")
                    color: Theme.palette.dangerColor1
                }
                PropertyChanges {
                    target: message
                    text: qsTr("Please try again with Keycard you read before")
                    color: Theme.palette.dangerColor1
                }
            },
            State {
                name: "wrong-pin"
                when: root.failure
                      && root.wrongPin
                      && root.keycardState !== Constants.keycard.state.blockedPIN
                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/wrong_card/wrong-profile")
                }
                PropertyChanges {
                    target: title
                    text: qsTr("PIN incorrect")
                    color: Theme.palette.dangerColor1
                }
                PropertyChanges {
                    target: message
                    visible: root.remainingAttempts > 0
                             && root.remainingAttempts < 3
                    text: qsTr("%n attempt(s) remaining", "", root.remainingAttempts)
                    color: Theme.palette.dangerColor1
                }
            },
            State {
                name: "blocked-pin"
                when: root.failure
                      && root.keycardState === Constants.keycard.state.blockedPIN
                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/card_inserted/writing-negative")
                }
                PropertyChanges {
                    target: title
                    text: qsTr("Keycard is blocked")
                    color: Theme.palette.dangerColor1
                }
                PropertyChanges {
                    target: message
                    text: qsTr("Keycard is blocked due to three failed PIN input attempts")
                    color: Theme.palette.dangerColor1
                }
            },
            State {
                name: "keycard-internal-error"
                when: root.failure
                      && root.keycardInternalError
                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/wrong_card/something-went-wrong")
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
                name: "processing"
                when: !root.failure
                      && root.processing
                PropertyChanges {
                    target: image
                    source: root.processingImage
                }
                PropertyChanges {
                    target: title
                    text: root.processingTitle
                    color: Theme.palette.directColor1
                }
                PropertyChanges {
                    target: message
                    text: root.processingMessage
                    color: Theme.palette.directColor1
                }
            },
            State {
                name: "failure"
                when: root.failure
                PropertyChanges {
                    target: image
                    source: root.failureImage
                }
                PropertyChanges {
                    target: title
                    text: root.failureTitle
                    color: Theme.palette.dangerColor1
                }
                PropertyChanges {
                    target: message
                    text: root.failureMessage
                    color: Theme.palette.dangerColor1
                }
            }
        ]
    }
}
