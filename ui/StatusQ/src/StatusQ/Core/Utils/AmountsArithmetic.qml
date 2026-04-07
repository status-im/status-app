pragma ComponentBehavior: Bound

pragma Singleton

import QtQuick

import "big.min.mjs" as Big

/*!
  \qmltype AmountsArithmetic
  \inherits QtObject
  \inqmlmodule StatusQ.Core.Utils
  \brief A singleton that provides methods to properly handle cryptocurrency amounts.

  A basic set of methods that provide basic operations on cryptocurrency amounts,
  such as multiplication or comparison. Correctness is ensured by using numbers
  of arbitrary accuracy and decimal arithmetic. Whenever ordinary java script
  numbers are used, their textual representation is used to initialize big precision
  number, not the exact binary representation.

  The big.js library is used internally.
 */
QtObject {
    /*!
      \qmlmethod AmountsArithmetic::fromNumber(number, multiplier = 0)
      \brief Construct an amount expressed in basic units for a currency with a specific divisibility.

      The amount is created from a number's `toString` value rather than from
      its underlying binary floating point value. This prevents errors such as
      those shown in this example:

      \qml
        console.log(0.07 * 10**18) // 70000000000000010 - incorrect
        console.log(AmountsArithmetic.fromNumber(0.07, 18)) // 70000000000000000 - correct
      \endqml
     */
    function fromNumber(number: real, multiplier = 0): var {
        console.assert(!isNaN(number) && Number.isInteger(multiplier)
                       && multiplier >= 0)
        return new Big.Big(number).times(fromExponent(multiplier))
    }

    /*!
      \qmlmethod AmountsArithmetic::toNumber(amount, multiplier = 0)
      \brief Converts an amount (in form of amount object or string) to a java script number.

      This operation may result in loss of precision. Because of that it should
      be used only to display a value in the user interface, but requires
      further formatting (localization, decimal places adjustment). Other
      operations like comparisons or multiplication must be performed directly
      on amounts to preserve precision.

      \qml
        console.log(AmountsArithmetic.toNumber(
                        AmountsArithmetic.fromString("123456789123456789123"))) // 123456789123456800000
        console.log(AmountsArithmetic.toNumber("123456789123456789123")) // 123456789123456800000
      \endqml
     */
    function toNumber(amount: var, multiplier = 0): real {
        console.assert(Number.isInteger(multiplier) && multiplier >= 0)

        if (typeof amount === "string")
            amount = fromString(amount)

        console.assert(amount instanceof Big.Big)
        return amount.div(fromExponent(multiplier)).toNumber()
    }

    /*!
      \qmlmethod AmountsArithmetic::fromString(numStr)
      \brief Construct an amount from a textual or numeric representation

      The constructed amount is of arbitrary precision. Using ordinary js
      numbers, precision might not be sufficient:

      \qml
        console.log(1234567891234567891) // 1234567891234568000 - incorrect
        console.log(parseInt("1234567891234567891")) // 1234567891234568000 - incorrect
        console.log(AmountsArithmetic.fromString("1234567891234567891")) // 1234567891234567891 - correct
      \endqml

      The obtained amount can be multiplied or compared.

      Provided number is assumed to be an amount in basic units, e.g. an integer or a float number.

      returns NaN in case the conversion fails.
     */
    function fromString(numStr: var): var {
        console.assert(typeof numStr === "string" || typeof numStr === "number")
        try {
            return new Big.Big(numStr)
        } catch(e) {
            return NaN
        }
    }

    /*!
      \qmlmethod AmountsArithmetic::fromExponent(exponent)
      \brief Construct a number 10^exponent in a safe manner.
     */
    function fromExponent(exponent: int): var {
        console.assert(Number.isInteger(exponent))
        const num = new Big.Big(1)
        num.e += exponent
        return num
    }

    /*!
      \qmlmethod AmountsArithmetic::times(amount, multiplier)
      \brief Returns an amount whose value is the value of num1 times num2.

      \qml
        console.log(0.07 * 10**18 * 1000 === 70 * 10**18) // false
        console.log(AmountsArithmetic.cmp(
                        AmountsArithmetic.fromNumber(0.07, 18).times(1000),
                        AmountsArithmetic.fromNumber(1, 18).times(70)) === 0) // true
      \endqml
     */
    function times(amount: var, multiplier: var): var {
        console.assert(amount instanceof Big.Big)
        console.assert(multiplier instanceof Big.Big || Number.isInteger(multiplier))
        return amount.times(multiplier)
    }

    /*!
      \qmlmethod AmountsArithmetic::div(divident, divisor)
      \brief Returns a Big number whose value is the value of divident divided by divisor.
     */
    function div(divident: var, divisor: var): var {
        console.assert(divident instanceof Big.Big)
        console.assert(divisor instanceof Big.Big)
        return divident.div(divisor)
    }

    /*!
      \qmlmethod AmountsArithmetic::sum(amount1, amount2)
      \brief Returns a Big number whose value is the sum of amount1 and amount2.
     */
    function sum(amount1: var, amount2: var): var {
        console.assert(amount1 instanceof Big.Big)
        console.assert(amount2 instanceof Big.Big)
        return amount1.plus(amount2)
    }

    /*!
      \qmlmethod AmountsArithmetic::sub(amount1, amount2)
      \brief Returns a Big number whose value is the subtraction of amount2 from amount1.
     */
    function sub(amount1: var, amount2: var): var {
        console.assert(amount1 instanceof Big.Big)
        console.assert(amount2 instanceof Big.Big || Number.isInteger(amount2))
        return amount1.minus(amount2)
    }

    /*!
      \qmlmethod AmountsArithmetic::cmp(amount1, amount2)
      \brief Compares two amounts.

      Returns 1 if the value of amount1 is greater than the value of amount2.
      Returns -1 if the value of amount1 is less than the value of amount2.
      Returns 0 if both amounts have the same value.
     */
    function cmp(amount1: var, amount2: var): int {
        console.assert(amount1 instanceof Big.Big)
        console.assert(amount2 instanceof Big.Big)
        return amount1.cmp(amount2)
    }

    /*!
      \qmlmethod AmountsArithmetic::round(amount, decimalPlaces = 0)
      \brief Returns a Big number rounded to the specified decimal places.

      If decimalPlaces is not specified, rounds to 0 decimal places (integer).
     */
    function round(amount: var, decimalPlaces = 0): var {
        console.assert(amount instanceof Big.Big)
        console.assert(Number.isInteger(decimalPlaces))
        return amount.round(decimalPlaces)
    }
}
