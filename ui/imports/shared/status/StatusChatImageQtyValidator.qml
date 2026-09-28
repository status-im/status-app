import QtQuick

import utils

StatusChatImageValidator {
    id: root

    // 0 = no limit (the host splits the send itself)
    property int maxImages: Constants.maxUploadFiles

    errorMessage: qsTr("You can only upload %n image(s) at a time", "", root.maxImages)

    onImagesChanged: {
        if (root.maxImages <= 0) {
            root.isValid = true
            root.validImages = images
            return
        }
        root.isValid = images.length <= root.maxImages
        root.validImages = images.slice(0, root.maxImages)
    }
}
