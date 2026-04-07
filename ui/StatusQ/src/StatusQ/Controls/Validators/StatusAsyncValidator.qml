pragma ComponentBehavior: Bound

import QtQuick
import StatusQ.Core.Backpressure

Item {
    id: statusAsyncValidator

    property string name: ""
    property string errorMessage: qsTr("invalid input")
    signal asyncComplete(var result)
    signal validationComplete(var value, bool valid)

    // Prevents firing async operations before time has elapsed. If multiple
    // calls are attempted, the timer resets each time.
    property int debounceTime: 600

    property var validate: function (value: var): bool {
        return value === "async result"
    }
    property var asyncOperation: function(inputText: string): void {
        // Do something with the input text. Once completed, fire the
        // `asyncComplete` signal
        asyncComplete("async result")
    }

    readonly property var asyncOperationInternal: Backpressure.debounce(statusAsyncValidator, debounceTime, function(inputText) {
        statusAsyncValidator.asyncOperation(inputText)
    })

    onAsyncComplete: function(result) {
        validationComplete(result, validate(result))
    }
}
