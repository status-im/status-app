import QtQuick

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

Row {
    id: root

    // Contact Verification States:
    property bool isContact: false
    property int trustIndicator: StatusContactVerificationIcons.TrustedType.None
    property bool isBlocked

    /*!
        Controls the default icon size.

        If true, the icon size is 10.
        If false, the icon size is 16.
    */
    property bool tiny: true

    /*!
        Overrides the default icon size.

        When 0, the component uses the default tiny/normal size.
    */
    property int customIconSize: 0

    QtObject {
        id: d

        readonly property int tinySize: Theme.fontSize(10)      // By design
        readonly property int normalSize: Theme.fontSize(16)    // By design

        readonly property int currentSize: root.customIconSize > 0 ? root.customIconSize :
                                                                     root.tiny ? tinySize : normalSize
    }

    enum TrustedType {
        None, //0
        Verified, //1
        Untrustworthy //2
    }

    spacing: Theme.halfPadding / 2
    visible: root.isContact ||
             root.isBlocked ||
             (root.trustIndicator !== StatusContactVerificationIcons.TrustedType.None)

    HoverHandler {
        id: hoverHandler
    }

    StatusToolTip {
        text: {
            if (root.isBlocked)
                return qsTr("Blocked")
            if (root.isContact) {
                if (root.trustIndicator === StatusContactVerificationIcons.TrustedType.Verified)
                    return qsTr("Trusted contact")
                if (root.trustIndicator === StatusContactVerificationIcons.TrustedType.Untrustworthy)
                    return qsTr("Untrusted contact")
                return qsTr("Contact")
            }
            if (root.trustIndicator === StatusContactVerificationIcons.TrustedType.Untrustworthy)
                return qsTr("Untrusted")
            return ""
        }

        visible: hoverHandler.hovered && text
    }

    // blocked
    StatusIcon {
        visible: root.isBlocked
        icon: root.isBlocked ? "cancel" : ""
        width: d.currentSize
        height: width
        color: Theme.palette.directColor1
    }

    // (un)trusted
    StatusIcon {
        visible: !root.isBlocked && (root.trustIndicator === StatusContactVerificationIcons.TrustedType.Untrustworthy ||
                                     (root.isContact && root.trustIndicator === StatusContactVerificationIcons.TrustedType.Verified))
        icon: root.trustIndicator === StatusContactVerificationIcons.TrustedType.Verified ? "trustedContact"
                                                                                          : "untrustworthyContact"
        width: d.currentSize
        height: width
    }

    // contact?
    StatusIcon {
        visible: !root.isBlocked && root.isContact && root.trustIndicator !== StatusContactVerificationIcons.TrustedType.Verified
        icon: "justContact"
        width: d.currentSize
        height: width
    }
}
