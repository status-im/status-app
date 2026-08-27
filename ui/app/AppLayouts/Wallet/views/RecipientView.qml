import AppLayouts.Wallet
import AppLayouts.Wallet.controls

import QtQuick

import StatusQ
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils

import utils

import QtModelsToolkit

Loader {
    id: root

    required property var model

    readonly property string searchPattern: d.searchPattern

    property string selectedRecipientAddress
    property bool interactive: true

    signal resolveENS(string ensName, string uuid)
    signal keyPressed(variant event)

    function setText(text) {
        if (!!selectedRecipientAddress || !item)
            return

        item.text = text
    }

    function ensNameResolved(resolvedPubKey, resolvedAddress, uuid) {
        if(uuid !== d.uuid) {
            return
        }
        if (!!selectedRecipientAddress) {
            d.isBeingEvaluated = false
            return
        }

        d.searchPattern = !!resolvedAddress ? resolvedAddress : d.validatedEns
        d.isBeingEvaluated = false

        if (root.model.ModelCount.count === 0) {
            if (!!resolvedAddress) {
                root.selectedRecipientAddress = resolvedAddress
            } else {
                d.inputError = qsTr("Enter a valid Ethereum address or ENS name")
            }
        }
    }

    QtObject {
        id: d
        objectName: "RecipientView_private"

        property bool isValidAddress: false
        property bool isBeingEvaluated: false

        property string inputError

        property string searchPattern

        property string uuid
        property string validatedEns

        readonly property Timer validationTimer: Timer {
            property string address
            interval: 1000
            running: false
            repeat: false
            onTriggered: d.validateInput(address)
            onRunningChanged: {
                if (running) {
                    d.inputError = ""
                    d.isBeingEvaluated = true
                }
            }
        }

        function validateInput(address) {
            if (!root || root.selectedRecipientAddress)
                return
            if (!address) {
                root.selectedRecipientAddress = ""
                d.searchPattern = ""
                d.isBeingEvaluated = false
                return
            }

            d.isValidAddress = Utils.isValidAddress(address)
            const isENSName = Utils.isValidEns(address)

            if(d.isValidAddress) {
                d.searchPattern = address
                d.isBeingEvaluated = false
                if (root.model.ModelCount.count === 0) {
                    root.selectedRecipientAddress = address
                }
                return
            } else if(isENSName) {
                d.uuid = Utils.uuid()
                d.validatedEns = address
                return root.resolveENS(address, uuid)
            } else {
                d.inputError = qsTr("Enter a valid Ethereum address or ENS name")
            }

            root.selectedRecipientAddress = ""
            d.searchPattern = address
            d.isBeingEvaluated = false
        }

        function clearValues() {
            root.selectedRecipientAddress = ""
            d.searchPattern = ""
            d.validatedEns = ""
            d.inputError = ""
            d.isValidAddress = false
            d.isBeingEvaluated = false
        }
    }

    sourceComponent: !!root.selectedRecipientAddress ? recipientItemComponent : recipientInput

    Component {
        id: recipientInput

        SendRecipientInput {
            objectName: "RecipientView_SendRecipientInput"
            anchors.left: parent.left
            anchors.right: parent.right

            function validateInput() {
                const address = StatusQUtils.StringUtils.plainText(text)
                if (!address) {
                    d.validationTimer.stop()
                    if (!root.selectedRecipientAddress && !!d.searchPattern) {
                        d.clearValues()
                    }
                    return
                }
                d.validationTimer.address = address
                d.validationTimer.restart()
            }

            leftPadding: 4
            rightPadding: 4
            bottomPadding: 4
            topPadding: 4
            height: visible ? implicitHeight: 0

            checkMarkVisible: !d.isBeingEvaluated && d.isValidAddress
            loading: d.isBeingEvaluated
            input.edit.textFormat: Text.AutoText
            error: !d.isBeingEvaluated && !!d.inputError && root.model.ModelCount.count === 0 ? d.inputError : ""
            input.background.color: Theme.palette.secondaryMenuBackground

            onTextChanged: Qt.callLater(() => validateInput())
            onClearClicked: {
                text = ""
                d.clearValues()
            }
            onValidateInputRequested: Qt.callLater(() => validateInput())
            Keys.onPressed: (event) => root.keyPressed(event)
        }
    }

    Component {
        id: recipientItemComponent
        RecipientViewDelegate {
            objectName: "RecipientView_RecipientViewDelegate"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.halfPadding / 2
            anchors.rightMargin: Theme.halfPadding / 2

            forceDefaultCursor: true
            statusListItemSubTitle.customColor: Theme.palette.baseColor1
            // Disable highlight
            color: "transparent"

            readonly property var accountsSelectedEntry: ModelEntry {
                sourceModel: root.model
                key: "address"
                value: root.selectedRecipientAddress.toLowerCase()
            }
            readonly property var modelData: accountsSelectedEntry.available ? accountsSelectedEntry.item : null

            address: !!modelData ? modelData.address : root.selectedRecipientAddress
            name: !!modelData ? (modelData.name ?? "") : d.validatedEns
            ens: !!modelData && !!modelData.ens ? modelData.ens : ""
            walletColor: !!modelData && !!modelData.color ? modelData.color : ""
            walletColorId: !!modelData && !!modelData.colorId ? modelData.colorId : ""
            emoji: !!modelData && !!modelData.emoji ? modelData.emoji : ""

            useAddressAsLetterIdenticon: !accountsSelectedEntry.available && !!d.validatedEns

            components: [
                StatusClearButton {
                    objectName: "RecipientView_clearButton"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.interactive
                    onClicked: d.clearValues()
                }
            ]
        }
    }
}

