import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core.Theme

import AppLayouts.Communities.popups

SplitView {
    id: root

    Logs { id: logs }

    readonly property string shortMessage: "Welcome to our community! Please read and follow the rules below."

    readonly property string longMessage: "Welcome to our community! We're glad you're here.

Please take a moment to read these rules carefully before participating.

1. Be respectful. Treat all members with kindness and courtesy. Harassment, hate speech, or personal attacks of any kind will not be tolerated.

2. Stay on topic. Keep discussions relevant to the community's focus. Off-topic content may be removed without notice.

3. No spam or self-promotion. Do not post unsolicited advertisements, referral links, or repetitive messages.

4. Protect privacy. Do not share personal information about yourself or others without explicit consent.

5. Follow the law. Do not post content that is illegal in your jurisdiction or that violates the rights of others.

6. Report issues. If you see behaviour that violates these rules, use the report function rather than engaging directly.

Violations may result in a warning, temporary suspension, or permanent removal from the community at the discretion of the moderators."

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground { anchors.fill: parent }

        CommunityRulesPopup {
            visible: true
            modal: false
            closePolicy: Popup.NoAutoClose
            parent: root.Overlay.overlay

            name: communityName.text
            introMessage: longMessageCheck.checked ? root.longMessage : root.shortMessage
            image: ""
            color: Theme.palette.primaryColor1

            onClosed: logs.logEvent("CommunityRulesPopup::closed")
        }
    }

    LogsAndControlsPanel {
        SplitView.preferredWidth: 300
        SplitView.fillHeight: true

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.halfPadding

            Label { text: "Community name"; font.bold: true }

            TextField {
                id: communityName
                Layout.fillWidth: true
                text: "Status"
            }

            CheckBox {
                id: longMessageCheck
                text: "Long intro message (tests scroll)"
                checked: true
            }
        }
    }
}

// category: Popups
// status: good
