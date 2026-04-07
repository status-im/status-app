pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Controls

/*!
   \qmltype StatusRegularExpressionValidator
   \inherits StatusValidator
   \inqmlmodule StatusQ.Controls.Validators
   \since StatusQ.Controls.Validators 0.1
   \brief The StatusRegularExpressionValidator type provides a validator for regular expressions.

   The \c StatusRegularExpressionValidator type provides a validator, that counts as valid any string which matches a specified regular expression.

   It is a wrapper of QML type \l{https://doc.qt.io/qt-5/qml-qtquick-regularexpressionvalidator.html}{RegularExpressionValidator}.

   Example of how to use it:

   \qml
        StatusRegularExpressionValidator {
            regularExpression: /[0-9A-Za-z@]+/
            errorMessage: qsTr("Please enter a valid regular expression.")
        }
   \endqml

   For a list of components available see StatusQ.
*/
StatusValidator {
    id: root

    /*!
       \qmlproperty var StatusRegularExpressionValidator::regularExpression
        This property holds the regular expression used for validation.

        Note that this property should be a regular expression in JS syntax, e.g /a/ for the regular expression matching "a".

        By default, this property contains a regular expression with the pattern .* that matches any string.

        Some more examples of regular expressions:

        > A list of numbers with one to three positions separated by a comma:
        \qml
        /\d{1,3}(?:,\d{1,3})+$/
        \endqml

        > An amount consisting of up to 3 numbers before the decimal point, and 1 to 2 after the decimal point:
        \qml
        /(\d{1,3})([.,]\d{1,2})?$/
       \endqml
    */
    property var regularExpression

    name: "regex"
    errorMessage: `Must match regex(${regularExpression.toString()})`
    validatorObj: RegularExpressionValidator { regularExpression: root.regularExpression }

    validate: function (value: string): var {
        // Basic validation management
        return root.regularExpression.test(value)
    }
}
