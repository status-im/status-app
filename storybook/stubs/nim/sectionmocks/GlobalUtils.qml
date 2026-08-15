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

    function qrCode(address) {
        return ""
    }

    function wei2Eth(wei, decimals) {
        return wei / Math.pow(10, decimals)
    }

    function eth2Wei(eth, decimals) {
        return eth * Math.pow(10, decimals)
    }
}
