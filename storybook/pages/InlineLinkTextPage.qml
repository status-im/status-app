pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import utils
import Models

SplitView {
    id: root

    readonly property ChatTextAppearance textAppearance: MessageTextAppearance { theme: root.Theme }
    readonly property string mentionKey: "0x" + "a".repeat(130)
    readonly property var mentionsMap: ({[root.mentionKey]: "robertf.ox.eth"})
    readonly property string statusImage: ModelsData.icons.status
    readonly property string travelImage: "data:image/svg+xml," + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><circle cx="16" cy="16" r="16" fill="#00bfa5"/><path d="M4 25 13 7l7 18z" fill="#8b6549"/><path d="m13 7-4 8 4-2 3 2z" fill="white"/><path d="m12 25 9-16 8 16z" fill="#a57b55"/><path d="m21 9-4 7 4-2 3 2z" fill="white"/></svg>')
    readonly property string bubbleImage: Assets.svg("message-bubble")
    // Key-only URLs from status-go sharedurls fixtures; display metadata is mocked locally.
    readonly property string profileUrl: "https://status.app/u#zQ3shwQPhRuDJSjVGVBnTjCdgXy5i9WQaeVPdGJD6yTarJQSj"
    readonly property string communityUrl: "https://status.app/c#zQ3shYSHp7GoiXaauJMnDcjwU2yNjdzpXLosAWapPS4CFxc11"
    readonly property string channelUrl: "https://status.app/cc/003cdcd5-e065-48f9-b166-b1a94ac75a11#zQ3shYSHp7GoiXaauJMnDcjwU2yNjdzpXLosAWapPS4CFxc11"
    readonly property string channelMessageUrl: "https://status.app/m/0xabcdef1234567890fedcba9876543210003cdcd5-e065-48f9-b166-b1a94ac75a11?message-id=0xmessage-id-123"
    readonly property string groupMessageUrl: "https://status.app/m/travel-group?message-id=0xmessage-id-456"
    // Thread destinations extend the parent URL; the query precedes the community-key fragment.
    readonly property string channelThreadUrl: channelUrl.replace("#", "?thread-id=release-thread#")
    readonly property string groupThreadUrl: "https://status.app/g/?a2=travel-group&thread-id=sierra-park-thread"
    readonly property var examples: [
        {label: "User profile", url: root.profileUrl, visualOnly: false, data: {title: "JohnDoe.ETH", image: Assets.png("chat/chat@2x")}},
        {label: "Community", url: root.communityUrl, visualOnly: false, data: {title: "Status App", image: root.statusImage}},
        {label: "Community channel", url: root.channelUrl, visualOnly: false, data: {title: "Status App", image: root.statusImage, path: [{text: "# channelName"}]}},
        {label: "Message in community channel", url: root.channelMessageUrl, visualOnly: false, data: {title: "Status App", image: root.statusImage, path: [{text: "# channelName"}], trailingIcons: [{image: root.bubbleImage}]}},
        {label: "Message in group", url: root.groupMessageUrl, visualOnly: false, data: {title: "TravelHUB", image: root.travelImage, trailingIcons: [{image: root.bubbleImage}]}},
        {label: "Message in community thread", url: root.channelThreadUrl, visualOnly: false, data: {title: "Status App", image: root.statusImage, path: [{text: "# feedback-desktop"}, {text: "Thread", icon: "thread"}], trailingIcons: [{image: root.bubbleImage}]}},
        {label: "Message in group thread", url: root.groupThreadUrl, visualOnly: false, data: {title: "TravelHub", image: root.travelImage, path: [{text: "Sierra Park - March’27", icon: "thread"}], trailingIcons: [{image: root.bubbleImage}]}},
        {label: "Three path entries", url: "https://example.invalid/three-contexts", visualOnly: true, data: {title: "Status App", image: root.statusImage, path: [{text: "General"}, {text: "# feedback-desktop"}, {text: "Release summary", icon: "thread"}], trailingIcons: [{image: root.bubbleImage}]}}
    ]

    // Mock the store boundary, without duplicating the production URL parser.
    function resolveLink(url) {
        return examples.find(example => example.url === url)?.data || null
    }

    ScrollView {
        id: examplesScroll
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        clip: true
        background: Rectangle { color: Theme.palette.background }

        ColumnLayout {
            width: Math.min(messageWidth.value, examplesScroll.availableWidth - 32)
            x: 16
            spacing: 24

            Repeater {
                model: root.examples
                delegate: ColumnLayout {
                    id: example
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 8
                    Label { text: example.modelData.label; color: Theme.palette.baseColor1 }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: example.modelData.visualOnly
                            ? "Visual fixture only — additional breadcrumb context"
                            : "Status URL format · mocked destination metadata"
                        color: Theme.palette.baseColor1
                    }
                    StatusInlineLinkText {
                        objectName: "inlineLinkExample" + example.index
                        Layout.fillWidth: true
                        appearance: root.textAppearance
                        readonly property string url: destinationUrl.text
                        sourceSegments: MarkdownUtils.toChatTextSegments(withContext.checked
                            ? "> hey, @" + root.mentionKey + ", Do we still plan to ship this with v2.1 or " + url + " next release cycle?"
                            : url, root.mentionsMap)
                        links: {
                            const data = root.resolveLink(url)
                            if (!data)
                                return ({})
                            const labels = [context1.text, context2.text, context3.text]
                            const path = labels.map((text, index) => ({
                                text,
                                icon: data.path?.[index]?.icon || ""
                            })).filter(part => part.text.length > 0)
                            const trailingIcons = showBubble.checked ? [{image: root.bubbleImage}] : []
                            return {[url]: Object.assign({}, data, {title: mainLabel.text, path, trailingIcons})}
                        }
                        onLinkActivated: link => {
                            activatedLink.text = link
                            const data = links[link]
                            activatedPath.text = data
                                ? [data.title, ...(data.path || []).map(part => part.text)].join(" › ")
                                : "Unresolved URL"
                        }
                    }
                    CheckBox {
                        id: editFields
                        text: "Edit fields"
                    }
                    GroupBox {
                        title: "Fields"
                        visible: editFields.checked
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        contentItem: GridLayout {
                            columns: 2
                            Label { text: "Destination URL" }
                            TextField {
                                id: destinationUrl
                                objectName: "inlineLinkDestination" + example.index
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: example.modelData.url
                            }
                            Label { text: "Main label" }
                            TextField {
                                id: mainLabel
                                objectName: "inlineLinkMainLabel" + example.index
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: example.modelData.data.title
                            }
                            Label { text: "Context 1" }
                            TextField {
                                id: context1
                                objectName: "inlineLinkContext1_" + example.index
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: example.modelData.data.path?.[0]?.text || ""
                                placeholderText: "Optional"
                            }
                            Label { text: "Context 2" }
                            TextField {
                                id: context2
                                objectName: "inlineLinkContext2_" + example.index
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: example.modelData.data.path?.[1]?.text || ""
                                placeholderText: "Optional"
                            }
                            Label { text: "Context 3" }
                            TextField {
                                id: context3
                                objectName: "inlineLinkContext3_" + example.index
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: example.modelData.data.path?.[2]?.text || ""
                                placeholderText: "Optional"
                            }
                            Label { text: "Message bubble" }
                            CheckBox {
                                id: showBubble
                                objectName: "inlineLinkShowBubble" + example.index
                                text: "Show"
                                checked: (example.modelData.data.trailingIcons || []).length > 0
                            }
                        }
                    }
                }
            }
        }
    }

    Pane {
        SplitView.preferredWidth: 280
        ColumnLayout {
            anchors.fill: parent
            Label { text: "Available width" }
            Slider { id: messageWidth; from: 120; to: 1000; value: 700; Layout.fillWidth: true }
            CheckBox { id: withContext; text: "Inside a sentence"; checked: true }
            CheckBox {
                text: "Dark theme"
                onToggled: root.Theme.style = checked ? Theme.Style.Dark : Theme.Style.Light
            }
            Label { text: "Activated path" }
            TextArea { id: activatedPath; objectName: "inlineLinkActivatedPath"; Layout.fillWidth: true; readOnly: true; wrapMode: TextEdit.Wrap }
            Label { text: "Activated URL" }
            TextArea { id: activatedLink; objectName: "inlineLinkActivatedUrl"; Layout.fillWidth: true; readOnly: true; wrapMode: TextEdit.Wrap }
            Item { Layout.fillHeight: true }
        }
    }
}
