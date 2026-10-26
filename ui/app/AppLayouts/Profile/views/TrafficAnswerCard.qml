import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

//! "Where does the traffic go?" with its one-sentence answer, striped in the
//! colour of the way most bytes go.
Rectangle {
    id: root

    //! Styled text.
    property string text
    property color accent
    property string textObjectName

    implicitHeight: answerColumn.implicitHeight + 16
    radius: Theme.radius
    color: Theme.palette.baseColor2

    Rectangle {
        width: 3
        height: parent.height
        color: root.accent
    }

    ColumnLayout {
        id: answerColumn
        anchors.fill: parent
        anchors.margins: 8
        anchors.leftMargin: 12
        spacing: 2

        TrafficCaption {
            text: qsTr("Where does the traffic go?")
        }
        StatusBaseText {
            objectName: root.textObjectName
            Layout.fillWidth: true
            text: root.text
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
        }
    }
}
