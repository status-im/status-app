import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

ToolBar {
    id: root

    property string backButtonName: ""
    property Item headerContent
    property bool backButtonVisible: !!backButtonName

    signal backButtonClicked()

    objectName: "statusToolBar"
    padding: Theme.halfPadding
    // The Qt 6.10+ style delegates bind the edge paddings to SafeArea.margins,
    // which pushes the header out of the macOS titlebar area. Our headers are
    // deliberately laid out into the titlebar (ExpandedClientAreaHint), so pin
    // all edges back to the uniform padding. FIXES #20212
    topPadding: padding
    leftPadding: padding
    rightPadding: padding
    bottomPadding: padding
    background: null

    contentItem: RowLayout {
        spacing: 0
        StatusFlatButton {
            Layout.leftMargin: Theme.smallPadding*2
            objectName: "toolBarBackButton"
            icon.name: "arrow-left"
            visible: root.backButtonVisible
            text: root.backButtonName
            onClicked: { root.backButtonClicked(); }
        }

        Control {
            id: headerContentItem
            Layout.fillWidth: !!headerContent
            Layout.fillHeight: !!headerContent
            Layout.margins: root.padding
            background: null
            contentItem: (!!headerContent) ? headerContent : null
        }
    }
}
