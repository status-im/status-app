import QtQuick
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls

// Create once per view, alongside its shared StatusMessageHeaderAppearance.
MessageHeaderServices {
    id: root

    property int tooltipDelay: -1
    property string tooltipText: ""
    property bool tooltipVisible: false
    readonly property bool tooltipCreated: !!popup.item
    readonly property bool tooltipOpened: !!popup.item && popup.item.opened

    function verificationText(header) {
        if (header.dataIsContact()) {
            if (header.dataTrustIndicator() === StatusContactVerificationIcons.TrustedType.Verified)
                return qsTranslate("StatusContactVerificationIcons", "Trusted contact")
            if (header.dataTrustIndicator() === StatusContactVerificationIcons.TrustedType.Untrustworthy)
                return qsTranslate("StatusContactVerificationIcons", "Untrusted contact")
            return qsTranslate("StatusContactVerificationIcons", "Contact")
        }
        return qsTranslate("StatusContactVerificationIcons", "Untrusted")
    }

    onTooltipRequested: {
        const header = root.tooltipTarget
        root.tooltipText = root.tooltipPart === MessageHeaderItem.Timestamp
                ? header.fullTimestampText() : root.verificationText(header)
        if (root.tooltipText.length) {
            popup.active = true
            root.tooltipVisible = true
        }
    }
    onTooltipDismissed: root.tooltipVisible = false

    resendDelegate: Component {
        StatusButton {
            required property MessageHeaderItem header
            objectName: "nativeResendButton"
            verticalPadding: 2
            horizontalPadding: 6
            size: StatusBaseButton.Size.Small
            type: StatusBaseButton.Type.Warning
            font.pixelSize: header.appearance.detailFont.pixelSize
            text: qsTranslate("StatusMessageHeader", "Resend")
            onClicked: header.resendClicked()
        }
    }

    readonly property Connections clockConnection: Connections {
        target: StatusSharedUpdateTimer
        function onTriggered() { root.tick() }
    }

    // One shared anchor preserves the former renderer child's position/size,
    // including taller allocated headers and space reserved for Resend.
    readonly property Item tooltipAnchor: Item {
        parent: root.tooltipTarget
        x: root.tooltipTarget?.textRect.x ?? 0
        y: root.tooltipTarget?.textRect.y ?? 0
        width: root.tooltipTarget?.textRect.width ?? 0
        height: root.tooltipTarget?.textRect.height ?? 0
    }

    readonly property Loader popup: Loader {
        active: false
        sourceComponent: StatusToolTip {
            id: tip
            property bool completed: false
            Component.onCompleted: completed = true
            objectName: "messageHeaderSharedTooltip"
            parent: root.tooltipAnchor
            text: root.tooltipText
            maxWidth: 350
            visible: completed && root.tooltipVisible && !!root.tooltipTarget && !!text
            Binding on delay { when: root.tooltipDelay >= 0; value: root.tooltipDelay }
        }
    }
}
