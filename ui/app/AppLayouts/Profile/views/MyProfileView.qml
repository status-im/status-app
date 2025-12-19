import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import utils
import shared
import shared.panels
import shared.popups
import shared.stores as SharedStores
import shared.validators
import shared.controls.chat

import "../popups"
import "../controls"
import "./profile"

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Controls

import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Profile.helpers
import AppLayouts.Profile.panels
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores as AppLayoutStores

SettingsContentBase {
    id: root

    property ProfileStores.ProfileStore profileStore
    property AppLayoutStores.ContactsStore contactsStore
    property CommunitiesStores.CommunitiesStore communitiesStore
    property SharedStores.UtilsStore utilsStore
    required property SharedStores.NetworksStore networksStore

    property bool sendToAccountEnabled: false

    property alias communitiesShowcaseModel: showcaseModels.communitiesSourceModel
    property alias accountsShowcaseModel: showcaseModels.accountsSourceModel
    property alias collectiblesShowcaseModel: showcaseModels.collectiblesSourceModel
    property alias socialLinksShowcaseModel: showcaseModels.socialLinksSourceModel

    property var assetsModel
    property var collectiblesModel

    property bool sideBySidePreview
    property bool toastClashesWithDirtyBubble
    readonly property alias sideBySidePreviewComponent: myProfilePreviewComponent

    enum TabIndex {
        Identity = 0,
        Communities = 1,
        Accounts = 2,
        Collectibles = 3,
        //Assets = 4,
        Web = 4
    }

    titleRowComponentLoader.sourceComponent: StatusButton {
        text: qsTr("Preview")
        onClicked: Global.openPopup(profilePreview)
        visible: !root.sideBySidePreview
    }

    dirty: priv.isIdentityTabDirty ||
           priv.hasAnyProfileShowcaseChanges
    saveChangesButtonEnabled: !!descriptionPanel.displayName.text && descriptionPanel.displayName.valid && (descriptionPanel.bio.valid || descriptionPanel.bio.text === '')

    toast.saveChangesTooltipText: saveChangesButtonEnabled ? "" : qsTr("Invalid changes made to Identity")
    autoscrollWhenDirty: profileTabBar.currentIndex === MyProfileView.Identity
    toast.loading: priv.expectedBackendResponses > 0
    toast.additionalComponent.visible: false // TODO:Issue #13997 // !toast.loading && root.toastClashesWithDirtyBubble && priv.saveRequestFailed
    toast.additionalComponent.text: qsTr("Changes could not be saved. Try again")
    toast.additionalComponent.color: Theme.palette.dangerColor1

    onResetChangesClicked: priv.reset()

    onSaveChangesClicked: priv.save()

    bottomHeaderComponents: StatusTabBar {
        id: profileTabBar

        StatusTabButton {
            objectName: "identityTabButton"
            width: implicitWidth
            text: qsTr("Identity")
        }

        StatusTabButton {
            objectName: "communitiesTabButton"
            width: implicitWidth
            text: qsTr("Communities")
        }

        StatusTabButton {
            objectName: "accountsTabButton"
            width: implicitWidth
            text: qsTr("Accounts")
        }

        StatusTabButton {
            objectName: "collectiblesTabButton"
            width: implicitWidth
            text: qsTr("Collectibles")
        }

        StatusTabButton {
            objectName: "webTabButton"
            width: implicitWidth
            text: qsTr("Web")
        }
    }

    onVisibleChanged: if (visible) profileStore.requestProfileShowcasePreferences()
    Component.onCompleted: profileStore.requestProfileShowcasePreferences()

    property QObject priv: QObject {
        id: priv

        readonly property ContactDetails liveContactDetails: ContactDetails {
            publicKey: root.profileStore.pubKey
            compressedPubKey: root.profileStore.compressedPubKey
            colorId: root.profileStore.colorId
            onlineStatus: root.profileStore.currentUserStatus
            isCurrentUser: true
            displayName: descriptionPanel.displayName.text || root.profileStore.name
            bio: descriptionPanel.bio.text
            largeImage: profileHeader.previewIcon
        }

        readonly property bool hasAnyProfileShowcaseChanges: showcaseModels.dirty
        readonly property bool isIdentityTabDirty: (!descriptionPanel.isEnsName &&
                                                    descriptionPanel.displayName.text !== profileStore.displayName) ||
                                                   descriptionPanel.bio.text !== profileStore.bio ||
                                                   profileStore.socialLinksDirty ||
                                                   profileHeader.icon !== profileStore.profileLargeImage

        property ProfileShowcaseModels showcaseModels: ProfileShowcaseModels {
            id: showcaseModels
        }

        // Used to track which are the expected backend responses (they can be 0, 1 or 2) depending on the dirty changes
        property int expectedBackendResponses: 0
        property bool saveRequestFailed: false

        // Maximum save action waiting time controller.
        // Backend response must be received before, otherwise it will be considered
        // a failure and UI will be released.
        property Timer saveLoadingTimeout : Timer {
            interval: 5000
            repeat: false
            running: toast.active && toast.loading

            onTriggered: {
                // Forcing a failure
                if(priv.expectedBackendResponses > 0) {
                    root.profileStore.profileSettingsSaveFailed()
                    priv.expectedBackendResponses = 0
                }
            }
        }

        // Save backend response received:
        property Connections profileStoreConnection: Connections {
            target: root.profileStore

            function onProfileIdentitySaveSucceeded() {
                priv.checkSaveResult(false)
            }

            function onProfileIdentitySaveFailed() {
                priv.checkSaveResult(true)
            }

            function onProfileShowcasePreferencesSaveSucceeded() {
                priv.checkSaveResult(false)
            }

            function onProfileShowcasePreferencesSaveFailed() {
                priv.checkSaveResult(true)
            }
        }

        function checkSaveResult(isFailure) {
            priv.expectedBackendResponses--
            if(isFailure)
                priv.saveRequestFailed = isFailure

            if(priv.expectedBackendResponses == 0) {
                if(priv.saveRequestFailed || isFailure) {
                    root.profileStore.profileSettingsSaveFailed()
                } else {
                    root.profileStore.profileSettingsSaveSucceeded()
                }
            }
        }

        function reset() {
            descriptionPanel.displayName.text = Qt.binding(() => { return profileStore.displayName })
            descriptionPanel.bio.text = Qt.binding(() => { return profileStore.bio })
            profileHeader.icon = Qt.binding(() => { return profileStore.profileLargeImage })

            priv.showcaseModels.revert()
            priv.saveRequestFailed = false
            priv.expectedBackendResponses = 0
            root.profileStore.requestProfileShowcasePreferences()
        }

        function save() {
            // IMPORTANT: Save implies 2 calls in backend but 1 result in UI so the order in current save method is relevant
            // First save stage: Review which are the expected responses before calling backend
            priv.expectedBackendResponses = 0
            priv.saveRequestFailed = false
            if(hasAnyProfileShowcaseChanges) {
                priv.expectedBackendResponses++
            }
            if (isIdentityTabDirty ) {
                priv.expectedBackendResponses++
            }

            // Second save stage: Ready to call backend
            if(priv.expectedBackendResponses > 0) {
                // Accounts, Communities, Assets, Collectibles and social links info
                if (hasAnyProfileShowcaseChanges) {
                    root.profileStore.saveProfileShowcasePreferences(showcaseModels.buildJSONModelsCurrentState())
                }

                // Identity info. Update only those fields that have changed
                if (isIdentityTabDirty) {
                    const imageChanged = profileHeader.icon !== profileStore.profileLargeImage
                    const displayNameChanged = descriptionPanel.displayName.text !== profileStore.displayName
                    const bioChanged = descriptionPanel.bio.text.trim() !== profileStore.bio.trim()

                    root.profileStore.saveProfileIdentityChanges(
                                displayNameChanged ? descriptionPanel.displayName.text : undefined,
                                bioChanged ? descriptionPanel.bio.text.trim() : undefined,
                                imageChanged ? {
                                       source : profileHeader.icon,
                                       aX: profileHeader.cropRect.x,
                                       aY: profileHeader.cropRect.y,
                                       bX: profileHeader.cropRect.x + profileHeader.cropRect.width,
                                       bY: profileHeader.cropRect.y + profileHeader.cropRect.height
                                   } : undefined
                                )
                    profileHeader.icon = Qt.binding(() => { return profileStore.profileLargeImage })
                }
            }
        }
    }

    Settings {
        id: appMainLocalSettings
        category: "AppMainLocalSettings_%1".arg(root.profileStore.pubKey)
        property bool isFirstShowcaseInteraction: true
    }

    StackLayout {
        id: stackLayout

        width: root.contentWidth
        height: profileTabBar.currentIndex === MyProfileView.Web ? implicitHeight : root.contentHeight
        currentIndex: profileTabBar.currentIndex

        onCurrentIndexChanged: {
            if(appMainLocalSettings.isFirstShowcaseInteraction && currentIndex !== MyProfileView.TabIndex.Identity) {
                appMainLocalSettings.isFirstShowcaseInteraction = false
                Global.openPopup(profileShowcaseInfoPopup)
            }
        }

        // identity
        ColumnLayout {
            objectName: "myProfileSettingsView"
            ProfileHeader {
                id: profileHeader
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding

                displayName: profileStore.name
                usesDefaultName: profileStore.usesDefaultName
                icon: profileStore.profileLargeImage
                imageSize: ProfileHeader.ImageSize.Big

                displayNameVisible: false
                pubkeyVisible: false
                emojiHashVisible: false
                editImageButtonVisible: true
                colorId: root.profileStore.colorId
            }

            ProfileDescriptionPanel {
                id: descriptionPanel

                readonly property bool isEnsName: profileStore.preferredName

                Layout.fillWidth: true

                displayName.focus: !isEnsName && !Utils.isMobile
                displayName.input.edit.readOnly: isEnsName
                displayName.text: profileStore.displayName
                displayName.validationMode: StatusInput.ValidationMode.Always
                displayName.validators: isEnsName || (profileStore.displayName === displayName.text) ? [] : displayNameValidators.validators
                bio.text: profileStore.bio

                DisplayNameValidators {
                    id: displayNameValidators

                    utilsStore: root.utilsStore
                    myDisplayName: root.profileStore.name
                    communitiesStore: root.communitiesStore
                }
            }
        }

        // communities
        ProfileShowcaseCommunitiesPanel {
            id: profileShowcaseCommunitiesPanel
            inShowcaseModel: priv.showcaseModels.communitiesVisibleModel
            hiddenModel: priv.showcaseModels.communitiesHiddenModel
            showcaseLimit: root.profileStore.getProfileShowcaseEntriesLimit()

            onChangePositionRequested: function (from, to) {
                priv.showcaseModels.changeCommunityPosition(from, to)
            }
            onSetVisibilityRequested: function (key, toVisibility) {
                priv.showcaseModels.setCommunityVisibility(key, toVisibility)
            }
        }

        // accounts
        ProfileShowcaseAccountsPanel {
            id: profileShowcaseAccountsPanel
            inShowcaseModel: priv.showcaseModels.accountsVisibleModel
            hiddenModel: priv.showcaseModels.accountsHiddenModel
            showcaseLimit: root.profileStore.getProfileShowcaseEntriesLimit()
            currentWallet: WalletStores.RootStore.overview.mixedcaseAddress

            onChangePositionRequested: function (from, to) {
                priv.showcaseModels.changeAccountPosition(from, to)

            }
            onSetVisibilityRequested: function (key, toVisibility) {
                priv.showcaseModels.setAccountVisibility(key, toVisibility)
            }
        }

        // collectibles
        ProfileShowcaseCollectiblesPanel {
            id: profileShowcaseCollectiblesPanel
            inShowcaseModel: priv.showcaseModels.collectiblesVisibleModel
            hiddenModel: priv.showcaseModels.collectiblesHiddenModel
            showcaseLimit: root.profileStore.getProfileShowcaseEntriesLimit()
            addAccountsButtonVisible: priv.showcaseModels.accountsHiddenModel.count > 0

            onNavigateToAccountsTab: profileTabBar.currentIndex = MyProfileView.TabIndex.Accounts

            onChangePositionRequested: function (from, to) {
                priv.showcaseModels.changeCollectiblePosition(from, to)
            }

            onSetVisibilityRequested: function (key, toVisibility) {
                priv.showcaseModels.setCollectibleVisibility(key, toVisibility)
            }
        }

        // web
        ProfileSocialLinksPanel {
            showcaseLimit: root.profileStore.getProfileShowcaseSocialLinksLimit()
            socialLinksModel: priv.showcaseModels.socialLinksVisibleModel

            onAddSocialLink: function(url, text) {
                priv.showcaseModels.appendSocialLink({ showcaseKey: "", text: text, url: url })
            }

            onUpdateSocialLink: function(index, url, text) {
                priv.showcaseModels.updateSocialLink(index, { text: text, url: url })
            }

            onRemoveSocialLink: function(index) {
                priv.showcaseModels.removeSocialLink(index)
            }

            onChangePosition: function(from, to) {
                priv.showcaseModels.changeSocialLinkPosition(from, to)
            }
        }

        Component {
            id: profilePreview

            ProfileDialog {
                contactDetails: priv.liveContactDetails

                profileStore: root.profileStore
                contactsStore: root.contactsStore
                walletStore: WalletStores.RootStore
                utilsStore: root.utilsStore
                networksStore: root.networksStore
                sendToAccountEnabled: root.sendToAccountEnabled
                onClosed: destroy()

                showcaseCommunitiesModel: priv.showcaseModels.communitiesVisibleModel
                showcaseAccountsModel: priv.showcaseModels.accountsVisibleModel
                showcaseCollectiblesModel: priv.showcaseModels.collectiblesVisibleModel
                showcaseSocialLinksModel: priv.showcaseModels.socialLinksVisibleModel

                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel
            }
        }

        Component {
            id: myProfilePreviewComponent

            MyProfilePreview {
                contactDetails: priv.liveContactDetails

                profileStore: root.profileStore
                contactsStore: root.contactsStore
                utilsStore: root.utilsStore
                networksStore: root.networksStore
                sendToAccountEnabled: root.sendToAccountEnabled

                showcaseCommunitiesModel: priv.showcaseModels.communitiesVisibleModel
                showcaseAccountsModel: priv.showcaseModels.accountsVisibleModel
                showcaseCollectiblesModel: priv.showcaseModels.collectiblesVisibleModel
                showcaseSocialLinksModel: priv.showcaseModels.socialLinksVisibleModel

                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel
            }
        }

        Component {
            id: profileShowcaseInfoPopup

            ProfileShowcaseInfoPopup {
                destroyOnClose: true
            }
        }
    }
}
