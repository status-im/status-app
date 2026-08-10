import QtQuick

QtObject {
    readonly property MessagingSettingsStore messagingSettingsStore: MessagingSettingsStore {}

    function createCommunityRootStore(parent, communityId) {
        if (MessagingStoresConfig.communityRootStoreFactory)
            return MessagingStoresConfig.communityRootStoreFactory(parent, communityId)
        console.warn("Stub MessagingRootStore: no communityRootStoreFactory installed")
        return null
    }
}
