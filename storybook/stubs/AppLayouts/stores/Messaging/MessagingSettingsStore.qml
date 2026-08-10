import QtQuick

QtObject {
    property var mailservers: null
    property bool useMailservers: false
    property bool messagesFromContactsOnly: false
    property bool syncingOnMobileNetwork: false
    property int urlUnfurlingMode: 0

    function toggleUseMailservers(value) {}
    function setMessagesFromContactsOnly(value) {}
    function setSyncingOnMobileNetwork(value) {}
    function setUrlUnfurlingMode(value) {}
}
