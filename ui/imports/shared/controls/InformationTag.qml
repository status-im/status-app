import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import utils

Control {
    id: root

    property alias tagPrimaryLabel: tagPrimaryLabel
    property alias tagSecondaryLabel: tagSecondaryLabel
    property alias middleLabel: middleLabel
    property alias asset: smartIdenticon.asset
    property alias rightComponent: rightComponent.sourceComponent
    property alias leftComponent: leftComponent.sourceComponent
    property bool loading: false
    property int secondarylabelMaxWidth: 100

    property color backgroundColor: "transparent"
    property color bgBorderColor: Theme.palette.baseColor2
    property real bgRadius: 36

    property Component customBackground: Component {
        Rectangle {
            color: root.backgroundColor
            border.width: 1
            border.color: root.bgBorderColor
            radius: root.bgRadius
        }
    }

    QtObject {
        id: d
        property var loadingComponent: Component { LoadingComponent { radius: root.bgRadius } }
    }

    horizontalPadding: 12
    verticalPadding: 8
    spacing: 4

    background: Loader {
        sourceComponent: root.loading ? d.loadingComponent : root.customBackground
    }

    contentItem: RowLayout {
        spacing: root.spacing
        visible: !root.loading
        Loader {
            id: leftComponent
        }
        StatusSmartIdenticon {
            id: smartIdenticon
            Layout.maximumWidth: visible ? asset.bgWidth : 0
            Layout.maximumHeight: visible ? asset.bgHeight : 0
            asset.width: visible ? 16 : 0
            asset.height: visible ? 16 : 0
            asset.bgHeight: visible ? asset.height : 0
            asset.bgWidth: visible ? asset.width : 0
            asset.color: Theme.palette.directColor1
            visible: !!asset.name
        }
        StatusBaseText {
            id: tagPrimaryLabel
            Layout.fillWidth: true
            font.pixelSize: Theme.tertiaryTextFontSize
            visible: text !== ""
            elide: Text.ElideRight
            wrapMode: Text.Wrap
        }
        StatusBaseText {
            id: middleLabel
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.baseColor1
            visible: text !== ""
        }
        StatusBaseText {
            id: tagSecondaryLabel
            Layout.maximumWidth: root.secondarylabelMaxWidth
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.baseColor1
            visible: text !== ""
            elide: Text.ElideMiddle
        }
        Loader {
            id: rightComponent
            Layout.preferredWidth: active ? implicitWidth : 0
            active: !!sourceComponent
        }
    }
}
