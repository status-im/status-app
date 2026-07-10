import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core.Theme

import utils

HomePageGridItem {
    id: root

    sectionType: Constants.appSection.profile
    color: Theme.palette.primaryColor2

    iconLoaderComponent: StatusRoundIcon {
        asset.name: root.icon.name
        asset.bgWidth: width
        asset.bgHeight: height
    }
}
