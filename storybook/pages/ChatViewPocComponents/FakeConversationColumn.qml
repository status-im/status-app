import QtQuick 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    property alias model: repeater.model

    Repeater {
        id: repeater

        delegate: FakeMessage {
            Layout.fillWidth: true

            model: modelData
        }
    }
}
