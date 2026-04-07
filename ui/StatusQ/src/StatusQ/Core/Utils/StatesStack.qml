pragma ComponentBehavior: Bound

import QtQml

QtObject {
    id: root

    property string currentState
    property int size: 0
    property var states: []

    function push(state: string): void {
        states.push(state)
        currentState = state
        size++
    }

    function pop(operation: var): void {
        states.pop()
        currentState = states.length ? states[states.length - 1] : ""
        size = states.length
    }

    function clear() {
        currentState = ""
        size = 0
        states = []
    }
}
