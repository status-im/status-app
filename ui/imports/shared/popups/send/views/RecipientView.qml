import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils

import AppLayouts.Wallet

import shared.controls as SharedControls
import shared.stores.send
import shared.popups.send.panels
import shared.popups.send

import utils

import "../controls"

Loader {
    id: root

    property TransactionStore store
    property bool isCollectiblesTransfer
    property bool interactive: true
    property var selectedAsset
    property var selectedRecipient: null
    property int selectedRecipientType: Helpers.RecipientAddressObjectType.Address

    readonly property bool ready: d.isAddressValid && !d.isPending
    property string addressText
    property string resolvedENSAddress

    signal recalculateRoutesAndFees()
    signal isLoading()

    onAddressTextChanged: d.isPending = false

    onSelectedRecipientChanged: {
        root.isLoading()
        if(!!root.selectedRecipient) {
            switch(root.selectedRecipientType) {
            case Helpers.RecipientAddressObjectType.Account: {
                root.addressText = root.selectedRecipient.address
                break
            }
            case Helpers.RecipientAddressObjectType.SavedAddress: {
                root.addressText = root.selectedRecipient.address

                // Resolve before using
                if (!!root.selectedRecipient.ens && root.selectedRecipient.ens.length > 0) {
                    d.isPending = true
                    d.resolveENS(root.selectedRecipient.ens)
                }
                break
            }
            case Helpers.RecipientAddressObjectType.RecentsAddress: {
                let isIncoming = root.selectedRecipient.txType === Constants.TransactionType.Receive
                root.addressText = isIncoming ? root.selectedRecipient.sender : root.selectedRecipient.recipient
                root.item.input.text = root.addressText
                break
            }
            case Helpers.RecipientAddressObjectType.Address: {
                root.addressText = root.selectedRecipient

                // Resolve before using
                if (Utils.isValidEns(root.selectedRecipient)) {
                    d.isPending = true
                    d.resolveENS(root.selectedRecipient)
                }
                else {
                    root.item.input.text = root.addressText
                }
                break
            }
            }

            // set preferred chains
            if(!isCollectiblesTransfer) {
                root.store.updateRoutePreferredChains([])
            }

            recalculateRoutesAndFees()
        }
    }

    QtObject {
        id: d
        readonly property bool isAddressValid: Utils.isValidAddress(root.addressText)
        readonly property var resolveENS: Backpressure.debounce(root, 1500, function (ensName) {
            store.resolveENS(ensName)
        })
        property bool isPending: false
        function clearValues() {
            root.addressText = ""
            root.resolvedENSAddress = ""
            root.selectedRecipientType = Helpers.RecipientAddressObjectType.Address
            root.selectedRecipient = null
        }
        property Timer waitTimer: Timer {
            interval: 1500
            onTriggered: d.evaluateAndSetPreferredChains()
        }

        function evaluateAndSetPreferredChains() {
            const plainText = StatusQUtils.StringUtils.plainText(root.item.input.text)
            const address = !!root.item.input && !!plainText ? plainText: ""
            const result = root.store.splitAndFormatAddressPrefix(address, !root.isCollectiblesTransfer)
            if(!!result.address) {
                root.addressText = result.address
                if(!!root.item.input) {
                    root.item.input.text = result.formattedText
                    root.item.input.edit.cursorPosition = root.item.input.edit.length
                }
            }
            root.recalculateRoutesAndFees()
        }
    }

    sourceComponent: root.selectedRecipientType === Helpers.RecipientAddressObjectType.SavedAddress
        ? savedAddressRecipient
        : root.selectedRecipientType === Helpers.RecipientAddressObjectType.Account
            ? myAccountRecipient : addressRecipient

    Component {
        id: savedAddressRecipient
        SavedAddressListItem {
            implicitWidth: parent.width
            modelData: root.selectedRecipient
            radius: 8
            clearVisible: true
            color: Theme.palette.indirectColor1
            sensor.enabled: false
            subTitle:  {
                if(!!modelData) {
                    if (!!modelData && !!modelData.ens && modelData.ens.length > 0)
                        return Utils.richColorText(modelData.ens, Theme.palette.directColor1)
                    else
                        return StatusQUtils.Utils.elideText(modelData.address,6,4)
                }
                return ""
            }
            onCleared: d.clearValues()
        }
    }

    Component {
        id: myAccountRecipient
        SharedControls.WalletAccountListItem {
            id: accountItem
            readonly property var modelData: root.selectedRecipient

            name: !!modelData ? modelData.name : ""
            address: !!modelData ? modelData.address : ""
            emoji: !!modelData ? modelData.emoji : ""
            walletColor: !!modelData ? Utils.getColorForId(Theme.palette, modelData.colorId): ""
            currencyBalance: !!modelData ? modelData.currencyBalance : ""
            walletType: !!modelData ? modelData.walletType : ""
            migratedToKeycard: !!modelData ? modelData.migratedToKeycard ?? false : false
            accountBalance: !!modelData ? modelData.accountBalance : null

            implicitWidth: parent.width
            radius: 8
            clearVisible: true
            color: Theme.palette.indirectColor1
            sensor.enabled: false
            subTitle: {
                if(!!modelData) {
                    return StatusQUtils.Utils.elideAndFormatWalletAddress(modelData.address)
                }
                return ""
            }
            onCleared: d.clearValues()
        }
    }

    Component {
        id: addressRecipient
        SendRecipientInput {
            width: parent.width
            height: visible ? implicitHeight: 0
            text: root.addressText

            function validateInput() {
                const plainText = StatusQUtils.StringUtils.plainText(text)
                root.isLoading()
                if (Utils.isValidEns(plainText)) {
                    d.isPending = true
                    d.resolveENS(plainText)
                } else {
                    d.waitTimer.restart()
                }
            }

            interactive: root.interactive
            checkMarkVisible: root.ready
            loading: d.isPending || d.waitTimer.running
            onClearClicked: d.clearValues()
            onValidateInputRequested: validateInput()
        }
    }

    Connections {
        target: store.mainModuleInst
        function onResolvedENS(resolvedPubKey: string, resolvedAddress: string, uuid: string) {
            d.isPending = false
            if(Utils.isValidAddress(resolvedAddress)) {
                root.resolvedENSAddress = resolvedAddress
                root.addressText = root.resolvedENSAddress
                if(!!root.item.input)
                    root.item.input.text = root.resolvedENSAddress
                d.evaluateAndSetPreferredChains()
            }
        }
    }
}

