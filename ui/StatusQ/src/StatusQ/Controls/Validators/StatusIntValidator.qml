pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Controls

/*!
   \qmltype StatusIntValidator
   \inherits StatusValidator
   \inqmlmodule StatusQ.Controls.Validators
   \since StatusQ.Controls.Validators 0.1
   \brief The StatusIntValidator type provides a validator for integer values.

   The \c StatusIntValidator type provides a validator for integer values.

   It is a wrapper of QML type \l{https://doc.qt.io/qt-5/qml-qtquick-intvalidator.html}{IntValidator}.

   Example of how to use it:

   \qml
        StatusIntValidator {
            bottom: 0
            top: 125
            errorMessage: qsTr("This is an invalid numeric value")
        }
   \endqml

   For a list of components available see StatusQ.
*/
StatusValidator {
    id: root

    /*!
       \qmlproperty string StatusIntValidator::bottom
       This property holds the validator's lowest acceptable value. By default, this property's value is derived from the lowest signed integer available (typically -2147483647).
    */
    property int bottom

    /*!
       \qmlproperty var StatusIntValidator::locale
       This property holds the locale used to interpret the number.
    */
    property var locale: Qt.locale()

    /*!
       \qmlproperty string StatusIntValidator::top
       This property holds the validator's highest acceptable value. By default, this property's value is derived from the highest signed integer available (typically 2147483647).
    */
    property int top

    name: "intValidator"
    errorMessage: qsTr("Please enter a valid numeric value.")
    validatorObj: IntValidator { bottom: root.bottom; locale: root.locale.name; top: root.top }

    validate: function (t: string): var {
        let value = parseInt(t)
        let floatValue = parseFloat(t)
        let nan = isNaN(t)

        if(nan || value !== floatValue )
           return false

        if(value <= root.top && value >= root.bottom)
            return true
        return false
    }
}
