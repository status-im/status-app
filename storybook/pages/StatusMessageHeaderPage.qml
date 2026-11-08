import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import Storybook

// Legacy StatusMessageHeader next to the native StatusMessageHeaderPrototype
// for the same inputs, with the number of visual items each one builds.
SplitView {
    id: root

    Logs { id: logs }

    readonly property double now: Date.now()
    readonly property double day: 86400000

    // One entry per variant: header data plus a short description.
    readonly property var variants: [
        { label: "Incoming", data: {} },
        { label: "Incoming contact", data: { isContact: true } },
        { label: "Trusted contact", data: { isContact: true, trustIndicator: 1 } },
        { label: "Untrusted contact", data: { isContact: true, trustIndicator: 2 } },
        { label: "Untrusted", data: { trustIndicator: 2 } },
        { label: "Secondary name", data: { secondaryName: "alice.eth" } },
        { label: "Secondary name, contact", data: { secondaryName: "alice.eth", isContact: true } },
        { label: "Origin info", data: { messageOriginInfo: "Discord" } },
        { label: "Empty tertiary detail", data: { tertiaryDetail: "" } },
        { label: "Yesterday", data: { timestamp: root.now - root.day } },
        { label: "This week", data: { timestamp: root.now - 3 * root.day } },
        { label: "Older", data: { timestamp: root.now - 400 * root.day } },
        { label: "Long name", data: { displayName: "A remarkably long display name that will need to wrap at narrow widths" } },
        { label: "Right-to-left name", data: { displayName: "مرحبا بالعالم" } },
        { label: "Own, sending", data: { amISender: true, outgoingStatus: 1 } },
        { label: "Own, sent", data: { amISender: true, outgoingStatus: 2 } },
        { label: "Own, delivered", data: { amISender: true, outgoingStatus: 3 } },
        { label: "Own, expired (resend)", data: { amISender: true, outgoingStatus: 4 } },
        { label: "Own, failed to resend", data: { amISender: true, outgoingStatus: 5, resendError: "network unreachable" } },
    ]

    function headerData(variant) {
        return Object.assign({ senderId: "0x04a1b2c3d4e5f60718293a4b5c6d7e8f9", displayName: "Alice",
                               timestamp: root.now }, variant.data)
    }

    function countItems(item) {
        let n = 1
        for (let i = 0; i < item.children.length; ++i)
            n += countItems(item.children[i])
        return n
    }

    StatusMessageHeaderAppearance {
        id: headerAppearance
        theme: root.Theme
    }

    StatusMessageHeaderServices {
        id: headerServices
    }

    Component {
        id: senderComponent
        StatusMessageSenderDetails {}
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth

            Column {
                width: Math.min(parent.width, widthSlider.value)
                spacing: 18

                Repeater {
                    model: root.variants

                    delegate: Column {
                        id: row

                        required property var modelData
                        readonly property var fixture: root.headerData(modelData)

                        width: parent.width
                        spacing: 4

                        Label {
                            text: row.modelData.label + "  —  legacy " + root.countItems(legacy)
                                  + " items, native " + root.countItems(native) + " items"
                            font.bold: true
                        }

                        StatusMessageHeader {
                            id: legacy
                            width: parent.width
                            sender: senderComponent.createObject(legacy, {
                                id: row.fixture.senderId,
                                displayName: row.fixture.displayName,
                                secondaryName: row.fixture.secondaryName ?? "",
                                isContact: row.fixture.isContact ?? false,
                                trustIndicator: row.fixture.trustIndicator ?? 0
                            })
                            tertiaryDetail: row.fixture.tertiaryDetail ?? sender.id
                            timestamp: row.fixture.timestamp
                            amISender: row.fixture.amISender ?? false
                            messageOriginInfo: row.fixture.messageOriginInfo ?? ""
                            resendError: row.fixture.resendError ?? ""
                            outgoingStatus: row.fixture.outgoingStatus ?? 0
                            displayNameClickable: clickableBox.checked
                            showFullTimestamp: fullTimestampBox.checked
                            showOutgoingStatusLabel: statusLabelBox.checked
                            isMobile: mobileBox.checked
                            onClicked: logs.logEvent("legacy clicked " + row.modelData.label)
                            onResendClicked: logs.logEvent("legacy resend " + row.modelData.label)
                        }

                        StatusMessageHeaderPrototype {
                            id: native
                            width: parent.width
                            appearance: headerAppearance
                            services: headerServices
                            headerData: row.fixture
                            displayNameClickable: clickableBox.checked
                            showFullTimestamp: fullTimestampBox.checked
                            showOutgoingStatusLabel: statusLabelBox.checked
                            isMobile: mobileBox.checked
                            onClicked: logs.logEvent("native clicked " + row.modelData.label)
                            onResendClicked: logs.logEvent("native resend " + row.modelData.label)
                        }
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        logsView.logText: logs.logText

        ColumnLayout {
            Label { text: "Width: " + Math.round(widthSlider.value) }
            Slider {
                id: widthSlider
                from: 160
                to: 900
                value: 600
            }
            CheckBox { id: clickableBox; text: "displayNameClickable"; checked: true }
            CheckBox { id: fullTimestampBox; text: "showFullTimestamp" }
            CheckBox { id: statusLabelBox; text: "showOutgoingStatusLabel" }
            CheckBox { id: mobileBox; text: "isMobile" }
            CheckBox {
                text: "Dark theme"
                onToggled: root.Theme.style = checked ? Theme.Style.Dark : Theme.Style.Light
            }
        }
    }
}

// category: Components
// status: good
