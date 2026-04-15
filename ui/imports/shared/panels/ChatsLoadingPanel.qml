import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core

import shared

Control {
    contentItem: RowLayout {
        spacing: 6
        StatusBaseText {
            text: qsTr("Loading chats...")
        }
        LoadingAnimation {}
    }
}
