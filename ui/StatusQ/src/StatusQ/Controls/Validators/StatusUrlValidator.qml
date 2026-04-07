pragma ComponentBehavior: Bound

import StatusQ.Core.Utils
import StatusQ.Controls

StatusValidator {
    name: "url"

    errorMessage: qsTr("Please enter a valid URL")

    validate: function (value: string): var {
        return Utils.isURL(value);
    }
}
