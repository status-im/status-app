import QtQml

QtObject {
    id: root

    required property var accountsModel
    property string selectedAddress: ""
    property bool showSavedAddresses: false
    property bool showFollowingAddresses: false
    property var totalCurrencyBalance
    property bool balanceLoading: false
    property bool accountBalanceNotAvailable: false
    property string accountBalanceNotAvailableText: ""

    readonly property bool showAllAccounts:
        !showSavedAddresses && !showFollowingAddresses && !selectedAddress
}
