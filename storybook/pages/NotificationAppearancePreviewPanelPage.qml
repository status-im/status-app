import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.Profile.panels

Item {
    id: root

    Rectangle {
        color: Theme.palette.background
        anchors.fill: parent

        NotificationAppearancePreviewPanel {
            id: notifNameAndMsg
            anchors.centerIn: parent

            width: explicitWidthCheckBox.checked ? widthSlider.value : undefined

            name: qsTr("Show Name and Message")
            notificationTitle: "Vitalik Buterin"
            notificationMessage: qsTr("Hi there! So EIP-1559 will defini...")
        }
    }

    RowLayout {
        anchors.bottom: parent.bottom

        CheckBox {
            id: explicitWidthCheckBox

            text: "explicit width"
        }

        Slider {
            id: widthSlider

            from: 10
            to: 300

            visible: explicitWidthCheckBox.checked
        }
    }
}

// category: Panels
// status: good
