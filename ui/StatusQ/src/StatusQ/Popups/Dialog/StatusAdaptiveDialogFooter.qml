import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Controls
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
    // Optional Dialog.standardButtons rendered with the same adaptive footer surface.
    property int standardButtons: Dialog.NoButton

    signal accepted
    signal rejected
    signal applied
    signal reset
    signal helpRequested

    property color color: Theme.palette.statusModal.backgroundColor
    property int radius: Theme.radius

    QtObject {
        id: d

        readonly property bool hasLeftButtons: !!root.leftButtons && root.leftButtons.count > 0
        readonly property bool hasRightButtons: !!root.rightButtons && root.rightButtons.count > 0
        readonly property bool hasStandardButtons: root.standardButtons !== Dialog.NoButton && !hasLeftButtons && !hasRightButtons
    }

    visible: d.hasLeftButtons || d.hasRightButtons || d.hasStandardButtons
    padding: 0
    spacing: Theme.defaultHalfPadding

    background: StatusDialogBackground {
        color: root.color
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius
        topLeftRadius: 0
        topRightRadius: 0
    }

    contentItem: RowLayout {
        spacing: root.spacing

        Repeater {
            model: root.leftButtons
        }

        Item {
            Layout.fillWidth: true
        }

        Repeater {
            model: root.rightButtons
        }

        Loader {
            id: standardButtonBoxLoader

            objectName: "statusAdaptiveDialogStandardButtonBoxLoader"
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            active: d.hasStandardButtons
            visible: active

            sourceComponent: DialogButtonBox {
                objectName: "statusAdaptiveDialogStandardButtonBox"
                spacing: root.spacing
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0
                topInset: 0
                bottomInset: 0
                leftInset: 0
                rightInset: 0
                standardButtons: root.standardButtons
                background: null

                delegate: StatusButton {
                    type: DialogButtonBox.buttonRole === DialogButtonBox.DestructiveRole ? StatusButton.Type.Danger
                                                                                         : StatusButton.Type.Normal
                }

                onAccepted: root.accepted()
                onRejected: root.rejected()
                onApplied: root.applied()
                onReset: root.reset()
                onHelpRequested: root.helpRequested()
            }
        }
    }
}
