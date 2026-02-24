import StatusQ

/*!
  \qmltype AmountValidator
  \inherits GenericValidator
  \inqmlmodule StatusQ.Validators
  \brief Validator validating amounts provided by the user.

  The validator do following checks:

  - marks empty input and consisting only of decimal point as Intermediate
  - limits allowed char set - digits and (only when maxDecimalDigits is not 0)
    two decimal point characters are available (".", ",")
  - replaces entered decimal point to the one provided via decimalPoint property
  - blocks attemps of entering more then one decimal point char
  - limits number of integral part specified by maxIntegralDigits
  - trims number of decimal part specified by maxDecimalDigits
  - numbers starting or ending with decimal point like .1 or 1. are considered
    as valid input
 */
GenericValidator {
    id: root

    property string decimalPoint: Qt.locale(locale).decimalPoint
    property int maxIntegralDigits: 10
    property int maxDecimalDigits: 10
    property int maxDigits: maxIntegralDigits + maxDecimalDigits

    validate: {
        if (input.length === 0)
            return GenericValidator.Intermediate

        const charSetRegex = root.maxDecimalDigits > 0 ? /^[0-9\.\,]*$/
                                                       : /^[0-9]*$/
        const validCharSet = charSetRegex.test(input)

        if (!validCharSet)
            return GenericValidator.Invalid

        const delocalized = input.replace(/,/g, ".")

        if (delocalized === ".")
            return {
                state: GenericValidator.Intermediate,
                output: root.decimalPoint
            }

        const pointsCount = (delocalized.match(/\./g) || []).length

        if (pointsCount > 1)
            return GenericValidator.Invalid

        const [integral, decimal] = pointsCount ? delocalized.split(".")
                                                : [delocalized, ""]

        if ((integral.length + decimal.length) > root.maxDigits)
            return GenericValidator.Invalid

        if (integral.length > root.maxIntegralDigits)
            return GenericValidator.Invalid

        if (pointsCount === 0)
            return GenericValidator.Acceptable

        const decimalTrimmed = decimal.slice(0, root.maxDecimalDigits)
        const localized = [integral, decimalTrimmed].join(root.decimalPoint)

        return {
            state: GenericValidator.Acceptable,
            output: localized
        }
    }
}
