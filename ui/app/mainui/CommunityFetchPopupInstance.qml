import AppLayouts.Communities.popups
import AppLayouts.Communities.stores as CommunitiesStores

CommunityFetchPopup {
    id: root

    required property CommunitiesStores.CommunitiesStore communitiesStore

    state: root.communitiesStore.communityFetchState
    timeoutSeconds: root.communitiesStore.communityFetchTimeoutSeconds

    onCancelRequested: root.communitiesStore.cancelPendingCommunityFetch()
    onTimeoutRequested: root.communitiesStore.timeoutPendingCommunityFetch()
    onDismissFailedRequested: root.communitiesStore.clearCommunityFetchFailure()
    onRetryRequested: root.communitiesStore.retryCommunityFetch()
}
