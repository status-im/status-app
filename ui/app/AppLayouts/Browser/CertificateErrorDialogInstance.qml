import QtQuick.Controls

import StatusQ.Popups.Dialog

StatusMessageDialog {
    id: sslDialog

    property var certErrors: []

    icon: StatusMessageDialog.StandardIcon.Warning
    standardButtons: Dialog.No | Dialog.Yes
    title: qsTranslate("BrowserLayout", "Server's certificate not trusted")
    text: qsTranslate("BrowserLayout", "Do you wish to continue?")
    detailedText: qsTranslate("BrowserLayout", "If you wish so, you may continue with an unverified certificate. Accepting an unverified certificate means you may not be connected with the host you tried to connect to.\nDo you wish to override the security check and continue?")
    onAccepted: {
        certErrors.shift().acceptCertificate();
        presentError();
    }
    onRejected: {
        certErrors.shift().rejectCertificate();
        presentError();
    }
    function enqueue(error){
        certErrors.push(error);
        presentError();
    }
    function presentError(){
        visible = certErrors.length > 0
    }
}
