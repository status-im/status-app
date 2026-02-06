import QtQuick

import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme
import StatusQ.Components

Rectangle {
    id: root

    Accessible.role: Accessible.Button
    Accessible.name: Utils.formatAccessibleName("", objectName)

    property StatusAssetSettings icon: StatusAssetSettings {
        width: 24
        height: 24
        rotation: 0

        color: {
            switch(root.type) {
            case StatusFlatRoundButton.Type.Secondary:
                return root.Theme.palette.directColor1;
            case StatusFlatRoundButton.Type.Primary:
                return root.Theme.palette.primaryColor1;
            case StatusFlatRoundButton.Type.Tertiary:
                return hovered ? root.Theme.palette.primaryColor1: root.Theme.palette.baseColor1;
            case StatusFlatRoundButton.Type.Quaternary:
                return hovered ? root.Theme.palette.primaryColor1: root.Theme.palette.directColor1;
            }
        }

        disabledColor: {
            switch(root.type) {
            case StatusFlatRoundButton.Type.Secondary:
            case StatusFlatRoundButton.Type.Primary:
            case StatusFlatRoundButton.Type.Tertiary:
            case StatusFlatRoundButton.Type.Quaternary:
                return root.Theme.palette.baseColor1;
            }
        }
    }

    property bool loading: false

    property alias hovered: sensor.containsMouse
    property alias tooltip: statusToolTip
    property alias backgroundHoverColor: backgroundSettings.hoverColor
    readonly property alias sensor: sensor

    property bool highlighted: false

    property int type: StatusFlatRoundButton.Type.Primary

    signal pressed(var mouse)
    signal released(var mouse)
    signal clicked(var mouse)
    signal pressAndHold(var mouse)

    enum Type {
        Primary,
        Secondary,
        Tertiary,
        Quaternary
    }

    /// Implementation

    QtObject {
        id: backgroundSettings

        property color color: {
            switch(root.type) {
            case StatusFlatRoundButton.Type.Primary:
            case StatusFlatRoundButton.Type.Secondary:
            case StatusFlatRoundButton.Type.Tertiary:
            case StatusFlatRoundButton.Type.Quaternary:
                return "transparent";
            }
        }

        property color hoverColor: {
            switch(root.type) {
            case StatusFlatRoundButton.Type.Primary:
                return root.Theme.palette.primaryColor3;
            case StatusFlatRoundButton.Type.Secondary:
            case StatusFlatRoundButton.Type.Tertiary:
            case StatusFlatRoundButton.Type.Quaternary:
                return root.Theme.palette.baseColor2;
            }
        }

        property color disabledColor: {
            switch(root.type) {
            case StatusFlatRoundButton.Type.Primary:
            case StatusFlatRoundButton.Type.Secondary:
            case StatusFlatRoundButton.Type.Tertiary:
            case StatusFlatRoundButton.Type.Quaternary:
                return "transparent";
            }
        }

        property color highlightedColor: {
            switch(root.type) {
            case StatusFlatRoundButton.Type.Primary:
                return root.Theme.palette.primaryColor3;
            case StatusFlatRoundButton.Type.Secondary:
            case StatusFlatRoundButton.Type.Tertiary:
            case StatusFlatRoundButton.Type.Quaternary:
                return root.Theme.palette.baseColor4;
            }
        }
    }

    implicitWidth: 44
    implicitHeight: 44
    radius: 8

    color: {
        if (root.enabled) {
            if (sensor.containsMouse) {
                return backgroundSettings.hoverColor
            }
            return highlighted ? backgroundSettings.highlightedColor : backgroundSettings.color
        } else {
            return backgroundSettings.disabledColor
        }
    }
    StatusMouseArea {
        id: sensor

        anchors.fill: parent
        cursorShape: root.loading ? Qt.ArrowCursor
                             : Qt.PointingHandCursor
        hoverEnabled: !root.loading
        enabled: !root.loading


        StatusIcon {
            id: statusIcon
            anchors.centerIn: parent
            visible: !root.loading

            icon: root.icon.name
            source: root.icon.source
            rotation: root.icon.rotation

            width: root.icon.width
            height: root.icon.height

            color: {
                if (root.enabled) {
                    return root.icon.color
                } else {
                    return root.icon.disabledColor
                }
            }
        } // Icon
        Loader {
            active: root.loading
            anchors.centerIn: parent
            sourceComponent: StatusLoadingIndicator {
                color: {
                    if (root.enabled) {
                        return root.icon.color
                    } else {
                        return root.icon.disabledColor
                    }
                }
            } // Indicator
        } // Loader

        onClicked: mouse => root.clicked(mouse)
        onPressed: mouse => root.pressed(mouse)
        onReleased: mouse => root.released(mouse)
        onPressAndHold: mouse => root.pressAndHold(mouse)
    } // Sensor

    StatusToolTip {
        id: statusToolTip
        visible: !!text && root.hovered
    } // Tooltip
} // Rectangle
