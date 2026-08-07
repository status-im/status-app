import QtQuick

QtObject {
    property string myPublicKey: "0xdeadbeef"

    function getContactPublicKeyByAddress(address) {
        return ""
    }

    function changeContactNickname(pubKey, nickname, displayName, isEdit) {}
    function removeTrustStatus(pubKey) {}
    function dismissContactRequest(chatId, contactRequestId) {}
    function acceptContactRequest(chatId, contactRequestId) {}
}
