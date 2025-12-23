import QtQuick
import QtQuick.Controls // for Popup.xxx

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import utils
import shared.stores as SharedStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Profile.helpers

StatusDialog {
    id: root

    required property WalletStores.RootStore store
    required property SharedStores.RootStore sharedRootStore
    property var contactsModel

    signal populateContactDetails(string publicKey)

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: 477
    fillHeightOnBottomSheet: true

    title: d.editMode? qsTr("Edit saved address") : qsTr("Add new saved address")
    subtitle: d.editMode? d.name : ""

    function initWithParams(params = {}) {
        d.storedName = params.name?? ""
        d.storedColorId = params.colorId?? ""

        d.editMode = params.edit?? false
        d.addAddress = params.addAddress?? false
        d.name = d.storedName
        nameInput.input.dirty = false
        d.address = params.address?? Constants.zeroAddress
        d.ens = params.ens?? ""
        d.colorId = d.storedColorId

        d.initialized = true

        if (d.colorId === "") {
            colorSelection.selectedColorIndex = Math.floor(Math.random() * colorSelection.model.length)
        }
        else {
            let ind = Utils.getColorIndexForId(Theme.palette, d.colorId)
            colorSelection.selectedColorIndex = ind
        }

        if (d.addressInputIsENS)
            addressInput.setPlainText(d.ens)
        else
            addressInput.setPlainText("%1".arg(d.address == Constants.zeroAddress? "" : d.address))

        nameInput.input.edit.forceActiveFocus()
    }

    enum CardType {
        Contact,
        WalletAccount,
        SavedAddress
    }

    QtObject {
        id: d

        property bool editMode: false
        property bool addAddress: false
        property alias name: nameInput.text
        property string address: Constants.zeroAddress // Setting as zero address since we don't have the address yet
        property string ens: ""
        property string colorId: ""

        property string storedName: ""
        property string storedColorId: ""

        property bool addressInputValid: d.editMode ||
                                         addressInput.input.dirty &&
                                         d.addressInputIsAddress &&
                                         !d.minAddressLengthRequestError &&
                                         !d.addressAlreadyAddedToWalletError &&
                                         !d.addressAlreadyAddedToSavedAddressesError
        readonly property bool valid: d.addressInputValid && nameInput.valid
        readonly property bool dirty: nameInput.input.dirty && (!d.editMode || d.storedName !== d.name)
                                      || !d.editMode
                                      || d.colorId.toUpperCase() !== d.storedColorId.toUpperCase()

        property bool incorrectChecksum: {
            if (d.addressInputIsAddress) {
                return !root.store.isChecksumValidForAddress(d.address)
            }
            return false
        }

        readonly property bool addressInputIsENS: !!d.ens &&
                                                  Utils.isValidEns(d.ens)
        readonly property bool addressInputIsAddress: !!d.address &&
                                                      d.address != Constants.zeroAddress &&
                                                      Utils.isAddress(d.address)
        readonly property bool addressInputHasError: !!addressInput.errorMessageCmp.text
        onAddressInputHasErrorChanged: addressInput.input.valid = !addressInputHasError // can't use binding because valid is overwritten in StatusInput

        property ListModel cardsModel: ListModel {}

        // possible errors/warnings
        readonly property int minAddressLen: 1
        property bool minAddressLengthRequestError: false
        property bool addressAlreadyAddedToWalletError: false
        property bool addressAlreadyAddedToSavedAddressesError: false
        property bool checkingContactsAddressInProgress: false
        property int contactsWithSameAddress: 0

        property var sharedContactModelEntryLoader: Loader {
            property string publicKey: ""

            active: false

            sourceComponent: ContactModelEntry {
                publicKey: d.sharedContactModelEntryLoader.publicKey
                contactsModel: root.contactsModel
                onPopulateContactDetailsRequested: {
                    root.populateContactDetails(d.sharedContactModelEntryLoader.publicKey)
                }
            }
        }

        function getContactModelEntry(pubkey) {
            d.sharedContactModelEntryLoader.active = false
            d.sharedContactModelEntryLoader.publicKey = pubkey
            d.sharedContactModelEntryLoader.active = true
            return d.sharedContactModelEntryLoader.item
        }

        function checkIfAddressIsAlreadyAddedToWallet(address) {
            let account = root.store.getWalletAccount(address)
            d.cardsModel.clear()
            d.addressAlreadyAddedToWalletError = !!account.name
            if (!d.addressAlreadyAddedToWalletError) {
                return
            }
            d.cardsModel.append({
                                    type: AddEditSavedAddressPopup.CardType.WalletAccount,
                                    address: account.mixedcaseAddress,
                                    title: account.name,
                                    icon: "",
                                    emoji: account.emoji,
                                    color: Utils.getColorForId(root.Theme.palette, account.colorId).toString().toUpperCase()
                                })
        }

        function checkIfAddressIsAlreadyAddedToSavedAddresses(address) {
            let savedAddress = root.store.getSavedAddress(address)
            d.cardsModel.clear()
            d.addressAlreadyAddedToSavedAddressesError = !!savedAddress.address
            if (!d.addressAlreadyAddedToSavedAddressesError) {
                return
            }
            d.cardsModel.append({
                                    type: AddEditSavedAddressPopup.CardType.SavedAddress,
                                    address: savedAddress.ens || savedAddress.address,
                                    title: savedAddress.name,
                                    icon: "",
                                    emoji: "",
                                    color: Utils.getColorForId(root.Theme.palette, savedAddress.colorId).toString().toUpperCase()
                                })
        }

        property bool resolvingEnsNameInProgress: false
        readonly property string uuid: Utils.uuid()
        readonly property var validateEnsAsync: Backpressure.debounce(root, 500, function (value) {
            var name = value.startsWith("@") ? value.substring(1) : value
            mainModule.resolveENS(name, d.uuid)
        });

        property var contactsModuleInst: root.sharedRootStore.profileSectionModuleInst.contactsModule

        /// Ensures that the \c root.address is not reset when the initial text is set
        property bool initialized: false

        function resetAddressValues(fullReset) {
            if (fullReset) {
                d.ens = ""
                d.address = Constants.zeroAddress
            }

            d.cardsModel.clear()
            d.resolvingEnsNameInProgress = false
            d.checkingContactsAddressInProgress = false
        }

        function checkForAddressInputOwningErrorsWarnings() {
            d.addressAlreadyAddedToWalletError = false
            d.addressAlreadyAddedToSavedAddressesError = false

            if (d.addressInputIsAddress) {
                d.checkIfAddressIsAlreadyAddedToWallet(d.address)
                if (d.addressAlreadyAddedToWalletError) {
                    addressInput.errorMessageCmp.text = qsTr("You cannot add your own account as a saved address")
                    addressInput.errorMessageCmp.visible = true
                    return
                }
                d.checkIfAddressIsAlreadyAddedToSavedAddresses(d.address)
                if (d.addressAlreadyAddedToSavedAddressesError) {
                    addressInput.errorMessageCmp.text = qsTr("This address is already saved")
                    addressInput.errorMessageCmp.visible = true
                    return
                }

                d.checkingContactsAddressInProgress = true
                d.contactsWithSameAddress = 0
                d.contactsModuleInst.fetchProfileShowcaseAccountsByAddress(d.address)
                return
            }

            addressInput.errorMessageCmp.text = qsTr("Not registered ens address")
            addressInput.errorMessageCmp.visible = true
        }

        function checkForAddressInputErrorsWarnings() {
            addressInput.errorMessageCmp.visible = false
            addressInput.errorMessageCmp.color = root.Theme.palette.dangerColor1
            addressInput.errorMessageCmp.text = ""

            d.minAddressLengthRequestError = false

            if (d.editMode || !addressInput.input.dirty) {
                return
            }

            if (d.addressInputIsENS || d.addressInputIsAddress) {
                let value = d.ens || d.address
                if (value.trim().length < d.minAddressLen) {
                    d.minAddressLengthRequestError = true
                    addressInput.errorMessageCmp.text = qsTr("Please enter an ethereum address")
                    addressInput.errorMessageCmp.visible = true
                    return
                }
            }

            if (d.addressInputIsENS) {
                d.resolvingEnsNameInProgress = true
                d.validateEnsAsync(d.ens)
                return
            }

            if (d.addressInputIsAddress) {
                d.checkForAddressInputOwningErrorsWarnings()
                return
            }

            addressInput.errorMessageCmp.text = qsTr("Ethereum address invalid")
            addressInput.errorMessageCmp.visible = true
        }

        function submit(event) {
            if (!d.valid
                    || !d.dirty
                    || event !== undefined && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                return

            if (!d.editMode && root.store.remainingCapacityForSavedAddresses() === 0) {
                limitPopup.active = true
                return
            }

            root.store.createOrUpdateSavedAddress(d.name, d.address, d.ens, d.colorId)
            root.close()
        }
    }

    Connections {
        target: mainModule
        function onResolvedENS(resolvedPubKey: string, resolvedAddress: string, uuid: string) {
            if (uuid !== d.uuid) {
                return
            }

            d.resolvingEnsNameInProgress = false
            d.address = resolvedAddress
            try { // allows to avoid issues in storybook without much refactoring
                d.checkForAddressInputOwningErrorsWarnings()
            }
            catch (e) {
            }
        }
    }

    Connections {
        target: d.contactsModuleInst
        function onProfileShowcaseAccountsByAddressFetched(accounts: string) {
            d.cardsModel.clear()
            d.checkingContactsAddressInProgress = false
            try {
                let accountsJson = JSON.parse(accounts)
                d.contactsWithSameAddress = accountsJson.length
                addressInput.errorMessageCmp.visible = d.contactsWithSameAddress > 0
                addressInput.errorMessageCmp.color = root.Theme.palette.warningColor1
                addressInput.errorMessageCmp.text = ""
                if (d.contactsWithSameAddress === 1)
                    addressInput.errorMessageCmp.text = qsTr("This address belongs to a contact")
                if (d.contactsWithSameAddress > 1)
                    addressInput.errorMessageCmp.text = qsTr("This address belongs to the following contacts")

                for (let i = 0; i < accountsJson.length; ++i) {
                    let contactEntry = d.getContactModelEntry(accountsJson[i].contactId)
                    d.cardsModel.append({
                                            type: AddEditSavedAddressPopup.CardType.Contact,
                                            address: accountsJson[i].address,
                                            title: ProfileUtils.displayName(contactEntry.contactDetails.localNickname, contactEntry.contactDetails.name, contactEntry.contactDetails.displayName, contactEntry.contactDetails.alias),
                                            icon: contactEntry.contactDetails.icon,
                                            emoji: "",
                                            color: Utils.colorForColorId(root.Theme.palette, contactEntry.contactDetails.colorId),
                                            onlineStatus: contactEntry.contactDetails.onlineStatus
                                        })

                }
            }
            catch (e) {
                console.warn("error parsing fetched accounts for contact: ", e.message)
            }
        }
    }

    StatusScrollView {
        id: scrollView

        anchors.fill: parent
        padding: 0
        topPadding: Theme.bigPadding
        contentWidth: availableWidth

        Column {
            id: column

            width: scrollView.availableWidth
            height: childrenRect.height

            spacing: Theme.xlPadding

            Loader {
                id: limitPopup
                active: false

                sourceComponent: StatusDialog {
                    width: root.width - 2*Theme.padding

                    title: Constants.walletConstants.maxNumberOfSavedAddressesTitle

                    StatusBaseText {
                        anchors.fill: parent
                        text: Constants.walletConstants.maxNumberOfSavedAddressesContent
                        wrapMode: Text.WordWrap
                    }

                    standardButtons: Dialog.Ok

                    onClosed: {
                        limitPopup.active = false
                    }
                }

                onLoaded: {
                    limitPopup.item.open()
                }
            }

            StatusInput {
                id: nameInput
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                charLimit: 24
                input.edit.objectName: "savedAddressNameInput"
                placeholderText: qsTr("Address name")
                label: qsTr("Name")
                validators: [
                    StatusMinLengthValidator {
                        minLength: 1
                        errorMessage: qsTr("Please name your saved address")
                    },
                    StatusValidator {
                        property bool isEmoji: false

                        name: "check-for-no-emojis"
                        validate: (value) => {
                                      if (!value) {
                                          return true
                                      }

                                      isEmoji = Constants.regularExpressions.emoji.test(value)
                                      if (isEmoji){
                                          return false
                                      }

                                      return Constants.regularExpressions.alphanumericalExpanded1.test(value)
                                  }
                        errorMessage: isEmoji?
                                          Constants.errorMessages.emojRegExp
                                        : Constants.errorMessages.alphanumericalExpanded1RegExp
                    },
                    StatusValidator {
                        name: "check-saved-address-existence"
                        validate: (value) => {
                                      return !root.store.savedAddressNameExists(value)
                                      || d.editMode && d.storedName == value
                                  }
                        errorMessage: qsTr("Name already in use")
                    }
                ]
                input.clearable: true
                input.rightPadding: 16
                input.tabNavItem: addressInput

                onKeyPressed: event => {
                    d.submit(event)
                }
            }

            StatusInput {
                id: addressInput
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                label: qsTr("Address")
                objectName: "savedAddressAddressInput"
                input.edit.objectName: "savedAddressAddressInputEdit"
                placeholderText: qsTr("Ethereum address")
                maximumHeight: 66
                input.implicitHeight: Math.min(Math.max(input.edit.contentHeight + topPadding + bottomPadding, minimumHeight), maximumHeight) // setting height instead does not work
                enabled: !(d.editMode || d.addAddress)
                input.edit.textFormat: TextEdit.RichText
                input.rightComponent: (d.resolvingEnsNameInProgress || d.checkingContactsAddressInProgress) ?
                                          loadingIndicator : null
                input.asset.name: d.addressInputValid && !d.editMode ? "checkbox" : ""
                input.asset.color: enabled ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
                input.asset.width: 17
                input.asset.height: 17
                input.rightPadding: 16
                input.leftIcon: false
                input.tabNavItem: nameInput

                warningMode: d.incorrectChecksum
                warningMessage: qsTr("Checksum of the entered address is incorrect")

                multiline: true

                property string plainText: input.edit.getText(0, text.length).trim()

                Component {
                    id: loadingIndicator

                    StatusLoadingIndicator {}
                }

                onTextChanged: {
                    if (skipTextUpdate || !d.initialized)
                        return

                    plainText = input.edit.getText(0, text.length).trim()

                    if (input.edit.previousText != plainText) {
                        setRichText(plainText)

                        // Reset
                        d.resetAddressValues(plainText.length == 0)

                        if (plainText.length > 0) {
                            // Update root values
                            if (Utils.isLikelyEnsName(plainText)) {
                                d.ens = plainText
                                d.address = Constants.zeroAddress
                            }
                            else {
                                d.ens = ""
                                d.address = plainText
                            }
                        }

                        d.checkForAddressInputErrorsWarnings()
                    }
                }

                onKeyPressed: (event) => {
                    d.submit(event)
                }

                property bool skipTextUpdate: false

                function setPlainText(newText) {
                    text = newText
                }

                function setRichText(val) {
                    skipTextUpdate = true
                    input.edit.previousText = plainText
                    const curPos = input.cursorPosition
                    setPlainText(val)
                    input.cursorPosition = curPos
                    skipTextUpdate = false
                }
            }

            Column {
                width: scrollView.availableWidth
                visible: d.cardsModel.count > 0

                spacing: Theme.halfPadding

                Repeater {
                    model: d.cardsModel

                    StatusListItem {
                        width: parent.width
                        border.width: 1
                        border.color: Theme.palette.baseColor2
                        anchors.horizontalCenter: parent.horizontalCenter
                        title: model.title
                        subTitle: model.address
                        statusListItemSubTitle.font.pixelSize: Theme.tertiaryTextFontSize
                        sensor.hoverEnabled: false
                        statusListItemIcon.badge.visible: model.type === AddEditSavedAddressPopup.CardType.Contact
                        statusListItemIcon.badge.color: model.type === AddEditSavedAddressPopup.CardType.Contact && model.onlineStatus === 1?
                                                            Theme.palette.successColor1
                                                          : Theme.palette.baseColor1
                        statusListItemIcon.hoverEnabled: false

                        asset {
                            width: 40
                            height: 40
                            name: model.icon
                            isImage: model.icon !== ""
                            emoji: model.emoji
                            color: model.color
                            isLetterIdenticon: !model.icon
                            letterIdenticonBgWithAlpha: model.type === AddEditSavedAddressPopup.CardType.SavedAddress
                            charactersLen: 2
                        }
                    }
                }
            }

            StatusColorSelectorGrid {
                id: colorSelection
                objectName: "addSavedAddressColor"
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                model: Theme.palette.customisationColorsArray
                title.color: Theme.palette.directColor1
                title.text: qsTr("Colour")
                selectedColorIndex: -1

                onSelectedColorChanged: {
                    d.colorId = Utils.getIdForColor(Theme.palette, selectedColor)
                }
            }
        }
    }

    footer: StatusDialogFooter {
       rightButtons: ObjectModel {
           StatusButton {
               text: d.editMode? qsTr("Save") : qsTr("Add address")
               enabled: d.valid && d.dirty
               onClicked: {
                   d.submit()
               }
               objectName: "addSavedAddress"
           }
       }
   }
}
