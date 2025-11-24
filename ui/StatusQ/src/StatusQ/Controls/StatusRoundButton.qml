import QtQuick
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme
import StatusQ.Components


Rectangle {
    id: statusRoundButton

    Accessible.role: Accessible.Button
    Accessible.name: Utils.formatAccessibleName("", objectName)

    property StatusAssetSettings icon: StatusAssetSettings {
        id: icon
        width: 23
        height: 23
        rotation: 0

        hoverColor: {
            switch(statusRoundButton.type) {
            case StatusRoundButton.Type.Primary:
                return Theme.palette.primaryColor1;
            case StatusRoundButton.Type.Secondary:
                return Theme.palette.indirectColor1;
            case StatusRoundButton.Type.Tertiary:
                return Theme.palette.primaryColor1;
            case StatusRoundButton.Type.Quaternary:
                return Theme.palette.dangerColor1;
            case StatusRoundButton.Type.Quinary:
                return Theme.palette.directColor1;
            }
        }

        color: {
            switch(statusRoundButton.type) {
            case StatusRoundButton.Type.Primary:
                return Theme.palette.primaryColor1;
            case StatusRoundButton.Type.Secondary:
                return Theme.palette.indirectColor1;
            case StatusRoundButton.Type.Tertiary:
                return Theme.palette.baseColor1;
            case StatusRoundButton.Type.Quaternary:
                return Theme.palette.dangerColor1;
            case StatusRoundButton.Type.Quinary:
                return Theme.palette.directColor1;
            }
        }

        disabledColor: {
            switch(statusRoundButton.type) {
            case StatusRoundButton.Type.Primary:
                return Theme.palette.baseColor1;
            case StatusRoundButton.Type.Secondary:
                return Theme.palette.indirectColor1;
            case StatusRoundButton.Type.Tertiary:
                return Theme.palette.baseColor1;
            case StatusRoundButton.Type.Quaternary:
                return Theme.palette.baseColor1;
            case StatusRoundButton.Type.Quinary:
                return Theme.palette.baseColor1;
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
            switch(statusRoundButton.type) {
            case StatusRoundButton.Type.Primary:
                return Theme.palette.primaryColor3;
            case StatusRoundButton.Type.Secondary:
                return Theme.palette.primaryColor1;
            case StatusRoundButton.Type.Tertiary:
                return "transparent";
            case StatusRoundButton.Type.Quaternary:
                return Theme.palette.dangerColor3;
            case StatusRoundButton.Type.Quinary:
                return "transparent";
            }
        }

        property color hoverColor: {
            switch(statusRoundButton.type) {
            case StatusRoundButton.Type.Primary:
                return Theme.palette.primaryColor2;
            case StatusRoundButton.Type.Secondary:
                return Theme.palette.miscColor1;
            case StatusRoundButton.Type.Tertiary:
                return Theme.palette.primaryColor3;
            case StatusRoundButton.Type.Quaternary:
                return Theme.palette.dangerColor2;
            case StatusRoundButton.Type.Quinary:
                return Theme.palette.primaryColor3;
            }
        }

        property color disabledColor: {
            switch(statusRoundButton.type) {
            case StatusRoundButton.Type.Primary:
                return Theme.palette.baseColor2;
            case StatusRoundButton.Type.Secondary:
                return Theme.palette.baseColor1;
            case StatusRoundButton.Type.Tertiary:
                return "transparent";
            case StatusRoundButton.Type.Quaternary:
                return Theme.palette.baseColor2;
            case StatusRoundButton.Type.Quinary:
                return "transparent";
            }
        }
    }

    QtObject {
        id: d
        readonly property color iconColor: !statusRoundButton.enabled ? statusRoundButton.icon.disabledColor :
                                                                        (statusRoundButton.enabled && (statusRoundButton.hovered || statusRoundButton.highlighted)) ? statusRoundButton.icon.hoverColor :
                                                                                                                                   statusRoundButton.icon.color
    }

    implicitWidth: 44
    implicitHeight: 44
    radius: width / 2;

    color: {
        if (statusRoundButton.enabled)
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
        enabled: !loading && statusRoundButton.enabled

        StatusIcon {
            id: statusIcon
            anchors.centerIn: parent
            visible: !loading

            icon: statusRoundButton.icon.name
            rotation: statusRoundButton.icon.rotation

            width: statusRoundButton.icon.width
            height: statusRoundButton.icon.height

            color: d.iconColor
        } // Icon
        Loader {
            active: loading
            anchors.centerIn: parent
            sourceComponent: StatusLoadingIndicator {
                color: d.iconColor
            } // Indicator
        } // Loader

        onClicked: mouse => statusRoundButton.clicked(mouse)
        onPressed: mouse => statusRoundButton.pressed(mouse)
        onReleased: mouse => statusRoundButton.released(mouse)
        onPressAndHold: mouse => statusRoundButton.pressAndHold(mouse)
    } // Sensor
} // Rectangle
