import QtQuick

Item {
    required property int value
    property QtObject counter

    Component.onCompleted: counter.count++
}
