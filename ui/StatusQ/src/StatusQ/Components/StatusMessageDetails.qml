import QtQuick

import StatusQ.Core

QtObject {
    id: msgDetails

    property bool amISender: false
    property StatusMessageSenderDetails sender: StatusMessageSenderDetails { }
    property bool isEdited: false
    property int contentType: 0
    property string messageText: ""
    // Raw message text (with textual "@0x…" mentions) for the client-side markdown renderer.
    property string unparsedText: ""
    // pubKey -> display name, used to resolve mentions in `unparsedText`.
    property var mentionsMap: ({})
    property string messageContent: ""
    property string messageOriginInfo: ""
    property bool messageDeleted: false
    property var album: []
    property int albumCount: 0
}
