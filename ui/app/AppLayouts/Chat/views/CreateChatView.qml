import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import shared.controls.delegates
import shared.status
import shared.stores as SharedStores
import utils

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.helpers

import QtModelsToolkit

Page {
    id: root

    property SharedStores.UtilsStore utilsStore
    property ChatStores.RootStore rootStore
    property ChatStores.CreateChatPropertiesStore createChatPropertiesStore

    property var mutualContactsModel
    property var allContactsModel
    property ContactDetails selfContact

    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)


    QtObject {
        id: d

        function createChat() {
            root.createChatPropertiesStore.createChatInitMessage = chatInput.getTextWithPublicKeys()
            root.createChatPropertiesStore.createChatFileUrls = chatInput.fileUrlsAndSources
            membersSelector.createChat()

            membersSelector.cleanup()
            chatInput.textInput.clear()

            Global.closeCreateChatView()
        }
    }

    padding: 0
    implicitWidth: 896

    Behavior on opacity { NumberAnimation {}}
    Behavior on anchors.bottomMargin { NumberAnimation { duration: 30 }}

    background: Rectangle {
        color: Theme.palette.statusAppLayout.rightPanelBackgroundColor
    }

    header: Item {
        implicitHeight: headerLayout.implicitHeight + headerLayout.anchors.topMargin + headerLayout.anchors.bottomMargin
        RowLayout {
            id: headerLayout
            anchors.fill: parent
            MembersSelectorView {
                id: membersSelector
                objectName: "createChatMembersSelector"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Theme.halfPadding
                Layout.rightMargin: Theme.halfPadding

                utilsStore: root.utilsStore
                contactsModel: root.mutualContactsModel
                allContactsModel: root.allContactsModel
                selfChatPublicKey: model.ModelCount.empty ? (root.selfContact?.publicKey ?? "") : ""
                selfChatCompressedPublicKey: root.selfContact?.compressedPubKey ?? ""
                suppressSuggestions: selfContactItem.visible && (matchesSelfChatKey || suggestionsModel.count === 0)

                function createChat() {
                    if (model.count === 0) {
                        console.warn("Can't create chat with no members")
                        return
                    }
                    if (model.count === 1) {
                        const member = model.get(0)
                        const ensName = member.displayName.includes(".eth") ? member.displayName : ""
                        root.rootStore.chatCommunitySectionModule.createOneToOneChat("", member.pubKey, ensName)
                    } else {
                        var groupName = []
                        var pubKeys = []
                        for (var i = 0; i < model.count; i++) {
                            const member = model.get(i)
                            groupName.push(member.displayName)
                            pubKeys.push(member.pubKey)
                        }
                        root.rootStore.chatCommunitySectionModule.createGroupChat("", groupName.join("&"), JSON.stringify(pubKeys))
                    }
                }

                onConfirmed: { d.createChat() }

                onRejected: {
                    cleanup()
                    Global.closeCreateChatView()
                }

                onVisibleChanged: {
                    if (visible)
                        edit.forceActiveFocus()
                }

                onEnterKeyPressed: {
                    if (selfContactItem.visible && (suppressSuggestions || (edit.text === "" && !contactsList.visible))) {
                        selfContactItem.openChat()
                    } else {
                        entryAccepted(contactsList.itemAtIndex(contactsList.currentIndex))
                    }
                }

                onUpKeyPressed: contactsList.decrementCurrentIndex()

                onDownKeyPressed: contactsList.incrementCurrentIndex()

                onResolveENS: (address) => root.rootStore.contactsStore.resolveENS(address)

                onPopulateContactDetails: (pubkey) => root.rootStore.contactsStore.populateContactDetails(pubkey)

                Connections {
                    enabled: membersSelector.visible
                    target: root.rootStore.contactsStore
                    function onResolvedENS(resolvedPubKey: string, resolvedAddress: string, uuid: string) {
                        membersSelector.ensResolved(resolvedPubKey, resolvedAddress, uuid);
                    }
                }

            }
        }
    }

    contentItem: Item {
        ColumnLayout {
            anchors {
                fill: parent
                topMargin: Theme.bigPadding
                bottomMargin: Theme.padding
                leftMargin: Theme.halfPadding
            }

            StatusBaseText {
                Layout.alignment: Qt.AlignTop
                Layout.leftMargin: Theme.halfPadding
                visible: contactsList.visible || selfContactItem.visible
                text: qsTr("Contacts")
                color: Theme.palette.baseColor1
            }

            StatusMemberListItem {
                id: selfContactItem
                objectName: "createChatSelfContact"

                Layout.fillWidth: true
                visible: {
                    if (!root.selfContact?.publicKey || !membersSelector.model.ModelCount.empty)
                        return false
                    const text = membersSelector.edit.text.trim()
                    const query = text.toLowerCase()
                    return membersSelector.matchesSelfChatKey || userName.toLowerCase().includes(query)
                            || root.selfContact.publicKey.toLowerCase().includes(query)
                            || pubKey.includes(text)
                }
                userName: root.selfContact ? qsTr("%1 (You)").arg(root.selfContact.preferredDisplayName) : ""
                pubKey: root.selfContact?.compressedPubKey ?? ""
                usesDefaultName: root.selfContact?.usesDefaultName ?? false
                isContact: true
                icon.name: root.selfContact?.icon ?? ""
                icon.color: Utils.colorForColorId(Theme.palette, root.selfContact?.colorId ?? 0)
                onClicked: openChat()

                function openChat() {
                    root.rootStore.contactsStore.joinPrivateChat(root.selfContact.publicKey)
                    membersSelector.cleanup()
                    chatInput.textInput.clear()
                    Global.closeCreateChatView()
                }
            }

            StatusListView {
                id: contactsList
                objectName: "createChatContactsList"

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: membersSelector.suggestionsModel.count &&
                         !(membersSelector.edit.text !== "")
                implicitWidth: contentItem.childrenRect.width
                model: membersSelector.suggestionsModel
                delegate: ContactListItemDelegate {
                    width: ListView.view.width
                    highlighted: ListView.isCurrentItem
                    onClicked: membersSelector.entryAccepted(this)
                }
            }

            StatusChatInput {
                id: chatInput

                // Pinpoint default padding
                Theme.padding: Theme.defaultPadding

                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                visible: !membersSelector.model.ModelCount.empty
                closeGifPopupAfterSelection: true
                usersModel: membersSelector.selectedContactsModel
                usersModelIncludeAtEveryone: membersSelector.model.ModelCount.count > 1
                paymentRequestFeatureEnabled: false
                onStickerSelected: (hashId, packId, url) => {
                    root.createChatPropertiesStore.createChatStickerHashId = hashId;
                    root.createChatPropertiesStore.createChatStickerPackId = packId;
                    root.createChatPropertiesStore.createChatStickerUrl = url;
                    membersSelector.createChat();
                }

                onOpenGifPopupRequest: (params, cbOnGifSelected, cbOnClose) =>
                    root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)
                onSendMessageRequested: { d.createChat() }
            }
        }

        StatusBaseText {
            anchors.centerIn: parent
            width: Math.min(553, parent.width - 2 * Theme.padding)
            visible: !root.selfContact?.publicKey && root.mutualContactsModel.ModelCount.empty
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            color: Theme.palette.baseColor1
            text: qsTr("You can only send direct messages to your Contacts.\n
Send a contact request to the person you would like to chat with, you will be able to chat with them once they have accepted your contact request.")
        }
    }
}
