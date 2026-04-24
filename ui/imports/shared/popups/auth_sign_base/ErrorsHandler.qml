import QtQuick

import utils

QtObject {
    id: root

    property string errorText: ""

    readonly property QtObject errKeyword: QtObject {
        readonly property string internalError: "Keycard info not found"
        readonly property string wrongKeycardProfile: "profile does not match"
        readonly property string wrongKeycard: "Keycard instance UID does not match"
        readonly property string wrongPin1: "Wrong PIN"
        readonly property string wrongPin2: "PIN must be 6 digits"
        readonly property string wrongPuk1: "Wrong PUK"
        readonly property string wrongPuk2: "PUK must be 12 digits"
        readonly property string connection1: "Failed to connect to card"
        readonly property string connection2: Constants.keycard.state.connectionError
        readonly property string emptyKeycard: Constants.keycard.state.emptyKeycard
        readonly property string notKeycard: Constants.keycard.state.notKeycard
        readonly property string blockedPin: Constants.keycard.state.blockedPIN
        readonly property string blockedPuk: Constants.keycard.state.blockedPUK
        readonly property string noAvailablePairingSlots: Constants.keycard.state.noAvailablePairingSlots
    }

    readonly property bool internalError: root.errorText.toLowerCase().indexOf(errKeyword.internalError.toLowerCase()) > -1
    readonly property bool wrongKeycardProfileError: root.errorText.toLowerCase().indexOf(errKeyword.wrongKeycardProfile.toLowerCase()) > -1
    readonly property bool wrongKeycardError: root.errorText.toLowerCase().indexOf(errKeyword.wrongKeycard.toLowerCase()) > -1
    readonly property bool wrongPinError1: root.errorText.toLowerCase().indexOf(errKeyword.wrongPin1.toLowerCase()) > -1
    readonly property bool wrongPinError2: root.errorText.toLowerCase().indexOf(errKeyword.wrongPin2.toLowerCase()) > -1
    readonly property bool wrongPukError1: root.errorText.toLowerCase().indexOf(errKeyword.wrongPuk1.toLowerCase()) > -1
    readonly property bool wrongPukError2: root.errorText.toLowerCase().indexOf(errKeyword.wrongPuk2.toLowerCase()) > -1
    readonly property bool connectionKeycardError1: root.errorText.toLowerCase().indexOf(errKeyword.connection1.toLowerCase()) > -1
    readonly property bool connectionKeycardError2: root.errorText.toLowerCase().indexOf(errKeyword.connection2.toLowerCase()) > -1
    readonly property bool emptyKeycardError: root.errorText.toLowerCase().indexOf(errKeyword.emptyKeycard.toLowerCase()) > -1
    readonly property bool notKeycardError: root.errorText.toLowerCase().indexOf(errKeyword.notKeycard.toLowerCase()) > -1
    readonly property bool blockedPinError: root.errorText.toLowerCase().indexOf(errKeyword.blockedPin.toLowerCase()) > -1
    readonly property bool blockedPukError: root.errorText.toLowerCase().indexOf(errKeyword.blockedPuk.toLowerCase()) > -1
    readonly property bool noAvailablePairingSlotsError: root.errorText.toLowerCase().indexOf(errKeyword.noAvailablePairingSlots.toLowerCase()) > -1
}
