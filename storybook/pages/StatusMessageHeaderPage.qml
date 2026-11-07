import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

import Storybook

SplitView {
    id: root

    Logs { id: logs }

    readonly property double sampleTime: Date.now()
    readonly property string sampleId: "0x04a1b2c3d4e5f678901234567890abcdef1234567890abcdef1234567890abcdef"
    readonly property var variants: [
        {title: "Incoming · display name and public key", name: "Alice"},
        {title: "Contact", name: "Alice", contact: true},
        {title: "Verified contact", name: "Alice", contact: true,
         trust: StatusContactVerificationIcons.TrustedType.Verified},
        {title: "Untrusted sender", name: "Mallory",
         trust: StatusContactVerificationIcons.TrustedType.Untrustworthy},
        {title: "ENS / secondary name", name: "Alice", secondary: "alice.stateofus.eth", contact: true},
        {title: "Message origin · replaces public key", name: "Alice", origin: "#general"},
        {title: "Minimal · no public key, name not clickable", name: "Alice", detail: "", clickable: false},
        {title: "Emoji in display name", name: "Alice 👩🏽‍💻 🎉", contact: true},
        {title: "Markup rendered literally", name: "<b>Alice & Bob</b>", detail: ""},
        {title: "Long display and secondary names", name: "Alice with a very long display name that wraps",
         secondary: "a-very-long-name.stateofus.eth", contact: true},
        {title: "Right-to-left display name", name: "مرحبا بالعالم · שלום", secondary: "alice.eth"},
        {title: "Yesterday", name: "Alice", age: 24 * 60 * 60 * 1000},
        {title: "Full timestamp", name: "Alice", fullTimestamp: true},
        {title: "Own message · unknown delivery status", own: true},
        {title: "Own message · sending", own: true, status: StatusMessage.OutgoingStatus.Sending},
        {title: "Own message · sent", own: true, status: StatusMessage.OutgoingStatus.Sent},
        {title: "Own message · delivered", own: true, status: StatusMessage.OutgoingStatus.Delivered},
        {title: "Own message · expired / resend", own: true, status: StatusMessage.OutgoingStatus.Expired},
        {title: "Own message · resend error", own: true, status: StatusMessage.OutgoingStatus.Expired,
         error: "Connection unavailable"}
    ]

    ScrollView {
        id: gallery
        SplitView.fillWidth: true
        SplitView.minimumWidth: 360
        clip: true
        contentWidth: Math.max(availableWidth, widthSlider.value + 48)
        background: Rectangle { color: root.Theme.palette.background }

        ColumnLayout {
            width: gallery.contentWidth
            spacing: 12

            Label {
                Layout.margins: 16
                text: "StatusMessageHeader"
                font.bold: true
                font.pixelSize: 22
                color: root.Theme.palette.directColor1
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: "Resize the headers to inspect wrapping. Hover names, trust icons and timestamps; click a name or Resend to log the event."
                wrapMode: Text.WordWrap
                color: root.Theme.palette.baseColor1
            }

            Repeater {
                model: root.variants
                delegate: Frame {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    padding: 8
                    background: Rectangle {
                        color: root.Theme.palette.background
                        border.color: root.Theme.palette.baseColor2
                        radius: 6
                    }

                    contentItem: ColumnLayout {
                        spacing: 12
                        Label {
                            Layout.fillWidth: true
                            text: card.modelData.title
                            wrapMode: Text.WordWrap
                            color: root.Theme.palette.baseColor1
                        }
                        StatusMessageHeader {
                            Layout.preferredWidth: widthSlider.value
                            Layout.maximumWidth: widthSlider.value
                            Layout.alignment: Qt.AlignLeft
                            sender.id: root.sampleId
                            sender.displayName: card.modelData.name ?? "Alice"
                            sender.secondaryName: card.modelData.secondary ?? ""
                            sender.isContact: card.modelData.contact ?? false
                            sender.trustIndicator: card.modelData.trust ?? StatusContactVerificationIcons.TrustedType.None
                            timestamp: root.sampleTime - (card.modelData.age ?? 60000)
                            tertiaryDetail: card.modelData.detail ?? root.sampleId
                            amISender: card.modelData.own ?? false
                            displayNameClickable: card.modelData.clickable ?? true
                            messageOriginInfo: card.modelData.origin ?? ""
                            showFullTimestamp: fullTimestamp.checked || (card.modelData.fullTimestamp ?? false)
                            outgoingStatus: card.modelData.status ?? StatusMessage.OutgoingStatus.Unknown
                            showOutgoingStatusLabel: statusLabels.checked
                            resendError: card.modelData.error ?? ""
                            isMobile: mobileMode.checked
                            onClicked: logs.logEvent("clicked", ["variant"], [card.modelData.title])
                            onResendClicked: logs.logEvent("resendClicked", ["variant"], [card.modelData.title])
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: 16 }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 260
        SplitView.preferredWidth: 320
        logsView.logText: logs.logText

        controls: ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 12
            Label {
                text: "Header width: " + Math.round(widthSlider.value) + " px"
            }
            Slider {
                id: widthSlider
                objectName: "headerWidthControl"
                Layout.fillWidth: true
                from: 240
                to: 900
                value: 600
                stepSize: 1
            }
            CheckBox { id: statusLabels; objectName: "headerStatusLabelsControl"; text: "Show delivery status labels"; checked: true }
            CheckBox { id: mobileMode; objectName: "headerMobileControl"; text: "Mobile mode" }
            CheckBox { id: fullTimestamp; objectName: "headerTimestampControl"; text: "Full timestamps for all variants" }
        }
    }
}

// category: Chat
// status: good
