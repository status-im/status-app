pragma ComponentBehavior: Bound

import QtQuick
import StatusQ.Core
import StatusQ.Core.Theme

StatusAction {
    id: root

    property string value: ""

    assetSettings.isImage: assetSettings.name.toString() !== ""
    assetSettings.isLetterIdenticon: assetSettings.name.toString() === ""
    assetSettings.color: assetSettings.name === "channel" ? Theme.palette.directColor1 : icon.color
    assetSettings.letterSize: assetSettings.charactersLen > 1 ? 8 : 11
    assetSettings.imgIsIdenticon: false
}
