// Mock of src/app/modules/main/wallet_section/assets/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionAssets"

    // key + balances submodel, per assets/grouped_account_assets_model.nim
    property var groupedAccountAssetsModel: emptyModel

    property bool hasBalanceCache: true
    property bool hasMarketValuesCache: true

    readonly property ListModel emptyModel: ListModel {}
}
