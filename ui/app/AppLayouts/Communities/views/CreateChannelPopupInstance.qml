import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.popups

CreateChannelPopup {
    id: root

    required property ChatStores.RootStore store

    assetsModel: root.store.assetsModel
    assetsLoading: root.store.tokenListLoading
    acquireTokenList: root.store.acquireTokenList
    releaseTokenList: root.store.releaseTokenList
    collectiblesModel: root.store.collectiblesModel
    channelsModel: root.store.chatCommunitySectionModule.model

    onCreateCommunityChannel: function (chName, chDescription, chEmoji, chColor,
                                        chCategoryId, viewOnlyCanAddReaction, hideIfPermissionsNotMet) {
        root.store.createCommunityChannel(chName, chDescription, chEmoji, chColor,
                                          chCategoryId, viewOnlyCanAddReaction, hideIfPermissionsNotMet)
        root.chatId = root.store.currentChatContentModule().chatDetails.id
    }
    onEditCommunityChannel: function (chName, chDescription, chEmoji, chColor,
                                      chCategoryId, viewOnlyCanAddReaction, hideIfPermissionsNotMet) {
        root.store.editCommunityChannel(root.chatId,
                                        chName,
                                        chDescription,
                                        chEmoji,
                                        chColor,
                                        chCategoryId,
                                        root.channelPosition,
                                        viewOnlyCanAddReaction,
                                        hideIfPermissionsNotMet)
    }
}
