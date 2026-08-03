import QtQuick

QtObject {
    property var walletModule: QtObject {
        property bool hasPairedDevices: false
    }

    property var accountsModule: null
    property var selectedAccount
    property var accounts: null

    signal loggedInUserAuthenticated(string requestedBy, string password, string pin, string keyUid, string keycardUid)

    function authenticateLoggedInUser(_requestedBy) {}
    function deleteAccount(_address, _password) { return "" }
    function updateAccount(_address, _accountName, _colorId, _emoji) { return "" }
    function updateWatchAccountHiddenFromTotalBalance(_address, _hideFromTotalBalance) {}
}
