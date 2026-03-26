import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    property string text
    property string informativeText
    property string detailedText

    enum StandardIcon {
        NoIcon,
        Question,
        Information,
        Warning,
        Critical
    }

    property int icon: StatusMessageDialog.StandardIcon.NoIcon

    readonly property string defaultTitle: {
        switch (root.icon) {
        case StatusMessageDialog.StandardIcon.Question:
            return qsTr("Question")
        case StatusMessageDialog.StandardIcon.Information:
            return qsTr("Information")
        case StatusMessageDialog.StandardIcon.Warning:
            return qsTr("Warning")
        case StatusMessageDialog.StandardIcon.Critical:
            return qsTr("Error")
        case StatusMessageDialog.StandardIcon.NoIcon:
        default:
            return ""
        }
    }

    standardButtons: Dialog.Ok

    header: StatusDialogHeader {
        visible: headline.title || root.subtitle
        headline.title: root.title || root.defaultTitle
        headline.subtitle: root.subtitle
        leftComponent: root.icon !== StatusMessageDialog.StandardIcon.NoIcon ? iconComponent : null
        actions.closeButton.onClicked: root.closeHandler()
    }

    footer: DialogButtonBox {
        spacing: Theme.halfPadding
        padding: Theme.padding

        standardButtons: root.standardButtons
        delegate: StatusButton {
            type: (DialogButtonBox.buttonRole & DialogButtonBox.DestructiveRole) ? StatusButton.Type.Danger
                                                                                 : StatusButton.Type.Normal
        }

        background: Rectangle {
            color: Theme.palette.statusModal.backgroundColor
            radius: Theme.radius

            // cover for the top rounded corners
            Rectangle {
                width: parent.width
                height: parent.radius
                anchors.top: parent.top
                color: parent.color
            }

            StatusDialogDivider {
                anchors.top: parent.top
                width: parent.width
            }
        }
    }

    ColumnLayout {
        width: root.availableWidth

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.text
            font.weight: Font.DemiBold
        }
        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: 4
            wrapMode: Text.Wrap
            text: root.informativeText
            visible: !!text
            font.pixelSize: Theme.secondaryTextFontSize
        }
        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.detailedText
            visible: !!text
            font.pixelSize: Theme.additionalTextSize
        }
    }

    Component {
        id: iconComponent
        StatusIcon {
            icon: {
                switch (root.icon) {
                case StatusMessageDialog.StandardIcon.Question:
                    return "help"
                case StatusMessageDialog.StandardIcon.Information:
                    return "info"
                case StatusMessageDialog.StandardIcon.Warning:
                    return "warning"
                case StatusMessageDialog.StandardIcon.Critical:
                    return "caution"
                case StatusMessageDialog.StandardIcon.NoIcon:
                default:
                    return ""
                }
            }
            color: Theme.palette.directColor1

            Binding on color {
                when: root.icon === StatusMessageDialog.StandardIcon.Warning || root.icon === StatusMessageDialog.StandardIcon.Critical
                value: root.icon === StatusMessageDialog.StandardIcon.Critical ? root.Theme.palette.dangerColor1 : root.Theme.palette.warningColor1
                restoreMode: Binding.RestoreBindingOrValue
            }
        }
    }
}
