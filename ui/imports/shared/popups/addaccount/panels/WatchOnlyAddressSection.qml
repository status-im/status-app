import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators

import utils

import "../stores"
import "../../common"

Column {
    id: root

    property AddAccountStore store

    function reset() {
        addressInput.reset()
    }

    QtObject {
        id: d

        property bool incorrectChecksum: false
        property string uuid
        property string resolvedEnsAddress

        function checkIfAddressChecksumIsValid(address) {
            d.incorrectChecksum = !root.store.isChecksumValidForAddress(address)
        }

        function validateEnsAsync(value) {
            var name = value.startsWith("@") ? value.substring(1) : value
            d.uuid = Utils.uuid()
            root.store.validateEnsAsync(name, d.uuid)
        }
    }

    Connections {
        target: root.store
        function onResolvedENS(resolvedPubKey: string, resolvedAddress: string, uuid: string) {
            if (uuid !== d.uuid) {
                return
            }

            d.resolvedEnsAddress = resolvedAddress
            addressInput.validate()
            root.store.changeWatchOnlyAccountAddressPostponed(resolvedAddress)
        }
    }

    StatusInput {
        id: addressInput
        objectName: "AddAccountPopup-WatchOnlyAddress"
        width: parent.width
        maximumHeight: Constants.addAccountPopup.itemHeight
        minimumHeight: Constants.addAccountPopup.itemHeight
        label: qsTr("Ethereum address or ENS name")
        placeholderText: qsTr("Type or paste ETH address")
        input.multiline: true
        warningMode: d.incorrectChecksum
        warningMessage: qsTr("Checksum of the entered address is incorrect")
        input.rightComponent: StatusPasteButton {
            anchors.verticalCenter: parent.verticalCenter
            onPasted: (text) => addressInput.text = text
        }
        validators: [
            StatusValidator {
                name: "address-or-ens"
                validate: (value) => {
                              return Utils.isValidAddress(value) ||
                              Utils.isValidEns(value) &&
                              !!d.resolvedEnsAddress
                          }
                errorMessage: qsTr("Please enter a valid Ethereum address or ENS name")
            }
        ]

        onTextChanged: {
            d.incorrectChecksum = false
            const trimmedText = text.trim()
            if (Utils.isValidEns(trimmedText)) {
                d.resolvedEnsAddress = ""
                d.validateEnsAsync(trimmedText)
                return
            } else if (Utils.isValidAddress(trimmedText)) {
                root.store.changeWatchOnlyAccountAddressPostponed(trimmedText)
                d.checkIfAddressChecksumIsValid(trimmedText)
                return
            }

            root.store.cleanWatchOnlyAccountAddress()
        }

        onKeyPressed: {
            root.store.submitPopup(event)
        }
    }

    AddressDetails {
        width: parent.width
        addressDetailsItem: root.store.watchOnlyAccAddress
        defaultMessage: qsTr("You will need to import your recovery phrase or use your Keycard to transact with this account")
        defaultMessageCondition: addressInput.text === "" || !addressInput.valid
    }
}
