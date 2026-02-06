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
        id: icon
        width: 23
        height: 23
        rotation: 0

        hoverColor: {
            switch(root.type) {
            case StatusRoundButton.Type.Primary:
                return root.Theme.palette.primaryColor1;
            case StatusRoundButton.Type.Secondary:
                return root.Theme.palette.indirectColor1;
            case StatusRoundButton.Type.Tertiary:
                return root.Theme.palette.primaryColor1;
            case StatusRoundButton.Type.Quaternary:
                return root.Theme.palette.dangerColor1;
            case StatusRoundButton.Type.Quinary:
                return root.Theme.palette.directColor1;
            }
        }

        color: {
            switch(root.type) {
            case StatusRoundButton.Type.Primary:
                return root.Theme.palette.primaryColor1;
            case StatusRoundButton.Type.Secondary:
                return root.Theme.palette.indirectColor1;
            case StatusRoundButton.Type.Tertiary:
                return root.Theme.palette.baseColor1;
            case StatusRoundButton.Type.Quaternary:
                return root.Theme.palette.dangerColor1;
            case StatusRoundButton.Type.Quinary:
                return root.Theme.palette.directColor1;
            }
        }

        disabledColor: {
            switch(root.type) {
            case StatusRoundButton.Type.Primary:
                return root.Theme.palette.baseColor1;
            case StatusRoundButton.Type.Secondary:
                return root.Theme.palette.indirectColor1;
            case StatusRoundButton.Type.Tertiary:
                return root.Theme.palette.baseColor1;
            case StatusRoundButton.Type.Quaternary:
                return root.Theme.palette.baseColor1;
            case StatusRoundButton.Type.Quinary:
                return root.Theme.palette.baseColor1;
            }
        }
    }

    property bool loading: false

    property alias hovered: sensor.containsMouse
    property alias hoverEnabled: sensor.hoverEnabled

    property bool highlighted: false

    property int type: StatusRoundButton.Type.Primary

    signal pressed(var mouse)
    signal released(var mouse)
    signal clicked(var mouse)
    signal pressAndHold(var mouse)

    enum Type {
        Primary,
        Secondary,
        Tertiary,
        Quaternary,
        Quinary
    }
    /// Implementation

    QtObject {
        id: backgroundSettings

        property color color: {
            switch(root.type) {
            case StatusRoundButton.Type.Primary:
                return root.Theme.palette.primaryColor3;
            case StatusRoundButton.Type.Secondary:
                return root.Theme.palette.primaryColor1;
            case StatusRoundButton.Type.Tertiary:
                return "transparent";
            case StatusRoundButton.Type.Quaternary:
                return root.Theme.palette.dangerColor3;
            case StatusRoundButton.Type.Quinary:
                return "transparent";
            }
        }

        property color hoverColor: {
            switch(root.type) {
            case StatusRoundButton.Type.Primary:
                return root.Theme.palette.primaryColor2;
            case StatusRoundButton.Type.Secondary:
                return root.Theme.palette.miscColor1;
            case StatusRoundButton.Type.Tertiary:
                return root.Theme.palette.primaryColor3;
            case StatusRoundButton.Type.Quaternary:
                return root.Theme.palette.dangerColor2;
            case StatusRoundButton.Type.Quinary:
                return root.Theme.palette.primaryColor3;
            }
        }

        property color disabledColor: {
            switch(root.type) {
            case StatusRoundButton.Type.Primary:
                return root.Theme.palette.baseColor2;
            case StatusRoundButton.Type.Secondary:
                return root.Theme.palette.baseColor1;
            case StatusRoundButton.Type.Tertiary:
                return "transparent";
            case StatusRoundButton.Type.Quaternary:
                return root.Theme.palette.baseColor2;
            case StatusRoundButton.Type.Quinary:
                return "transparent";
            }
        }
    }

    QtObject {
        id: d
        readonly property color iconColor: !root.enabled ? root.icon.disabledColor :
                                                           (root.enabled && (root.hovered || root.highlighted)) ? root.icon.hoverColor :
                                                                                                                  root.icon.color
    }

    implicitWidth: 44
    implicitHeight: 44
    radius: width / 2;

    color: {
        if (root.enabled)
            return sensor.containsMouse || highlighted ? backgroundSettings.hoverColor
                                                       : backgroundSettings.color;
        return backgroundSettings.disabledColor
    }

    StatusMouseArea {
        id: sensor

        anchors.fill: parent
        cursorShape: loading ? Qt.ArrowCursor
                             : Qt.PointingHandCursor

        hoverEnabled: true
        enabled: !loading && root.enabled

        StatusIcon {
            id: statusIcon
            anchors.centerIn: parent
            visible: !loading

            icon: root.icon.name
            rotation: root.icon.rotation

            width: root.icon.width
            height: root.icon.height

            color: d.iconColor
        } // Icon
        Loader {
            active: loading
            anchors.centerIn: parent
            sourceComponent: StatusLoadingIndicator {
                color: d.iconColor
            } // Indicator
        } // Loader

        onClicked: mouse => root.clicked(mouse)
        onPressed: mouse => root.pressed(mouse)
        onReleased: mouse => root.released(mouse)
        onPressAndHold: mouse => root.pressAndHold(mouse)
    } // Sensor
} // Rectangle
