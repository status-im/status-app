import QtQuick

import utils

/*!
    Mock of `src/app/modules/shared_modules/add_account/view.nim`, enough for
    `AddAccountPopup` to open and render its **Main** state against the generated
    keypairs: origin selection, derived-address list, name/colour/emoji.

    Deliberately shallow: the module is a state machine driven from Nim
    (SelectMasterKey / EnterSeedPhrase / DisplaySeedPhrase / …) and the actions
    that leave Main are no-ops here. Anything past the first screen — importing a
    seed phrase or private key, or actually creating the account — is not
    reproduced.
*/
QtObject {
    id: root

    // The generated wallet accounts, so origins carry the same accounts the
    // section shows. Rows need `keyUid`, `name`, `colorId`, `emoji`.
    property var accountsModel: null

    readonly property QtObject currentState: QtObject {
        readonly property string stateType: Constants.addAccountPopup.state.main
        readonly property bool displayBackButton: false

        function doPrimaryAction() {}
        function doSecondaryAction() {}
        function doTertiaryAction() {}
        function doQuaternaryAction() {}
        function doBackAction() {}
        function doCancelAction() {}
    }

    property bool editMode: false
    property bool disablePopup: false
    property bool actionAuthenticated: false
    property bool scanningForActivityIsOngoing: false

    property string accountName: ""
    property string newKeyPairName: ""
    property string selectedEmoji: ""
    property string selectedColorId: ""
    property string derivationPath: "m/44'/60'/0'/0/1"
    readonly property string suggestedDerivationPath: "m/44'/60'/0'/0/1"

    property var selectedOrigin: root.originModel.length > 0 ? root.originModel[0].keyPair
                                                             : root._watchOnlyOrigin

    // JS array rather than a ListModel: the origin rows nest an accounts list per
    // keypair, which ListModel cannot hold.
    readonly property var originModel: {
        const byKeyUid = new Map()
        const count = root.accountsModel ? root.accountsModel.count : 0
        for (let i = 0; i < count; ++i) {
            const account = root.accountsModel.get(i)
            if (!account.keyUid)
                continue
            if (!byKeyUid.has(account.keyUid)) {
                byKeyUid.set(account.keyUid, {
                    keyUid: account.keyUid,
                    name: account.keyUid === userProfile.keyUid ? qsTr("Status profile")
                                                                : qsTr("Seed phrase %1").arg(byKeyUid.size),
                    icon: "",
                    image: "",
                    pairType: account.keyUid === userProfile.keyUid
                              ? Constants.addAccountPopup.keyPairType.profile
                              : Constants.addAccountPopup.keyPairType.seedImport,
                    migratedToColdWallet: false,
                    derivesFromXpub: true,
                    accounts: []
                })
            }
            byKeyUid.get(account.keyUid).accounts.push({
                account: {
                    name: account.name,
                    colorId: account.colorId,
                    emoji: account.emoji,
                    icon: ""
                }
            })
        }
        const rows = []
        for (const keyPair of byKeyUid.values())
            rows.push({ keyPair })
        rows.push({ keyPair: root._watchOnlyOrigin })
        return rows
    }

    readonly property var _watchOnlyOrigin: ({
        keyUid: Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc,
        name: Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc,
        icon: "show",
        image: "",
        pairType: Constants.addAccountPopup.keyPairType.unknown,
        migratedToColdWallet: false,
        derivesFromXpub: false,
        accounts: []
    })

    readonly property ListModel derivedAddressModel: ListModel {}

    property var selectedDerivedAddress: root._emptyAddressDetails
    property var watchOnlyAccAddress: root._emptyAddressDetails
    property var privateKeyAccAddress: root._emptyAddressDetails

    readonly property var _emptyAddressDetails: ({
        address: "", order: 0, alreadyCreated: false, hasActivity: false,
        detailsLoaded: false, errorInScanningActivity: false
    })

    signal confirmSavedAddressRemoval(string name, string address)
    signal xpubMissingForSelectedOrigin(string keypairName)
    signal authenticationRequested(string keyUid)

    function getStoredAccountName() { return "" }
    function getStoredSelectedEmoji() { return "" }
    function getStoredSelectedColorId() { return "" }
    function getSeedPhrase() { return "" }

    function changeSelectedOrigin(keyUid) {
        for (const row of root.originModel) {
            if (row.keyPair.keyUid === keyUid) {
                root.selectedOrigin = row.keyPair
                return
            }
        }
    }

    function changeDerivationPath(path) { root.derivationPath = path }
    function changeSelectedDerivedAddress(address) {}
    function changeWatchOnlyAccountAddress(address) {}
    function changePrivateKey(privateKey) {}
    function changeSeedPhrase(seedPhrase) {}
    function validSeedPhrase(seedPhrase) { return false }
    function resetDerivationPath() {}
    function authenticateForEditingDerivationPath() {}
    function authenticationCompleted(password, pin, keyUid) {}
    function startScanningForActivity() {}
    function isChecksumValidForAddress(address) { return true }
    function remainingAccountCapacity() { return 10 }
    function remainingKeypairCapacity() { return 10 }
    function remainingWatchOnlyAccountCapacity() { return 10 }
    function removingSavedAddressRejected() {}
    function removingSavedAddressConfirmed() {}
}
