pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    property string title
    property string subTitle
    property int titleElide: Text.ElideRight
    property int subTitleElide: Text.ElideRight
    property bool headerImageEditable: false
    property bool editable: false
    property Component popupMenu

    property StatusAssetSettings asset: StatusAssetSettings {
        width: 40
        height: 40
        isLetterIdenticon: false
        imgIsIdenticon: false
    }
}
