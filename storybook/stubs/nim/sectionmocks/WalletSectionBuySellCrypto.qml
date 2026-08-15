// Mock of src/app/modules/main/wallet_section/buy_sell_crypto/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionBuySellCrypto"

    property ListModel model: ListModel {}
    property bool isFetching: false

    signal providerUrlReady(string uuid, string url)

    function fetchProviders() {}
    function fetchProviderUrl(uuid, providerID, isRecurrent, selectedWalletAddress, chainID, symbol) {
        root.providerUrlReady(uuid, "https://example.status.app/buy")
    }
}
