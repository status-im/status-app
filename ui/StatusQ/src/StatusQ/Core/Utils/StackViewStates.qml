pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

QtObject {
    id: root

    required property StackView stackView

    readonly property StatesStack _statesStack: StatesStack { id: statesStack }

    property alias currentState: statesStack.currentState
    property alias size: statesStack.size
    readonly property alias states: statesStack.states

    function pushInitialState(state: string): void {
        if(size > 0)
            console.warn("Pushing initial state but the stack already contains elements:  " + size)
        statesStack.push(state)
    }

    function push(state: string, item: var, properties: var, operation: var): var {
        // States related operations:
        statesStack.push(state)

        // Stack view related operations:
        return stackView.push(item, properties, operation)
    }

    function pop(operation: var): var {
        // States related operations:
        statesStack.pop()

        // Stack view related operations:
        return stackView.pop(operation)
    }

    function clear(initialState: string, operation: var): var {
        // States related operations:
        statesStack.clear()
        statesStack.push(initialState)

        // Stack view related operations:
        return stackView.pop(null, operation) // Resetting to the initial stack state
    }
}
