import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.ActivityCenter.views

import Storybook

ActivityNotificationBaseLayout {
    id: root

    communityEditorActive: false
    contactEditorActive: true
    activityNotificationComponent: ActivityNotificationContactRemoved {
        notification: baseEditor.notificationBaseMock
        contactsModel: ListModel {}
        contactDetails: conntactEditor.contactDetailsMock

        onOpenProfilePopup: (contactId) =>
                            logs.logEvent("ActivityNotificationContactRemoved::onOpenProfilePopup" + contactId)
    }
}
// category: Activity Center
// status: good
