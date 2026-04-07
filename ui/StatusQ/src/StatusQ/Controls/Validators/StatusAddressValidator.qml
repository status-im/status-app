pragma ComponentBehavior: Bound

import StatusQ.Controls
import StatusQ.Core.Utils

StatusValidator {
    name: "address"

    errorMessage: qsTr("Please enter a valid address.")

    validate: function (t: string): var {
        return Utils.isValidAddress(t) ? true : { actual: t }
    }
}

