import QtQuick
import QtQml

import StatusQ.Core.Utils

import AppLayouts.Profile.helpers

import utils

import SortFilterProxyModel

QtObject {
    id: root

    property var profileModule
    property var sectionsModel

    property string pubKey: userProfile.pubKey
    property string compressedPubKey: userProfile.compressedPubKey
    property string name: userProfile.name
    property string username: userProfile.username
    property string displayName: userProfile.displayName
    property bool usesDefaultName: userProfile.usesDefaultName
    property string preferredName: userProfile.preferredName
    property string profileLargeImage: userProfile.largeImage
    property string icon: userProfile.icon
    readonly property bool userDeclinedBackupBanner: Global.appIsReady? localAccountSensitiveSettings.userDeclinedBackupBanner : false
    readonly property string keyUid: userProfile.keyUid
    readonly property bool migratedToColdWallet: userProfile.migratedToColdWallet
    readonly property int currentUserStatus: userProfile.currentUserStatus
    readonly property var thumbnailImage: userProfile.thumbnailImage
    readonly property var largeImage: userProfile.largeImage
    readonly property int colorId: Utils.colorIdForPubkey(root.pubKey)

    readonly property string bio: profileModule.bio
    readonly property string socialLinksJson: profileModule.socialLinksJson
    readonly property var socialLinksModel: profileModule.socialLinksModel
    readonly property var temporarySocialLinksModel: profileModule.temporarySocialLinksModel // for editing purposes
    readonly property var temporarySocialLinksJson: profileModule.temporarySocialLinksJson
    readonly property bool socialLinksDirty: profileModule.socialLinksDirty


    readonly property var showcasePreferencesCommunitiesModel: profileModule.showcasePreferencesCommunitiesModel
    readonly property var showcasePreferencesAccountsModel: profileModule.showcasePreferencesAccountsModel
    readonly property var showcasePreferencesCollectiblesModel: profileModule.showcasePreferencesCollectiblesModel
    readonly property var showcasePreferencesAssetsModel: profileModule.showcasePreferencesAssetsModel
    readonly property var showcasePreferencesSocialLinksModel: profileModule.showcasePreferencesSocialLinksModel

    readonly property alias ownShowcaseCommunitiesModel: ownShowcaseModels.adaptedCommunitiesSourceModel
    readonly property alias ownShowcaseAccountsModel: ownShowcaseModels.adaptedAccountsSourceModel
    readonly property alias ownShowcaseCollectiblesModel: ownShowcaseModels.adaptedCollectiblesSourceModel
    readonly property alias ownShowcaseSocialLinksModel: ownShowcaseModels.adaptedSocialLinksSourceModel

    property var ownAccounts
    property var collectibles

    // TODO: Review if this model shoud come from `CommunitiesStore` or in a more appropriate domain
    readonly property var communitiesList: SortFilterProxyModel {
        sourceModel: root.sectionsModel
        filters: ValueFilter {
            roleName: "sectionType"
            value: Constants.appSection.community
        }
    }

    // The following signals wrap the settings / preferences save request responses in one unique result (identity + preferences result)
    signal profileSettingsSaveSucceeded()
    signal profileSettingsSaveFailed()

    // The following signals describe separate save request responses between identity and preferences
    signal profileIdentitySaveSucceeded()
    signal profileIdentitySaveFailed()
    signal profileShowcasePreferencesSaveSucceeded()
    signal profileShowcasePreferencesSaveFailed()

    readonly property QObject d: QObject {
        ProfileShowcaseSettingsModelAdapter {
            id: ownShowcaseModels
            communitiesSourceModel: root.communitiesList
            communitiesShowcaseModel: root.showcasePreferencesCommunitiesModel
            accountsSourceModel: root.ownAccounts
            accountsShowcaseModel: root.showcasePreferencesAccountsModel
            collectiblesSourceModel: root.collectibles
            collectiblesShowcaseModel: root.showcasePreferencesCollectiblesModel
            socialLinksSourceModel: root.showcasePreferencesSocialLinksModel
        }
    }

    readonly property Connections profileModuleConnections: Connections {
        target: root.profileModule

        function onProfileIdentitySaveSucceeded() {
            root.profileIdentitySaveSucceeded()
        }

        function onProfileIdentitySaveFailed() {
            root.profileIdentitySaveFailed()
        }

        function onProfileShowcasePreferencesSaveSucceeded() {
            root.profileShowcasePreferencesSaveSucceeded()
        }

        function onProfileShowcasePreferencesSaveFailed() {
            root.profileShowcasePreferencesSaveFailed()
        }
    }

    function getQrCodeSource(text) {
        return globalUtils.qrCode(text)
    }

    function saveProfileIdentityChanges(displayName, bio, imageInfo) {
        const changes = Object.assign({},
                                      displayName !== undefined && { displayName },
                                      bio !== undefined && { bio },
                                      imageInfo !== undefined && { image: imageInfo })

        const json = JSON.stringify(changes)
        root.profileModule.saveProfileIdentityChanges(json)
    }

    function getProfileShowcaseEntriesLimit() {
        return root.profileModule.getProfileShowcaseEntriesLimit()
    }

    function getProfileShowcaseSocialLinksLimit() {
        return root.profileModule.getProfileShowcaseSocialLinksLimit()
    }

    function saveProfileShowcasePreferences(json) {
        root.profileModule.saveProfileShowcasePreferences(json)
    }

    function requestProfileShowcasePreferences() {
        root.profileModule.requestProfileShowcasePreferences()
    }

    function setUserDeclinedBackupBanner(value = true) {
        localAccountSensitiveSettings.userDeclinedBackupBanner = value
    }
}
