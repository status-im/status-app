pragma ComponentBehavior: Bound

import QtQuick
import StatusQ.Core.Theme

QtObject {
    id: root

    property int width
    property int height
    property bool isIdenticon: false

    property string name
    property string pubkey
    property bool interactive: true

    property color color

    property StatusAssetSettings assetSettings: StatusAssetSettings {
        width: root.width
        height: root.height
        name: root.name
        isLetterIdenticon: (name === "")
        imgIsIdenticon: root.isIdenticon
        color: root.color
        charactersLen: 2
    }
}
