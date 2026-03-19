import QtQuick
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

Rectangle {
    id: root

    property alias identiconText: identiconText
    property string name
    property string emoji
    property string emojiSize: Emoji.size.small
    property int letterSize: 21
    property int charactersLen: 1
    property color letterIdenticonColor: Theme.palette.miscColor5

    // In this mode, one or two letters are used depending on words used:
    // John -> J
    // John Smith -> JS
    // John Smith Junior -> JS
    //
    // characterLen is ignored
    property bool useAcronymForLetterIdenticon: false
    property bool backgroundWithAlpha: useAcronymForLetterIdenticon

    color: {
        if (!root.backgroundWithAlpha)
            return root.letterIdenticonColor

        return Qt.rgba(root.letterIdenticonColor.r,
                       root.letterIdenticonColor.g,
                       root.letterIdenticonColor.b, 0.2)
    }

    width: 40
    height: 40
    radius: width / 2

    StatusEmoji {
        visible: !!root.emoji
        anchors.centerIn: parent
        width: Math.round(parent.width / 2)
        height: Math.round(parent.height / 2)
        emojiId: Emoji.iconId(root.emoji, root.emojiSize) || Emoji.iconHex(root.emoji) || ""
    }

    StatusBaseText {
        id: identiconText

        visible: !root.emoji
        anchors.alignWhenCentered: false
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width: parent.width
        height: parent.height

        font.weight: Font.Bold
        font.pixelSize: root.letterSize
        color: {
            if (root.backgroundWithAlpha)
                return root.letterIdenticonColor

            return ColorUtils.luminance(root.letterIdenticonColor) > 0.5 ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.7)
        }

        text: {
            const parts = root.name.split(" ")

            if (root.useAcronymForLetterIdenticon) {
                let word = ""

                for (let i = 0; i < Math.min(parts.length, 2); i++) {
                    let shift = (parts[i].charAt(0) === "#") ||
                                (parts[i].charAt(0) === "@")

                    word += parts[i].substring(shift, shift + 1).toUpperCase()
                }

                return word
            }

            const shift = (root.name.charAt(0) === "#") ||
                          (root.name.charAt(0) === "@")
            return root.name.substring(shift, shift + charactersLen)
        }
    }


}
