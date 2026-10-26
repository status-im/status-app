import QtQuick

import utils

StatusChatImageValidator {
    id: root

    property int maxImages: Constants.maxUploadFiles

    errorMessage: qsTr("You can only upload %n image(s) at a time", "", root.maxImages)

    onImagesChanged: {
        root.isValid = images.length <= root.maxImages
        root.validImages = images.slice(0, root.maxImages)
    }
}
