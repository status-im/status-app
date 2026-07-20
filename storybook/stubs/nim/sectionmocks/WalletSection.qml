import QtQuick

// Required mock of: src/app/modules/main/wallet_section/view.nim

Item {
    readonly property string contextPropertyName: "walletSection"

    // Required
    //
    readonly property bool walletReady: true

    //
    // Silence warnings
    readonly property QtObject overview: QtObject {
        readonly property string mixedcaseAddress: ""
    }
    readonly property ListModel mixedcaseAddress: ListModel {}

    signal displayAddAccountPopup
    signal destroyAddAccountPopup
    signal walletAccountRemoved(string address)
}