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
    required property bool wrongKeycard

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Image {
            id: readingImage
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        StatusLoadingIndicator {
            Layout.alignment: Qt.AlignCenter
            visible: root.keycardState === Constants.keycard.state.connectingCard
        }

        StatusBaseText {
            id: readingTitle
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusBaseText {
            id: readingMessage
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
                name: "waiting-for-reader"
                when: root.keycardState === Constants.keycard.state.waitingForReader
                      || root.keycardState === Constants.keycard.state.noReadersFound
                      || root.keycardState === Constants.keycard.state.unknownReaderState
                      || root.keycardState === ""
                PropertyChanges {
                    target: readingImage
                    source: Assets.png("keycard/wrong_card/something-went-wrong")
                }
                PropertyChanges {
                    target: readingTitle
                    text: qsTr("Plug in Keycard reader...")
                    color: Theme.palette.directColor1
                }
                PropertyChanges {
                    target: readingMessage
                    text: ""
                }
            },
            State {
                name: "waiting-for-card"
                when: root.keycardState === Constants.keycard.state.waitingForCard
                PropertyChanges {
                    target: readingImage
                    source: Assets.png("keycard/card_insert/insert")
                }
                PropertyChanges {
                    target: readingTitle
                    text: qsTr("Tap or insert Keycard...")
                    color: Theme.palette.directColor1
                }
                PropertyChanges {
                    target: readingMessage
                    text: ""
                }
            },
            State {
                name: "reading-card"
                when: !root.wrongKeycard
                      && (root.keycardState === Constants.keycard.state.connectingCard
                          || root.keycardState === Constants.keycard.state.ready
                          || root.keycardState === Constants.keycard.state.authorized)
                PropertyChanges {
                    target: readingImage
                    source: Assets.png("keycard/scanning/scanning")
                }
                PropertyChanges {
                    target: readingTitle
                    text: qsTr("Reading Keycard...")
                    font.pixelSize: Theme.primaryTextFontSize
                    font.weight: Font.Normal
                    color: Theme.palette.baseColor1
                }
                PropertyChanges {
                    target: readingMessage
                    text: ""
                }
            },
            State {
                name: "not-keycard"
                when: root.keycardState === Constants.keycard.state.notKeycard
                PropertyChanges {
                    target: readingImage
                    source: Assets.png("keycard/wrong_card/not-keycard")
                }
                PropertyChanges {
                    target: readingTitle
                    text: qsTr("This is not a Keycard")
                    color: Theme.palette.dangerColor1
                }
                PropertyChanges {
                    target: readingMessage
                    text: qsTr("The card is not a Keycard, try again with Keycard.")
                    color: Theme.palette.dangerColor1
                }
            },
            State {
                name: "connection-error"
                when: root.keycardState === Constants.keycard.state.connectionError
                      || root.keycardState === Constants.keycard.state.readerConnectionError
                      || root.keycardState === Constants.keycard.state.internalError
                PropertyChanges {
                    target: readingImage
                    source: Assets.png("keycard/wrong_card/something-went-wrong")
                }
                PropertyChanges {
                    target: readingTitle
                    text: qsTr("Connection error")
                    color: Theme.palette.dangerColor1
                }
                PropertyChanges {
                    target: readingMessage
                    text: qsTr("Something went wrong, please try again")
                    color: Theme.palette.dangerColor1
                }
            },
            State {
                name: "wrong-keycard"
                when: root.keycardState === Constants.keycard.state.ready
                      && root.wrongKeycard
                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/wrong_card/wrong-profile")
                }
                PropertyChanges {
                    target: title
                    text: qsTr("Wrong Keycard inserted")
                    color: Theme.palette.directColor1
                }
                PropertyChanges {
                    target: message
                    text: qsTr("Inserted Keycard does not match the expected key")
                    color: Theme.palette.directColor1
                }
            }
        ]
    }
}
