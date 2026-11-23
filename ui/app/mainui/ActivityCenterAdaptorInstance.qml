import QtQml

import AppLayouts.ActivityCenter.adaptors
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.stores as AppLayoutStores

ActivityCenterAdaptor {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore
    required property ProfileStores.ProfileStore profileStore
    required property AppLayoutStores.ActivityCenterStore activityCenterStore
    required property ChatStores.RootStore rootChatStore

    contactsModel: root.contactsStore?.contactsModel ?? null
    userProfileName: root.profileStore?.name ?? ""
    notifications: root.activityCenterStore?.activityCenterNotifications ?? null
    getCommunityDetails: communityId => root.rootChatStore?.getCommunityDetailsAsJson(communityId) ?? ({})
    getChatDetails: chatId => root.rootChatStore?.getChatDetails(chatId) ?? ({})

    onPopulateContactDetailsRequested: contactId => root.contactsStore.populateContactDetails(contactId)
}
