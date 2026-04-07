pragma ComponentBehavior: Bound

import StatusQ.Controls

StatusValidator {

    property int minLength: 0

    name: "minLength"

    errorMessage: {
        minLength === 1 ?
            qsTr("Please enter a value") :
            qsTr("The value must be at least %n character(s).", "", minLength)
    }

    validate: function (value: string): var {
        return value.length >= minLength && value.trim().length > 0 ? true : {
            min: minLength,
            actual: value.length
        }
    }
}
