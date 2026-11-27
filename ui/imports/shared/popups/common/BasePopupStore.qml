import QtQml

QtObject {
    id: root

    // store properties
    required property bool isAddAccountPopup
    property bool enteredPrivateKeyIsValid: false
    property bool enteredPrivateKeyMatchTheKeypair: true
    property bool enteredSeedPhraseIsValid: false
    // The profile has no password yet: its addresses are shown elided and copied through the gate
    property bool addressRevealNeedsPassword: false

    // backend properties
    required property var privateKeyAccAddress

    // functions
    property var changePrivateKeyPostponed: function(){}
    property var cleanPrivateKey: function(){}
    property var submitPopup: function(){}
    property var changeSeedPhrase: function(){}
    property var validSeedPhrase: function(){}
}
