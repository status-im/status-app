import QtQuick

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils

SQUtils.QObject {
    id: root

    property string id: ""
    property string compressedPubKey: ""
    property string displayName: ""
    property bool usesDefaultName: false
    property string secondaryName: ""

    property bool isEnsVerified: false
    property bool isContact: false
    property int trustIndicator: StatusContactVerificationIcons.TrustedType.None
    property bool isBlocked: false

    property string badgeImage: ""

    property StatusProfileImageSettings profileImage: StatusProfileImageSettings {
        pubkey: root.id
        width: 40
        height: 40
    }
}
