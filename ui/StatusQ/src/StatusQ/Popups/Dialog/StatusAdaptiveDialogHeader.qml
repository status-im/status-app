import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

// Header surface for StatusAdaptiveDialog.
//
// Renders a title/subtitle row with an optional left component (e.g. a back
// button) and a right actions area (close button, overflow menu). Visibility
// is automatic — the component hides itself when both title and subtitle are
// empty.
//
// The parent dialog owns external margins, dividers and section visibility.
// This component owns only the painted surface and the internal row layout.
// Consumers configure it through StatusAdaptiveDialog's header aliases rather
// than depending on this component directly.
Control {
    id: root

    objectName: "statusAdaptiveDialogHeader"

    readonly property alias headline: headline
    readonly property alias actions: actions
    property alias title: headline.title
    property alias subtitle: headline.subtitle
    property alias leftComponent: leftComponentLoader.sourceComponent

    property color color: Theme.palette.statusModal.backgroundColor
    property int radius: Theme.radius

    visible: !!headline.title || !!headline.subtitle
    padding: 0

    background: StatusDialogBackground {
        color: root.color
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: 0
        bottomRightRadius: 0
    }

    contentItem: RowLayout {
        id: layout

        spacing: Theme.halfPadding

        Item {
            id: leftComponentHost

            Layout.fillHeight: true
            Layout.preferredWidth: visible ? leftComponentLoader.implicitWidth : 0
            Layout.rightMargin: visible ? Math.max(Theme.padding, 8) - layout.spacing : 0
            visible: leftComponentLoader.sourceComponent

            Loader {
                id: leftComponentLoader

                anchors.centerIn: parent
            }
        }

        StatusTitleSubtitle {
            id: headline

            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        StatusHeaderActions {
            id: actions

            Layout.alignment: Qt.AlignTop
        }
    }
}
