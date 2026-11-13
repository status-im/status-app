pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme
import AppLayouts.Profile.helpers

SplitView {
    id: root

    readonly property string profileUrl: "https://status.app/u#zQ3shwQPhRuDJSjVGVBnTjCdgXy5i9WQaeVPdGJD6yTarJQSj"
    readonly property string mentionKey: "0x" + "a".repeat(130)
    readonly property string avatar: "data:image/svg+xml," + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="#4360df"/><circle cx="16" cy="12" r="6" fill="white"/><ellipse cx="16" cy="30" rx="12" ry="10" fill="white"/></svg>')

    ListModel {
        id: contacts
        ListElement { pubKey: "profile-key"; displayName: "JohnDoe.ETH"; thumbnailImage: "" }
    }

    ProfileLinkResolver {
        id: resolver
        text: source.text
        contactsModel: contacts
        parseProfileUrl: url => url === root.profileUrl ? {publicKey: "profile-key", displayName: "JohnDoe.ETH"} : null
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        background: Rectangle { color: Theme.palette.background }

        StatusMessage {
            id: message
            objectName: "profileLinkMessage"
            anchors.centerIn: parent
            width: Math.min(messageWidth.value, parent.width - 32)
            showHeader: false
            textAppearance: MessageTextAppearance { theme: root.Theme }
            previewAppearance: ReplyTextAppearance { theme: root.Theme }
            messageDetails: StatusMessageDetails {
                contentType: StatusMessage.ContentType.Text
                unparsedText: source.text
                mentionsMap: ({[root.mentionKey]: "robertf.ox.eth"})
                inlineLinks: resolver.links
            }
            onLinkActivated: link => activatedLink.text = link
        }
    }

    ScrollView {
        SplitView.preferredWidth: 320
        ColumnLayout {
            width: 300
            spacing: 12
            Label { text: "Message source" }
            TextArea {
                id: source
                Layout.fillWidth: true
                wrapMode: TextEdit.Wrap
                text: "> hey, @" + root.mentionKey + ", Do we still plan to ship this with v2.1 or " + root.profileUrl + " next release cycle?"
            }
            Label { text: "Profile name" }
            TextField {
                Layout.fillWidth: true
                text: "JohnDoe.ETH"
                onTextChanged: contacts.setProperty(0, "displayName", text)
            }
            CheckBox {
                text: "Show avatar"
                checked: true
                onCheckedChanged: contacts.setProperty(0, "thumbnailImage", checked ? root.avatar : "")
                Component.onCompleted: contacts.setProperty(0, "thumbnailImage", root.avatar)
            }
            Label { text: "Message width" }
            Slider { id: messageWidth; from: 100; to: 700; value: 380; Layout.fillWidth: true }
            CheckBox {
                text: "Dark theme"
                onToggled: root.Theme.style = checked ? Theme.Style.Dark : Theme.Style.Light
            }
            Label { text: "Selected text" }
            TextArea { Layout.fillWidth: true; readOnly: true; wrapMode: TextEdit.Wrap; text: message.selectedText }
            Label { text: "Activated URL" }
            TextArea { id: activatedLink; Layout.fillWidth: true; readOnly: true; wrapMode: TextEdit.Wrap }
        }
    }
}
