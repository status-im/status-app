import QtQuick
import utils

import StatusQ.Core.Utils as SQUtils
import MobileUI

QtObject {
    id: root

    property var notificationsModule
    property var notificationsSettings: appSettings

    property var exemptionsModel: notificationsModule.exemptionsModel

    function loadExemptions() {
        root.notificationsModule.loadExemptions()
    }

    function sendTestNotification(title, message) {
        if (SQUtils.Utils.isIOS) {
            // Post a test 1:1 notification through the iOS local-notification path so the
            // rendering can be verified on demand. No avatar is supplied, so the native
            // side draws an initials avatar; the fixed identifier lets the delegate
            // surface it in the foreground (see willPresentNotification). Trailing
            // params (avatarBase64, conversationName, deepLink) use their defaults.
            PushNotifications.showNotification(title, message, "status-test-notification",
                                               "status-test-notification", title, "0xtest")
            return
        }
        root.notificationsModule.sendTestNotification(title, message)
    }

    function saveExemptions(itemId, muteAllMessages, personalMentions, globalMentions, allMessages) {
        root.notificationsModule.saveExemptions(itemId, muteAllMessages, personalMentions, globalMentions, allMessages)
    }
}
