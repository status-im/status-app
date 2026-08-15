// Mock of src/app/modules/main/wallet_section/all_collectibles/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionAllCollectibles"

    // 20 roles of shared_models/collectibles_model.nim, plus hasMore/fetchMore —
    // the only paginated surface in the section.
    property var allCollectiblesModel: emptyModel

    property int lastCreatedSelectorModelId: -1
    property bool collectibleGroupByCommunity: false
    property bool collectibleGroupByCollection: false
    property string collectiblePreferencesJson: "[]"

    readonly property ListModel emptyModel: ListModel {
        readonly property bool hasMore: false
        readonly property bool isFetching: false
        readonly property bool isUpdating: false
        readonly property bool isError: false
        function loadMore() {}
        function getUidForData(tokenId, tokenAddress, chainId) { return "" }
    }

    function createCollectiblesSelectorModel() {
        root.lastCreatedSelectorModelId++
        return root.allCollectiblesModel
    }
    function releaseCollectiblesSelectorModel(id) {}

    function updateCollectiblePreferences(json) { root.collectiblePreferencesJson = json }
    function getCollectiblePreferencesJson() { return root.collectiblePreferencesJson }

    function toggleCollectibleGroupByCommunity() {
        root.collectibleGroupByCommunity = !root.collectibleGroupByCommunity
        return root.collectibleGroupByCommunity
    }
    function toggleCollectibleGroupByCollection() {
        root.collectibleGroupByCollection = !root.collectibleGroupByCollection
        return root.collectibleGroupByCollection
    }
}
