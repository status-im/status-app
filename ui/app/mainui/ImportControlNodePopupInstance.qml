import AppLayouts.Communities.popups
import AppLayouts.stores as AppLayoutStores

ImportControlNodePopup {
    id: root

    required property AppLayoutStores.RootStore rootStore

    onImportControlNode: communityId => root.rootStore.promoteSelfToControlNode(communityId)
}
