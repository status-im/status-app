import QtQuick

// Required mock of: src/app/modules/main/wallet_section/overview/view.nim

Item {
    id: root

    readonly property string contextPropertyName: "walletSectionOverview"

    property string name: qsTr("All accounts")
    property string mixedcaseAddress: ""
    property var ens: ""
    property var currencyBalance: ({
        amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false
    })
    property bool balanceLoading: false
    // strings, like overview/view.nim: colorIds is a ";"-separated list
    property var colorId: "primary"
    property var colorIds: "primary"
    property var emoji: ""
    property bool isAllAccounts: true
    property bool isWatchOnlyAccount: false
    property bool canSend: true
}
