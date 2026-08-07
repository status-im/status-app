import QtQuick

QtObject {
    property bool gifUnfurlingEnabled: false
    property bool neverAskAboutUnfurlingAgain: false

    function setNeverAskAboutUnfurlingAgain(neverAskAgain) {
        neverAskAboutUnfurlingAgain = neverAskAgain
    }
}
