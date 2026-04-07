pragma ComponentBehavior: Bound

import QtQuick

Image {
    property string emojiId: ""

    width: 14
    height: 14
    sourceSize.width: width
    sourceSize.height: height

    fillMode: Image.PreserveAspectFit
    mipmap: true
    antialiasing: true
    source: emojiId ? Qt.resolvedUrl(`../../assets/twemoji/svg/${emojiId}.svg`) : ""
}
