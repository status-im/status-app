import QtQml

QtObject {
    property int value
    property int openCount

    signal closed

    function open() {
        openCount++
    }

    function close() {
        closed()
    }
}
