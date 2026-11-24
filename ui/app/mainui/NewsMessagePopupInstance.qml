import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

NewsMessagePopup {
    id: root

    required property AppLayoutStores.ActivityCenterStore activityCenterStore

    activityCenterNotifications: root.activityCenterStore.activityCenterNotifications
    onLinkClicked: (link) => {
                       if (Utils.isStatusDeepLink(link))
                           Global.activateDeepLink(link)
                       else
                           Global.requestOpenLink(link)
                       close()
                   }
}
