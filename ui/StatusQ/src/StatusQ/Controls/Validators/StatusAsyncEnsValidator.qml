pragma ComponentBehavior: Bound

import StatusQ.Controls
import StatusQ.Core.Utils

StatusAsyncValidator {
    readonly property string uuid: Utils.uuid()

    name: "asyncEns"

    errorMessage: qsTr("ENS name could not be resolved in to an address")

    validate: function (asyncResult: string): var {
        return Utils.isValidAddress(asyncResult)
    }
}

