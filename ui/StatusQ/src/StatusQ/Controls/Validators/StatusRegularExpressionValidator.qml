import QtQuick

import StatusQ
import StatusQ.Controls

/*!
   \qmltype StatusRegularExpressionValidator
   \inherits StatusValidator
   \inqmlmodule StatusQ.Controls.Validators
   \since StatusQ.Controls.Validators 0.1
   \brief The StatusRegularExpressionValidator type provides a validator for regular expressions.

   The \c StatusRegularExpressionValidator type provides a validator, that counts as valid any string which matches a specified regular expression.

   It is a wrapper of \l RXValidator, a \c QValidator built on \c QRegularExpression (PCRE2) with Unicode
   support enabled. Validation is NOT performed by the JS regex engine: QML's JS engine has no support
   for Unicode property escapes (\c {\p{L}}) and its \c {\w} / \c {\d} classes are ASCII-only, which makes it
   unsuitable for validating user input in non-Latin scripts.

   Example of how to use it:

   \qml
        StatusRegularExpressionValidator {
            regularExpression: /^[\p{L}\p{M}\p{N} ]+$/
            errorMessage: qsTr("Only letters, numbers and spaces allowed")
        }
   \endqml

   For a list of components available see StatusQ.
*/
StatusValidator {
    id: root

    /*!
       \qmlproperty var StatusRegularExpressionValidator::regularExpression
        This property holds the regular expression used for validation.

        The value is written as a JS regular expression literal (e.g. \c {/^[0-9]+$/}), but the pattern text is
        handed over verbatim to \c QRegularExpression and evaluated by PCRE2 with
        \c QRegularExpression::UseUnicodePropertiesOption. Consequently:

        \list
        \li Unicode property classes are available: \c {\p{L}} (letters of any script), \c {\p{M}} (combining
            marks), \c {\p{N}} (digits of any script), \c {\p{P}} (punctuation), \c {\p{S}} (symbols, incl. emoji)...
        \li \c {\w}, \c {\d}, \c {\s} and \c {\b} are Unicode-aware (unlike in JS). Use explicit ranges such as
            \c {[0-9]} or \c {[A-Z]} when ASCII-only semantics are required.
        \li The pattern is anchored: the whole input has to match.
        \li Do not use the JS \c u flag (the JS parser would reject \c {\p{...}}), \c {\uXXXX} escapes or
            surrogate pair escapes (not supported by PCRE2 - use \c {\p{...}} classes instead), nor a class
            range ending with a class escape (e.g. \c {[$-\s]}).
        \endlist

        Only the \c i (case insensitive) and \c m (multiline) JS flags are carried over.

        Some examples of regular expressions:

        > A list of numbers with one to three positions separated by a comma:
        \qml
        /^\d{1,3}(?:,\d{1,3})+$/
        \endqml

        > An amount consisting of up to 3 numbers before the decimal point, and 1 to 2 after the decimal point:
        \qml
        /^(\d{1,3})([.,]\d{1,2})?$/
       \endqml
    */
    property var regularExpression

    name: "regex"
    errorMessage: `Must match regex(${regularExpression.toString()})`
    validatorObj: RXValidator { regularExpression: root.regularExpression }

    validate: function (value) {
        return root.validatorObj.test(value)
    }
}
