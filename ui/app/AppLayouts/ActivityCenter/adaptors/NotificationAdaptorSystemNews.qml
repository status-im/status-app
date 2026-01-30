import QtQuick

import StatusQ.Core.Theme

NotificationAdaptorBase {
    avatarSource: Assets.png("status-logo-icon")
    title: notification.newsTitle
    preImageSource: notification.newsImageUrl ?? ""
    content: {
        const d = notification.newsDescription ?? ""
        if (d.length) {
            return d
        }
        const c = notification.newsContent ?? ""
        if (c.length) {
            return c
        }
    }
    redirectToLink: true
}
