pragma ComponentBehavior: Bound

import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Core

StatusFlatRoundButton {
    id: statusChatListCategoryItemButton

    height: 22
    width: 22
    radius: 4

    property bool highlighted: false

    type: StatusFlatRoundButton.Type.Secondary
    icon.width: 20
    icon.color: Theme.palette.directColor4

    color: hovered || highlighted ? 
        Theme.palette.statusChatListCategoryItem.buttonHoverBackgroundColor : 
        "transparent"
}
