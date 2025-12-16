import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import QtQuick.Window


Control {
    id: root

    property alias showTracer: showTracer.checked
    property alias cardWidth: cardWidth.value

    property int minCardWidth: 256
    property int maxCardWidth: 400

    background: Rectangle {
        color: "lightgray"
        opacity: 0.2
        radius: 8
    }

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding


        Label {
            Layout.topMargin: Theme.padding
            Layout.leftMargin: Theme.padding
            Layout.bottomMargin: Theme.padding
            text: "LAYOUT"
            font.weight: Font.Bold
        }

        CheckBox {
            id: showTracer
            Layout.leftMargin: Theme.padding
            text: "Show Tracer?"
            checked: true
        }

        Label {
            text: "Card width"
            Layout.leftMargin: Theme.padding
            font.weight: Font.Bold
        }

        Slider {
            id: cardWidth
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.fillWidth: true
            value: from
            from: root.minCardWidth
            to: root.maxCardWidth
        }
    }
}

