import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme

// Footer action surface for StatusAdaptiveDialog.
//
// Renders two ObjectModel slots in a horizontal row: leftButtons on the left
// (navigation controls, contextual info) and rightButtons on the right (primary
// and secondary actions). Visibility is automatic — the component hides itself
// when both slots are empty.
//
// The parent dialog owns external margins, dividers, safe-area spacing and
// section visibility. This component owns only the painted surface and the
// button row inside it.
Control {
    id: root

    objectName: "statusAdaptiveDialogFooter"

    // Typically navigation controls (e.g. StatusBackButton in multi-step flows) or
    // informational content (e.g. estimated time, fees).
    property ObjectModel leftButtons
    // Typically the primary and secondary actions (e.g. Cancel + Confirm).
    property ObjectModel rightButtons

    property color color: Theme.palette.statusModal.backgroundColor
    property int radius: Theme.radius

    visible: !!leftButtons || !!rightButtons
    padding: 0

    background: StatusDialogBackground {
        color: root.color
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius
        topLeftRadius: 0
        topRightRadius: 0
    }

    contentItem: RowLayout {
        spacing: Theme.defaultHalfPadding

        Repeater {
            model: root.leftButtons
        }

        Item {
            Layout.fillWidth: true
        }

        Repeater {
            model: root.rightButtons
        }
    }
}
