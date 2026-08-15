// Mock of src/app/modules/main/wallet_section/token_selector/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionTokenSelector"

    property int lastPreparedModelId: -1

    // Factory installed by WalletSectionMock: (kind) -> terminal picker model.
    // Without it prepareModel hands back an empty model, which is what the
    // pickers show for a profile with no tokens.
    property var modelFactory: null

    property var _preparedModel: null
    property var preparedKinds: []

    readonly property ListModel emptyModel: ListModel {
        property int enabledChainId: -1
        property string accountAddress: ""
        property bool showZeroBalanceForDefaultTokens: false
        property bool showCommunityAssets: false
        property bool hasMoreItems: false
        property bool isLoadingMore: false
        property string searchString: ""

        function search(keyword) {}
        function fetchMore() {}
        function setSectionNames(owned, popular) {}
    }

    function prepareModel(kind) {
        root.preparedKinds = root.preparedKinds.concat([kind])
        root.lastPreparedModelId++
        root._preparedModel = root.modelFactory ? root.modelFactory(kind) : root.emptyModel
    }

    function getPreparedModel() {
        return root._preparedModel ? root._preparedModel : root.emptyModel
    }

    function releaseModel(id) {}
}
