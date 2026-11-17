import QtQuick

import StatusQ

import utils

// Filters out Attachments that AttachmentPreparer rejected (e.g. an animation over the size
// limit). Rejections arrive asynchronously, after the images were added: reject() shows the
// reason for a while once the rejected Attachment has been removed.
StatusChatImageValidator {
    id: root

    function reject(reason) {
        root.errorMessage = reason
        root.isValid = false
        hideTimer.restart()
    }

    onImagesChanged: {
        const rejected = images.filter(img => AttachmentPreparer.isRejected(img.toString()))
        root.validImages = images.filter(img => !rejected.includes(img))
        if (rejected.length > 0)
            root.reject(AttachmentPreparer.rejectionReason(rejected[0].toString()))
    }

    Timer {
        id: hideTimer
        interval: 5000
        onTriggered: root.isValid = true
    }
}
