pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core

QtObject {
    id: msgDetails

    property bool amISender: false
    property StatusMessageSenderDetails sender: StatusMessageSenderDetails { }
    property bool isEdited: false
    property int contentType: 0
    property string messageText: ""
    property string messageContent: ""
    property string messageOriginInfo: ""
    property bool messageDeleted: false
    property var album: []
    property int albumCount: 0
}
