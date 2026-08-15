// Mock of src/app/modules/main/wallet_section/assets_view/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionAssetsView"

    // Terminal, already-aggregated assets model (24 roles of
    // shared_models/assets_adaptor_model.nim). Storybook cannot run the Nim
    // aggregation, so the mock emits the terminal shape directly.
    property var assetsModel: emptyModel

    // Set by WalletSectionMock; sortBy is forwarded to the generated model.
    property var profile: null

    readonly property ListModel emptyModel: ListModel {}

    function sortBy(roleName, order) {
        if (root.profile)
            root.profile.sortAssets(roleName, order)
    }
}
