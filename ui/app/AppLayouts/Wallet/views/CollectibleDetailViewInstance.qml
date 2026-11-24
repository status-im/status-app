import "collectibles"

CollectibleDetailView {
    id: root

    collectible: root.walletRootStore.collectiblesStore.detailedCollectible
    isCollectibleLoading: root.walletRootStore.collectiblesStore.isDetailedCollectibleLoading
    addressFilters: root.walletRootStore.addressFilters
}
