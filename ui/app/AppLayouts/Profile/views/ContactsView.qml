import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import AppLayouts.Profile.panels
import AppLayouts.Profile.popups
import AppLayouts.Profile.stores
import AppLayouts.stores as AppLayoutStores

import shared
import shared.controls
import shared.stores as SharedStores
import shared.views
import shared.views.chat

import utils

import QtModelsToolkit
import SortFilterProxyModel

SettingsContentBase {
    id: root

    property AppLayoutStores.ContactsStore contactsStore
    property SharedStores.UtilsStore utilsStore

    required property var mutualContactsModel
    required property var blockedContactsModel
    required property var pendingContactsModel
    required property int pendingReceivedContactsCount
    required property var dismissedReceivedRequestContactsModel

    property alias searchStr: searchBox.text

    titleRowComponentLoader.sourceComponent: StatusButton {
        objectName: "ContactsView_ContactRequest_Button"

        text: qsTr("Send contact request to chat key")
        onClicked: sendContactRequestComponent.createObject(root).open()
    }

    function openContextMenu(model, pubKey) {
        const entry = ModelUtils.getByKey(model, "pubKey", pubKey)

        const profileType = Utils.getProfileType(entry.isCurrentUser, false, entry.isBlocked)
        const contactType = Utils.getContactType(entry.contactRequest, entry.isContact)

        const params = {
            pubKey, profileType, contactType,
            compressedPubKey: entry.compressedPubKey,
            emojiHash: root.utilsStore.getEmojiHash(pubKey),
            displayName: entry.preferredDisplayName,
            userIcon: entry.icon,
            colorId: entry.colorId,
            trustStatus: entry.trustStatus,
            onlineStatus: entry.onlineStatus,
            ensVerified: entry.isEnsVerified,
            usesDefaultName: entry.usesDefaultName,
            hasLocalNickname: !!entry.localNickname
        }

        Global.openMenu(contactContextMenuComponent, this, params)
    }

    headerComponents: ColumnLayout {
        width: root.contentWidth
        spacing: Theme.padding

        StatusTabBar {
            id: contactsTabBar

            Layout.fillWidth: true

            StatusTabButton {
                objectName: "ContactsView_Contacts_Button"

                width: implicitWidth
                text: qsTr("Contacts")
            }
            StatusTabButton {
                objectName: "ContactsView_PendingRequest_Button"

                width: implicitWidth
                enabled: !root.pendingContactsModel.ModelCount.empty
                text: qsTr("Pending Requests")
                badge.value: root.pendingReceivedContactsCount
            }
            StatusTabButton {
                objectName: "ContactsView_DismissedRequest_Button"

                width: implicitWidth
                enabled: !root.dismissedReceivedRequestContactsModel.ModelCount.empty
                text: qsTr("Dismissed Requests")
            }
            StatusTabButton {
                objectName: "ContactsView_Blocked_Button"

                width: implicitWidth
                enabled: !root.blockedContactsModel.ModelCount.empty
                text: qsTr("Blocked")
            }
        }

        SearchBox {
            id: searchBox

            Layout.fillWidth: true
            placeholderText: qsTr("Search by name or chat key")
        }
    }

    StackLayout {
        width: root.contentWidth
        height: root.availableHeight

        currentIndex: contactsTabBar.currentIndex

        ContactsList {
            inviteButtonVisible: searchBox.text === ""

            model: SortFilterProxyModel {
                sourceModel: root.mutualContactsModel

                filters: UserSearchFilter {
                    searchString: searchBox.text
                }

                sorters: [
                    RoleSorter {
                        roleName: "isVerified"
                        sortOrder: Qt.DescendingOrder
                    },
                    StringSorter {
                        roleName: "preferredDisplayName"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                ]
            }

            section.property: "isVerified"
            section.delegate: SectionComponent {
                text: section === "true" ? qsTr("Trusted Contacts")
                                         : qsTr("Contacts")
            }

            section.labelPositioning: ViewSection.InlineLabels |
                                      ViewSection.CurrentLabelAtStart
        }

        ContactsList {
            model: SortFilterProxyModel {
                sourceModel: root.pendingContactsModel

                filters: UserSearchFilter {
                    searchString: searchBox.text
                }

                sorters: [
                    FilterSorter { // Received CRs first
                        ValueFilter {
                            roleName: "contactRequest"
                            value: Constants.ContactRequestState.Received
                        }
                    },

                    StringSorter {
                        roleName: "preferredDisplayName"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                ]
            }

            section.property: "contactRequest"
            section.delegate: SectionComponent {
                text: section === `${Constants.ContactRequestState.Received}`
                      ? qsTr("Received") : qsTr("Sent")
            }

            section.labelPositioning: ViewSection.InlineLabels |
                                      ViewSection.CurrentLabelAtStart
        }

        ContactsList {
            model: SortFilterProxyModel {
                sourceModel: root.dismissedReceivedRequestContactsModel

                filters: UserSearchFilter {
                    searchString: searchBox.text
                }

                sorters: StringSorter {
                    roleName: "preferredDisplayName"
                    caseSensitivity: Qt.CaseInsensitive
                }
            }
        }

        ContactsList {
            model: SortFilterProxyModel {
                sourceModel: root.blockedContactsModel

                filters: UserSearchFilter {
                    searchString: searchBox.text
                }

                sorters: StringSorter {
                    roleName: "preferredDisplayName"
                    caseSensitivity: Qt.CaseInsensitive
                }
            }
        }
    }

    component ContactsList: ContactsListPanel {
        onProfilePopupRequested: Global.openProfilePopup(publicKey)
        onContextMenuRequested: root.openContextMenu(model, publicKey)

        onSendMessageRequested: root.contactsStore.joinPrivateChat(publicKey)
        onAcceptContactRequested: root.contactsStore.acceptContactRequest(publicKey, "")
        onRejectContactRequested: root.contactsStore.dismissContactRequest(publicKey, "")
        onRejectionRemoved: root.contactsStore.acceptContactRequest(publicKey, "")
    }

    component SectionComponent: Rectangle {
        required property string section
        property alias text: sectionText.text

        width: ListView.view.width
        height: sectionText.implicitHeight
        color: Theme.palette.statusListItem.backgroundColor

        StatusBaseText {
            id: sectionText
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            topPadding: Theme.halfPadding
            bottomPadding: Theme.halfPadding

            color: Theme.palette.baseColor1
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    Component {
        id: sendContactRequestComponent

        SendContactRequestToChatKeyModal {
            contactsStore: root.contactsStore
            utilsStore: root.utilsStore
            onClosed: destroy()
        }
    }

    Component {
        id: contactContextMenuComponent

        ProfileContextMenu {
            id: menu

            property string pubKey

            onOpenProfileClicked: Global.openProfilePopup(menu.pubKey, null, null)
            onReviewContactRequest: Global.openReviewContactRequestPopup(menu.pubKey, null)
            onSendContactRequest: Global.openContactRequestPopup(menu.pubKey, null)
            onEditNickname: Global.openNicknamePopupRequested(menu.pubKey, null)
            onUnblockContact: Global.unblockContactRequested(menu.pubKey)
            onMarkAsUntrusted: Global.markAsUntrustedRequested(menu.pubKey)
            onRemoveContact: Global.removeContactRequested(menu.pubKey)
            onBlockContact: Global.blockContactRequested(menu.pubKey)

            onCreateOneToOneChat: root.contactsStore.joinPrivateChat(menu.pubKey)
            onRemoveTrustStatus: root.contactsStore.removeTrustStatus(menu.pubKey)
            onRemoveNickname: root.contactsStore.changeContactNickname(menu.pubKey, "",
                                                                       menu.displayName, true)
            onMarkAsTrusted: Global.openMarkAsIDVerifiedPopup(menu.pubKey, null)
            onRemoveTrustedMark: Global.openRemoveIDVerificationDialog(menu.pubKey, null)

            onClosed: destroy()
        }
    }
}
