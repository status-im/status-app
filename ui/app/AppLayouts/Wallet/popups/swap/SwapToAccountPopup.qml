import QtQuick
import QtQuick.Controls

import StatusQ.Popups.Dialog

import AppLayouts.Wallet.panels
import AppLayouts.Wallet.adaptors

StatusDialog {
    id: root

    /** Recipient source models (same as the Send modal wiring) **/
    required property var savedAddressesModel
    required property var accountsModel
    required property var recentRecipientsModel

    /** The from account, excluded from the "My Accounts" list **/
    property string selectedSenderAddress

    /** Resolve an ENS name typed into the recipient input **/
    property var fnResolveENS: function(ensName, uuid) {}

    /** Emitted once a recipient address is picked/resolved **/
    signal recipientSelected(string address)

    /** Forward a resolved ENS result to the inner panel **/
    function ensNameResolved(resolvedPubKey, resolvedAddress, uuid) {
        recipientsPanel.ensNameResolved(resolvedPubKey, resolvedAddress, uuid)
    }

    title: qsTr("Send to")
    standardButtons: Dialog.NoButton
    implicitWidth: 480
    destroyOnClose: true

    RecipientViewAdaptor {
        id: recipientViewAdaptor

        savedAddressesModel: root.savedAddressesModel
        accountsModel: root.accountsModel
        recentRecipientsModel: root.recentRecipientsModel

        selectedSenderAddress: root.selectedSenderAddress
        selectedRecipientType: recipientsPanel.selectedRecipientType
        searchPattern: recipientsPanel.searchPattern
    }

    RecipientSelectorPanel {
        id: recipientsPanel
        objectName: "swapRecipientsPanel"

        width: root.availableWidth

        recipientsModel: recipientViewAdaptor.recipientsModel
        recipientsFilterModel: recipientViewAdaptor.recipientsFilterModel

        onResolveENS: root.fnResolveENS(ensName, uuid)
        onSelectedRecipientAddressChanged: {
            if (!!selectedRecipientAddress) {
                root.recipientSelected(selectedRecipientAddress)
                root.close()
            }
        }
    }
}
