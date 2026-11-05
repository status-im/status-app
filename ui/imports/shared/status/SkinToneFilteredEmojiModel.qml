import QtQuick

import StatusQ

import SortFilterProxyModel

/*!
   \qmltype SkinToneFilteredEmojiModel
   \brief Emoji catalogue in display order, keeping only the variants of the
   chosen skin tone (or the base variants when \c skinColor is empty).
*/
SortFilterProxyModel {
    id: root

    required property StatusEmojiModel emojiModel
    property string skinColor

    sourceModel: root.emojiModel

    filters: AnyOf {
        ValueFilter {
            roleName: "skinColor"
            value: ""
        }
        ValueFilter {
            roleName: "skinColor"
            value: root.skinColor !== "" ? root.skinColor : root.emojiModel.baseSkinColorName
        }
    }

    sorters: RoleSorter {
        roleName: "emoji_order"
    }
}
