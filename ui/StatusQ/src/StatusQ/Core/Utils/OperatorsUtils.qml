pragma ComponentBehavior: Bound

pragma Singleton

import QtQuick

QtObject {
    id: root

    /*!
       \qmlproperty string OperatorsUtils::andOperatorText
       This property holds the string text representation for an `AND` logical operator.
    */
    readonly property string andOperatorText: qsTr("and")
    /*!
       \qmlproperty string OperatorsUtils::orOperatorText
       This property holds the string text representation for an `OR` logical operator.
    */
    readonly property string orOperatorText: qsTr("or")

    // Logical operators
    enum Operators {
        None,
        And,
        Or
    }

    function setOperatorTextFormat(operator: int): string {
        switch(operator) {
            case OperatorsUtils.Operators.And:
                return root.andOperatorText
            case OperatorsUtils.Operators.Or:
                return root.orOperatorText
            case OperatorsUtils.Operators.None:
            default:
                return ""
        }
    }
}
