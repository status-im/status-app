import QtQuick

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

/*!
    \qmltype SettingsList
    \inherits StatusListView
    \inqmlmodule AppLayouts.Profile.controls

    \brief List view rendering setting entries

    Expected model structure:

    subsection          [int]    - identifier of the entry (Constants.settingsSubsection)
    text                [string] - readable name of the entry
    icon                [string] - icon name
    badgeCount          [int]    - number presented on the badge
    isExperimental      [bool]   - indicates if the beta tag should be presented
    experimentalTooltip [string] - tooltip text for the beta tag
*/
StatusListView {
    id: root

    property int currenctSubsection

    signal clicked(int subsection)

    QtObject {
        id: d
        readonly property int horizontalMargins: Theme.halfPadding
    }

    spacing: Theme.halfPadding

    verticalScrollBar.implicitWidth: d.horizontalMargins

    delegate: StatusNavigationListItem {
        id: delegate

        objectName: model.subsection + "-MenuItem"

        anchors.left: root.contentItem.left
        anchors.right: root.contentItem.right
        anchors.margins: d.horizontalMargins

        title: model.text
        Accessible.name: Utils.formatAccessibleName(title, objectName)
        asset.name: model.icon
        selected: root.currenctSubsection === model.subsection
        badge.value: model.badgeCount

        statusListItemTitleIcons.sourceComponent: null

        onClicked: root.clicked(model.subsection)
    }

    section.property: "group"

    section.delegate: StatusBaseText {
        text: section
        color: Theme.palette.baseColor1

        anchors.left: root.contentItem.left
        anchors.right: root.contentItem.right
        anchors.margins: d.horizontalMargins

        topPadding: Theme.smallPadding
        bottomPadding: Theme.smallPadding
    }
}
