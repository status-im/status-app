import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.ActivityCenter.controls
import Models
import Storybook

import StatusQ.Core.Theme
import StatusQ.Components

import utils

SplitView {
    id: root

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            NotificationContextRow {
                anchors.centerIn: parent
                Tracer {
                    visible: baseEditor.showTracer
                }
                width: baseEditor.cardWidth
                primaryText: editor.primartyText
                contextAvatar: editor.isContextAvatar ? "https://picsum.photos/320/240?10" : ""
                iconName: editor.iconType
                secondaryText: editor.secondaryText
                separatorIconName: editor.separatorType

                // Colors setup:
                iconColor: editor.changeIconColor ? "pink" : Theme.palette.directColor1
                primaryColor: editor.changePrimaryTextColor ? "red" : Theme.palette.directColor1
                secondaryColor: editor.changeSecondaryTextColor ? "green" : Theme.palette.directColor1
                separatorColor: editor.changeSeparatorColor ? "orange" : Theme.palette.directColor5
            }
        }
    }

    ScrollView {
        id: scroll
        SplitView.minimumWidth: 350
        SplitView.preferredWidth: 350
        clip: true

        Pane {
            ColumnLayout {
                width: scroll.width

                NotificationCardBaseEditor {
                    id: baseEditor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true
                }

                NotificationContextRowEditor {
                    id: editor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true
                }
            }
        }
    }
}
// category: Activity Center
// status: good
// https://www.figma.com/design/SGyfSjxs5EbzimHDXTlj8B/Qt-Responsive---v?node-id=1786-63536&m=dev
