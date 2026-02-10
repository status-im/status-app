import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.views
import shared.stores as SharedStores
import mainui

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Profile.helpers
import AppLayouts.Wallet.stores as WalletStores

import Storybook
import Models

SplitView {
    id: root

    property bool globalUtilsReady: false
    property bool globalCommunitiesModuleInstReady: false

    // globalUtilsInst mock
    QtObject {
        function isCompressedPubKey() {
            return false
        }

        Component.onCompleted: {
            Utils.globalUtilsInst = this
            root.globalUtilsReady = true

        }
        Component.onDestruction: {
            root.globalUtilsReady = false
            Utils.globalUtilsInst = {}
        }
    }

    // communitiesModuleInst mock
    QtObject {
        function shareCommunityUrlWithData(communityId) {
            return "https://status.app/0x" + communityId
        }

        Component.onCompleted: {
            Utils.communitiesModuleInst = this
            root.globalCommunitiesModuleInstReady = true

        }
        Component.onDestruction: {
            root.globalCommunitiesModuleInstReady = false
            Utils.communitiesModuleInst = {}
        }
    }

    SharedStores.UtilsStore {
        id: mockUtilsStore
        function getEmojiHash(publicKey) {
            return ["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮","🤷🏻‍♂️", "🤦🏻",
                    "📣", "🤎", "👷🏽", "😺", "🥞", "🔃", "🧝🏽‍♂️"]
        }

        function getCompressedPk(publicKey) { return "zx3sh" + publicKey }

        function isCompressedPubKey(publicKey) { return true }

        function isAlias(name) { return false }
    }

    ProfileStores.ProfileStore {
        id: mockProfileStore
        function getQrCodeSource() {
            return "https://upload.wikimedia.org/wikipedia/commons/4/41/QR_Code_Example.svg"
        }
    }

    AppLayoutStores.ContactsStore {
        id: mockContactsStore
        function joinPrivateChat(publicKey) {
            logs.logEvent("contactsStore::joinPrivateChat", ["publicKey"], arguments)
        }

        function markUntrustworthy(publicKey) {
            logs.logEvent("contactsStore::markUntrustworthy", ["publicKey"], arguments)
        }

        function removeContact(publicKey) {
            logs.logEvent("contactsStore::removeContact", ["publicKey"], arguments)
        }

        function acceptContactRequest(publicKey, contactRequestId) {
            logs.logEvent("contactsStore::acceptContactRequest", ["publicKey, contactRequestId"], arguments)
        }

        function dismissContactRequest(publicKey, contactRequestId) {
            logs.logEvent("contactsStore::dismissContactRequest", ["publicKey, contactRequestId"], arguments)
        }

        function removeTrustStatus(publicKey) {
            logs.logEvent("contactsStore::removeTrustStatus", ["publicKey"], arguments)
        }

        function removeTrustVerificationStatus(publicKey) {
            logs.logEvent("contactsStore::removeTrustVerificationStatus", ["publicKey"], arguments)
        }

        function verifiedUntrustworthy(publicKey) {
            logs.logEvent("contactsStore::verifiedUntrustworthy", ["publicKey"], arguments)
        }

        function verifiedTrusted(publicKey) {
            logs.logEvent("contactsStore::verifiedTrusted", ["publicKey"], arguments)
            ctrlTrustStatus.currentIndex = ctrlTrustStatus.indexOfValue(Constants.trustStatus.trusted)
        }

        function cancelVerificationRequest(pubKey) {
            logs.logEvent("contactsStore::cancelVerificationRequest", ["pubKey"], arguments)
        }

        function getLinkToProfile(publicKey) {
            return Constants.userLinkPrefix + publicKey
        }

        function changeContactNickname(publicKey, newNickname, displayName, isEdit) {
            logs.logEvent("contactsStore::changeContactNickname", ["publicKey", "newNickname", "displayName", "isEdit"], arguments)
        }

        function requestProfileShowcase(publicKey) {
            logs.logEvent("contactsStore::requestProfileShowcase", ["publicKey"], arguments)
        }
    }

    SharedStores.NetworksStore {
        id: mockNetworksStore
    }

    Popups {
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: mockNetworksStore
        utilsStore: mockUtilsStore
        profileStore: mockProfileStore
        contactsStore: mockContactsStore
    }

    ListModel {
        id: linksModel
        ListElement {
            text: "__github"
            url: "https://github.com/caybro"
            showcaseVisibility: Constants.ShowcaseVisibility.Everyone
        }
        ListElement {
            text: "__twitter"
            url: "https://twitter.com/caybro"
            showcaseVisibility: Constants.ShowcaseVisibility.Everyone
        }
        ListElement {
            text: "__personal_site"
            url: "https://status.im"
            showcaseVisibility: Constants.ShowcaseVisibility.Everyone
        }
        ListElement {
            text: "__youtube"
            url: "https://www.youtube.com/@LukasTinkl"
            showcaseVisibility: Constants.ShowcaseVisibility.Everyone
        }
        ListElement {
            text: "__telegram"
            url: "https://t.me/ltinkl"
            showcaseVisibility: Constants.ShowcaseVisibility.Everyone
        }
    }

    ManageCollectiblesModel {
        id: manageCollectiblesModel
        Component.onCompleted: {
            for (let i = 0; i < this.count; i++) {
                setProperty(i, "showcaseVisibility", Constants.ShowcaseVisibility.Everyone)
            }
        }
    }

    WalletAccountsModel {
        id: walletAccountsModel
        Component.onCompleted: {
            for (let i = 0; i < this.count; i++) {
                setProperty(i, "showcaseVisibility", Constants.ShowcaseVisibility.Everyone)
            }
        }
    }

    CommunitiesModel {
        id: communitiesModel
        Component.onCompleted: {
            for (let i = 0; i < this.count; i++) {
                setProperty(i, "showcaseVisibility", Constants.ShowcaseVisibility.Everyone)
            }
        }
    }

    Logs { id: logs }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            ScrollView {
                width: parent.width
                height: parent.height
                clip: true

                Loader {
                    active: root.globalUtilsReady && root.globalCommunitiesModuleInstReady
                    width: parent.availableWidth
                    height: parent.availableHeight

                    sourceComponent: ProfileDialogView {
                        implicitWidth: 640

                        contactDetails: ContactDetails {
                            publicKey: "0xdeadbeef"

                            displayName: displayNameTextField.text
                            localNickname: localNicknameTextField.text
                            ensVerified: ensVerifiedCheckBox.checked
                            ensName: ensNameTextField.text
                            name: ensNameTextField.text

                            isCurrentUser: ownProfileSwitch.checked
                            isContact: ctrlIsContact.checked
                            contactRequestState: ctrlContactRequestState.currentValue

                            largeImage: userImageCheckBox.checked ? Assets.png("status-logo") : ""

                            onlineStatus: onlineStatusComboBox.currentValue

                            trustStatus: ctrlTrustStatus.currentValue
                            isVerified: ctrlTrustStatus.currentValue === Constants.trustStatus.trusted
                            isUntrustworthy: ctrlTrustStatus.currentValue === Constants.trustStatus.untrustworthy
                            isBlocked: isBlockedCheckBox.checked

                            colorId: colorIdSpinBox.value

                            bio: ctrlBio.text
                        }

                        readOnly: ctrlReadOnly.checked

                        onCloseRequested: logs.logEvent("closeRequested()")

                        sendToAccountEnabled: true

                        showcaseCommunitiesModel: communitiesModel
                        showcaseAccountsModel: walletAccountsModel
                        showcaseCollectiblesModel: manageCollectiblesModel
                        showcaseSocialLinksModel: linksModel
                        // TODO: showcaseAssetsModel

                        assetsModel: AssetsModel {}
                        collectiblesModel: CollectiblesModel {}

                        profileStore: mockProfileStore

                        contactsStore: mockContactsStore

                        utilsStore: mockUtilsStore
                        networksStore: mockNetworksStore
                        walletStore: WalletStores.RootStore
                    }
                }
            }
        }

        LogsAndControlsPanel {
            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 350

            logsView.logText: logs.logText

            ColumnLayout {
                width: parent.width
                RowLayout {
                    Layout.fillWidth: true
                    Switch {
                        id: ownProfileSwitch

                        text: "Own profile"
                        checked: false
                    }
                    Switch {
                        id: ctrlReadOnly

                        text: "Readonly (preview)"
                        visible: ownProfileSwitch.checked
                        checked: false
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "localNickname:" }

                    TextField {
                        Layout.preferredWidth: 100
                        id: localNicknameTextField

                        text: "Alex"
                        placeholderText: "Local Nickname"
                    }

                    Label {
                        text: "displayName:"
                    }

                    TextField {
                        Layout.preferredWidth: 100
                        id: displayNameTextField

                        text: "Alex Pella"
                        placeholderText: "Display Name"
                    }

                    CheckBox {
                        id: ensVerifiedCheckBox

                        checked: true
                        text: "ensVerified"
                    }

                    Label {
                        text: "name:"
                    }

                    TextField {
                        Layout.preferredWidth: 100
                        id: ensNameTextField

                        enabled: ensVerifiedCheckBox.checked
                        text: ensVerifiedCheckBox.checked ? "8⃣6⃣.eth" : ""
                        placeholderText: "ENS name"
                    }
                }
                RowLayout {
                    CheckBox {
                        id: userImageCheckBox

                        text: "User image"
                        checked: true
                    }
                    Label {
                        font.italic: true
                        text: "or"
                    }
                    Label {
                        enabled: !userImageCheckBox.checked

                        text: "colorId"
                    }
                    SpinBox {
                        id: colorIdSpinBox

                        enabled: !userImageCheckBox.checked
                        from: 0
                        to: 11 // Theme.palette.userCustomizationColors.length
                    }

                    Label {
                        text: "onlineStatus"
                    }

                    ComboBox {
                        id: onlineStatusComboBox

                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { value: Constants.onlineStatus.unknown, text: "unknown" },
                            { value: Constants.onlineStatus.inactive, text: "inactive" },
                            { value: Constants.onlineStatus.online, text: "online" }
                        ]
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    enabled: !ownProfileSwitch.checked

                    CheckBox {
                        id: ctrlIsContact

                        enabled: true
                        checked: ctrlContactRequestState.currentValue === Constants.ContactRequestState.Mutual
                        text: "isContact"
                    }

                    ComboBox {
                        id: ctrlContactRequestState

                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { value: Constants.ContactRequestState.None, text: "None" },
                            { value: Constants.ContactRequestState.Mutual, text: "Mutual" },
                            { value: Constants.ContactRequestState.Sent, text: "Sent" },
                            { value: Constants.ContactRequestState.Received, text: "Received" },
                            { value: Constants.ContactRequestState.Dismissed, text: "Dismissed" }
                        ]
                    }

                    Label {
                        text: "trustStatus:"
                    }

                    ComboBox {
                        id: ctrlTrustStatus

                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { value: Constants.trustStatus.unknown, text: "unknown" },
                            { value: Constants.trustStatus.trusted, text: "trusted" },
                            { value: Constants.trustStatus.untrustworthy, text: "untrustworthy" }
                        ]
                    }

                    CheckBox {
                        id: isBlockedCheckBox

                        text: "isBlocked"
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Bio:" }
                    TextField {
                        Layout.fillWidth: true
                        id: ctrlBio
                        selectByMouse: true
                        text: "


Hi, I am Alex. I'm an indie developer who mainly works on web products.



I worked for several different companies and created a couple of my own products from scratch. Currently building Telescope and Prepacked.

Say hi, or find me on Twitter, GitHub, or Mastodon.



"
                    }
                }
            }
        }
    }
}

// category: Views

// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=733%3A12552
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=682%3A15078
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=682%3A17655
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=682%3A17087
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=4%3A23525
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=4%3A23932
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=4%3A23932&t=h8DUW6Eysawqe5u0-0
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=724%3A15511&t=h8DUW6Eysawqe5u0-0
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=6%3A16845&t=h8DUW6Eysawqe5u0-0
// https://www.figma.com/file/ibJOTPlNtIxESwS96vJb06/%F0%9F%91%A4-Profile-%7C-Desktop?node-id=4%3A25437&t=h8DUW6Eysawqe5u0-0

// status: good
