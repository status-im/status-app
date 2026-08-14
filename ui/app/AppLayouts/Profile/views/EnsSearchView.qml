import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Controls as StatusQControls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme

import utils
import shared.panels
import shared.status
import shared.controls

import AppLayouts.Profile.stores

Item {
    id: root

    property EnsUsernamesStore ensUsernamesStore
    property int profileContentWidth

    signal backBtnClicked()
    signal connectUsername(string username, string ownerAddress)
    signal continueClicked(string output, string username)

    property string validationMessage: ""
    property bool valid: false
    property bool isStatus: true
    property bool loading: false
    property string ensStatus: ""
    property string ensOwnerAddress: ""

    property var validateENS: Backpressure.debounce(root, 500, function (ensName, isStatus){
        root.ensUsernamesStore.checkEnsUsernameAvailability(ensName, isStatus)
    });

    function validate(ensUsername) {
        validationMessage = "";
        valid = false;
        ensStatus = "";
        if (ensUsername.length < 4) {
            validationMessage = qsTr("At least 4 characters. Latin letters, numbers, and lowercase only.");
        } else if(isStatus && !ensUsername.match(/^[a-z0-9]+$/)){
            validationMessage = qsTr("Letters and numbers only.");
        } else if(!isStatus && !ensUsername.endsWith(".eth")){
            validationMessage = qsTr("Type the entire username including the custom domain like username.domain.eth")
        }
        return validationMessage === "";
    }

    function onEnsUsernameChanged(ensUsername){
        if (!validate(ensUsername)) {
            return;
        }
        loading = true;
        Qt.callLater(validateENS, ensUsername, isStatus)
    }

    Item {
        id: ensContainer
        anchors.top: parent.top
        width: profileContentWidth
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            id: circleAt
            anchors.top: parent.top
            anchors.topMargin: Theme.bigPadding*2
            anchors.horizontalCenter: parent.horizontalCenter
            width: 60
            height: 60
            radius: 120
            color: Theme.palette.primaryColor1

            SVGImage {
                visible: ensStatus === Constants.ens_taken
                fillMode: Image.PreserveAspectFit
                source: Assets.svg("block-icon-white")
                width: 20
                height: 20
                anchors.centerIn: parent
            }

            StatusBaseText {
                visible: ensStatus !== Constants.ens_taken
                text: {
                    if((ensStatus === Constants.ens_available ||
                         ensStatus === Constants.ens_connected ||
                         ensStatus === Constants.ens_connected_dkey)) {
                        return "✓"
                    } else {
                        return "@"
                    }
                }
                opacity: 0.7
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSize(18)
                color: Theme.palette.indirectColor1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Input {
            id: ensUsername
            textField.objectName: "ensUsernameInput"
            placeholderText: !isStatus ? "vitalik94.domain.eth" : "vitalik94"
            anchors.left: parent.left
            anchors.top: circleAt.bottom
            anchors.topMargin: Theme.bigPadding
            anchors.right: btnContinue.left
            anchors.rightMargin: Theme.bigPadding

            onEditingFinished: inputValue => onEnsUsernameChanged(inputValue)
            onTextEdited: inputValue => onEnsUsernameChanged(inputValue)

            Connections {
                target: root.ensUsernamesStore.ensUsernamesModule
                function onUsernameAvailabilityChecked(availabilityStatus: string, ownerAddress: string) {
                    if(!validate(ensUsername.text)) return;
                    valid = false;
                    loading = false;
                    ensStatus = availabilityStatus;
                    ensOwnerAddress = ownerAddress
                    switch(availabilityStatus){
                        case "available":
                        case "owned":
                        case "connected":
                        case "connected-different-key":
                            valid = true;
                            validationMessage = Constants.ensState[availabilityStatus]
                            break;
                        case "taken":
                            validationMessage = Constants.ensState[!isStatus ? 'taken-custom' : 'taken']
                            break;
                        case "already-connected":
                            validationMessage = Constants.ensState[availabilityStatus]
                            break;
                    }
                }
            }
        }

        StatusQControls.StatusRoundButton {
            id: btnContinue
            width: 40
            height: 40
            anchors.top: circleAt.bottom
            anchors.topMargin: Theme.bigPadding
            anchors.right: parent.right
            type: StatusQControls.StatusRoundButton.Type.Secondary
            objectName: "ensNextButton"
            icon.name: "arrow-right"
            visible: valid
            onClicked: {
                if(!valid) return;

                if(ensStatus === Constants.ens_connected){
                    root.ensUsernamesStore.ensConnectOwnedUsername(ensUsername.text, isStatus);
                    continueClicked(ensStatus, ensUsername.text)
                    return;
                }

                if(ensStatus === Constants.ens_available){
                    continueClicked(ensStatus, ensUsername.text);
                    return;
                }

                if(ensStatus === Constants.ens_connected_dkey || ensStatus === Constants.ens_owned){
                    root.connectUsername(ensUsername.text, root.ensOwnerAddress)
                }
            }
        }

        Rectangle {
            id: ensTypeRect
            anchors.top: ensUsername.bottom
            anchors.topMargin: Theme.bigPadding
            border.width: 1
            border.color: Theme.palette.border
            color: Theme.palette.background
            radius: 50
            height: 30
            width: ensTypeRow.width + Theme.halfPadding*2

            Row {
                id: ensTypeRow
                anchors.top: parent.top
                anchors.topMargin: Theme.halfPadding
                leftPadding: Theme.padding
                spacing: Theme.smallPadding
                height: 20

                StatusBaseText {
                    text: !isStatus ?
                        qsTr("Custom domain")
                        :
                        ".stateofus.eth"
                    font.weight: Font.Bold
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: !isStatus ?
                        qsTr("I want a stateofus.eth domain")
                        :
                        qsTr("I own a name on another domain")
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.primaryColor1

                    StatusMouseArea {
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        onClicked : {
                            isStatus = !isStatus;
                            let ensUser = ensUsername.text;
                            if(validate(ensUser))
                                validateENS(ensUser, isStatus)
                        }
                    }
                }
            }
        }

        StatusBaseText {
            id: validationResult
            text: validationMessage
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            anchors.top: ensTypeRect.bottom
            wrapMode: Text.WordWrap
            anchors.topMargin: Theme.bigPadding
            color: Theme.palette.directColor1
        }
    }

    StatusQControls.StatusButton {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.padding
        anchors.horizontalCenter: parent.horizontalCenter
        text: qsTr("Back")
        onClicked: root.backBtnClicked()
    }
}

