pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Core

/*!
   \qmltype StatusPasswordStrengthIndicator
   \inherits StatusProgressBar
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief It allows visualizing the password strength. Inherits from StatusProgressBar.

   The \c StatusPasswordStrengthIndicator changes its text and color depending on the selected StatusPasswordStrengthIndicator::strength.

   Since it inherits from \c StatusProgressBar, `value` property will change the length of the bar accordingly.

   When `value` property is 0, StatusPasswordStrengthIndicator::strength is automatically set to StatusPasswordStrengthIndicator.Strength.None and no text is displayed.

   Example of how the control looks like:
   \image status_password_strength_indicator.png

   Example of how to use it:

   \qml
        StatusPasswordStrengthIndicator {
            id: weakPw
            strength: StatusPasswordStrengthIndicator.Strength.Weak
            value: 0.5
        }

        StatusPasswordStrengthIndicator {
            id: sosoPw
            strength: StatusPasswordStrengthIndicator.Strength.SoSo
            value: 0.25
        }
   \endqml

   For a list of components available see StatusQ.
*/
StatusProgressBar {
    id: control

    /*!
       \qmlproperty int StatusPasswordStrengthIndicator::strength
       This property holds the password strength value. Possible values are:
       \list
       \li StatusPasswordStrengthIndicator.Strength.None
       \li StatusPasswordStrengthIndicator.Strength.VeryWeak
       \li StatusPasswordStrengthIndicator.Strength.Weak
       \li StatusPasswordStrengthIndicator.Strength.SoSo
       \li StatusPasswordStrengthIndicator.Strength.Good
       \li StatusPasswordStrengthIndicator.Strength.Great
       \endlist
    */
    required property int strength
    /*!
       \qmlproperty string StatusPasswordStrengthIndicator::labelVeryWeak
       This property holds the text shown when the strength is StatusPasswordStrengthIndicator.Strength.VeryWeak.
    */
    property string labelVeryWeak: qsTr("Very weak")
    /*!
       \qmlproperty string StatusPasswordStrengthIndicator::labelWeak
       This property holds the text shown when the strength is StatusPasswordStrengthIndicator.Strength.Weak.
    */
    property string labelWeak: qsTr("Weak")
    /*!
       \qmlproperty string StatusPasswordStrengthIndicator::labelSoso
       This property holds the text shown when the strength is StatusPasswordStrengthIndicator.Strength.SoSo.
    */
    property string labelSoso: qsTr("Okay")
    /*!
       \qmlproperty string StatusPasswordStrengthIndicator::labelGood
       This property holds the text shown when the strength is StatusPasswordStrengthIndicator.Strength.Good.
    */
    property string labelGood: qsTr("Good")
    /*!
       \qmlproperty string StatusPasswordStrengthIndicator::labelGreat
       This property holds the text shown when the strength is StatusPasswordStrengthIndicator.Strength.Great.
    */
    property string labelGreat: qsTr("Very strong")

    enum Strength {
        None, // 0
        VeryWeak, // 1
        Weak, // 2
        SoSo, // 3
        Good, // 4
        Great // 5
    }

    // Behavior:
    states: [
        // Strength states definition:
        State {
            when: control.strength === StatusPasswordStrengthIndicator.Strength.None
            PropertyChanges { target: control; text: "" }
        },
        State {
            when: control.strength === StatusPasswordStrengthIndicator.Strength.VeryWeak
            PropertyChanges { target: control; fillColor: Theme.palette.dangerColor1; text: labelVeryWeak }
        },
        State {
            when: control.strength === StatusPasswordStrengthIndicator.Strength.Weak
            PropertyChanges { target: control; fillColor: Theme.palette.pinColor1; text: labelWeak }
        },
        State {
            when: control.strength === StatusPasswordStrengthIndicator.Strength.SoSo
            PropertyChanges { target: control; fillColor: Theme.palette.miscColor7; text: labelSoso }
        },
        State {
            when: control.strength === StatusPasswordStrengthIndicator.Strength.Good
            PropertyChanges { target: control; fillColor: Theme.palette.miscColor12; text: labelGood }
        },
        State {
            when: control.strength === StatusPasswordStrengthIndicator.Strength.Great
            PropertyChanges { target: control; fillColor: Theme.palette.successColor1; text: labelGreat}
        }
    ]
}
