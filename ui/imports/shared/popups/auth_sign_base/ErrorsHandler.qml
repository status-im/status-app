import QtQuick

import utils

QtObject {
    id: root

    property string errorText: ""

    readonly property QtObject errKeyword: QtObject {
        readonly property string wrongKeycard: "profile does not match"
        readonly property string wrongPin1: "Wrong PIN"
        readonly property string wrongPin2: "PIN must be 6 digits"
        readonly property string connection1: "Failed to connect to card"
        readonly property string connection2: Constants.keycard.state.connectionError
        readonly property string emptyKeycard: Constants.keycard.state.emptyKeycard
        readonly property string notKeycard: Constants.keycard.state.notKeycard
        readonly property string blockedPin: Constants.keycard.state.blockedPIN
        readonly property string blockedPuk: Constants.keycard.state.blockedPUK
        readonly property string noAvailablePairingSlots: Constants.keycard.state.noAvailablePairingSlots
    }

    readonly property bool wrongKeycardError: root.errorText.toLowerCase().indexOf(errKeyword.wrongKeycard.toLowerCase()) > -1
    readonly property bool wrongPinError1: root.errorText.toLowerCase().indexOf(errKeyword.wrongPin1.toLowerCase()) > -1
    readonly property bool wrongPinError2: root.errorText.toLowerCase().indexOf(errKeyword.wrongPin2.toLowerCase()) > -1
    readonly property bool connectionKeycardError1: root.errorText.toLowerCase().indexOf(errKeyword.connection1.toLowerCase()) > -1
    readonly property bool connectionKeycardError2: root.errorText.toLowerCase().indexOf(errKeyword.connection2.toLowerCase()) > -1
    readonly property bool emptyKeycardError: root.errorText.toLowerCase().indexOf(errKeyword.emptyKeycard.toLowerCase()) > -1
    readonly property bool notKeycardError: root.errorText.toLowerCase().indexOf(errKeyword.notKeycard.toLowerCase()) > -1
    readonly property bool blockedPinError: root.errorText.toLowerCase().indexOf(errKeyword.blockedPin.toLowerCase()) > -1
    readonly property bool blockedPukError: root.errorText.toLowerCase().indexOf(errKeyword.blockedPuk.toLowerCase()) > -1
    readonly property bool noAvailablePairingSlotsError: root.errorText.toLowerCase().indexOf(errKeyword.noAvailablePairingSlots.toLowerCase()) > -1
}
