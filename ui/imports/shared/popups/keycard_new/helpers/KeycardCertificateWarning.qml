import QtQuick

import StatusQ.Controls
import StatusQ.Core.Theme

/*!
    Non-blocking warning for an applet 4.x Keycard whose certificate no trusted CA signed
    (development or custom-made card). Collapses when \c text is empty.
*/
StatusWarningBox {
    objectName: "keycardDetailsCertificateWarning"

    visible: !!text
    icon: "warning"
    bgColor: Theme.palette.warningColor3
    borderColor: Theme.palette.warningColor2
    textColor: Theme.palette.directColor1
    iconColor: Theme.palette.warningColor1
}
