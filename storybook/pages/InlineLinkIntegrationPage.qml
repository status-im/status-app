pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme
import AppLayouts.Chat.stores as ChatStores
import shared.views.chat
import utils

SplitView {
    id: root

    readonly property string communityUrl: "https://status.app/c#community"
    readonly property string channelUrl: "https://status.app/cc/channel#community"
    readonly property var examples: [
        {label: "Community", url: communityUrl, data: {kind: "community", communityId: "community", communityName: "Status App"}},
        {label: "Community channel", url: channelUrl, data: {kind: "channel", communityId: "community", communityName: "Status App", chatName: "general"}},
        {label: "Message in community channel", url: "https://status.app/m/community-channel?message-id=message", data: {kind: "message", communityId: "community", communityName: "Status App", chatName: "general"}},
        {label: "Message in group", url: "https://status.app/m/group?message-id=message", data: {kind: "message", chatName: "TravelHUB"}},
        {label: "Community thread", url: channelUrl.replace("#", "?thread-id=thread#"), data: {kind: "thread", communityId: "community", communityName: "Status App", chatName: "feedback-desktop", threadId: "thread"}},
        {label: "Group thread", url: "https://status.app/g/?a2=group&thread-id=thread", data: {kind: "thread", chatName: "TravelHUB", threadId: "thread", threadName: "Sierra Park"}},
        {label: "Message in group thread", url: "https://status.app/m/group?message-id=thread-message", data: {kind: "message", chatName: "TravelHUB", threadId: "thread", threadName: "Sierra Park"}},
        {label: "Direct thread (internal scheme)", url: "status-app://p/?thread-id=thread", data: {kind: "thread", chatName: "Alice", threadId: "thread", threadName: "Weekend plans"}}
    ]

    ScrollView {
        id: scroll
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        clip: true
        background: Rectangle { color: Theme.palette.background }

        ColumnLayout {
            width: Math.min(messageWidth.value, scroll.availableWidth - 32)
            x: 16
            spacing: 24

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Real MessageView and inline resolver; destination IDs and backend metadata are mocked."
                color: Theme.palette.baseColor1
            }
            Repeater {
                model: root.examples
                delegate: ColumnLayout {
                    id: example
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: example.modelData.label; color: Theme.palette.baseColor1 }
                    MessageView {
                        id: message
                        objectName: "inlineIntegrationMessage" + example.index
                        Layout.fillWidth: true
                        unparsedText: withContext.checked ? "Before " + example.modelData.url + " after" : example.modelData.url
                        textAppearance: MessageTextAppearance { theme: root.Theme }
                        previewAppearance: ReplyTextAppearance { theme: root.Theme }
                        messageStore: ChatStores.MessageStore {
                            inlineLinkRevision: (noAccess.checked ? 1 : 0) + (unknown.checked ? 2 : 0) + (unavailable.checked ? 4 : 0)
                            function parseInlineLink(url) { return {url} }
                            function resolveInlineLink(target) {
                                if (target.url !== example.modelData.url)
                                    return null
                                const data = Object.assign({}, example.modelData.data)
                                if (unknown.checked) {
                                    data.communityName = ""
                                    data.chatName = ""
                                    data.threadName = ""
                                }
                                data.noAccess = noAccess.checked
                                data.contentUnavailable = unavailable.checked
                                return data
                            }
                        }
                    }
                }
            }
        }
    }

    ScrollView {
        SplitView.preferredWidth: 300
        ColumnLayout {
            width: 280
            spacing: 12
            CheckBox { id: withContext; text: "Embedded in a sentence"; checked: true }
            CheckBox { id: noAccess; objectName: "inlineIntegrationNoAccess"; text: "No access" }
            CheckBox { id: unavailable; objectName: "inlineIntegrationUnavailable"; text: "Content unavailable" }
            CheckBox { id: unknown; objectName: "inlineIntegrationUnknown"; text: "Missing destination names" }
            Label { text: "Message width" }
            Slider { id: messageWidth; from: 160; to: 700; value: 600; Layout.fillWidth: true }
            CheckBox {
                text: "Dark theme"
                onToggled: root.Theme.style = checked ? Theme.Style.Dark : Theme.Style.Light
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Standalone URLs stay unchanged. Use InlineLinkText for renderer controls and ProfileLinks for contact metadata."
            }
        }
    }
}
