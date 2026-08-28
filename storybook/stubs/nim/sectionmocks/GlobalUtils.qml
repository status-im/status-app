import QtQuick

QtObject {
    readonly property string contextPropertyName: "globalUtils"

    function isCompressedPubKey(value) {
        return false
    }

    function isAlias(name) {
        return false
    }

    function getColorId(publicKey) {
        return 0
    }

    function getCompressedPk(publicKey) {
        return publicKey
    }

    function getStatusSupportBotChatKey() {
        return "0xdeadb07"
    }
}
