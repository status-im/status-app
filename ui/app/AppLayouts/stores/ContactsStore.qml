import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils
import AppLayouts.Profile.helpers

import utils

QtObject {
    id: root

    signal contactInfoRequestFinished(string publicKey, bool ok)

    readonly property QtObject _d: QtObject {
        id: d

        readonly property var contactsModuleInst: profileSectionModule.contactsModule
        readonly property var mainModuleInst: mainModule
        readonly property var globalUtilsInst: globalUtils
        readonly property var communitiesModuleInst: communitiesModule


        Component.onCompleted: {
            mainModuleInst.resolvedENS.connect(root.resolvedENS)
            contactsModuleInst.trustStatusRemoved.connect(root.trustStatusRemoved)
            contactsModuleInst.contactRemoved.connect(root.contactRemoved)
            contactsModuleInst.contactInfoRequestFinished.connect(root.contactInfoRequestFinished)
        }
    }

    readonly property string myPublicKey: userProfile.pubKey

    // contactsModel holds all available contacts
    readonly property var contactsModel: d.contactsModuleInst.contactsModel

    readonly property var showcasePublicKey: d.contactsModuleInst.showcasePublicKey

    // Showcase models for a contact with showcasePublicKey
    readonly property var showcaseContactCommunitiesModel: d.contactsModuleInst.showcaseContactCommunitiesModel
    readonly property var showcaseContactAccountsModel: d.contactsModuleInst.showcaseContactAccountsModel
    readonly property var showcaseContactCollectiblesModel: d.contactsModuleInst.showcaseContactCollectiblesModel
    readonly property var showcaseContactAssetsModel: d.contactsModuleInst.showcaseContactAssetsModel
    readonly property var showcaseContactSocialLinksModel: d.contactsModuleInst.showcaseContactSocialLinksModel

    readonly property bool isShowcaseForAContactLoading: d.contactsModuleInst.showcaseForAContactLoading

    // Support models for showcase for a contact with showcasePublicKey
    readonly property var showcaseCollectiblesModel: d.contactsModuleInst.showcaseCollectiblesModel

    // Adapted contacts showcase models (TODO: Review if the store is the proper place. Should it be in an intermediate
    // layer in between of store and the corresponding views?)
    readonly property alias contactShowcaseCommunitiesModel: contactShowcaseModels.adaptedCommunitiesSourceModel
    readonly property alias contactShowcaseAccountsModel: contactShowcaseModels.adaptedAccountsSourceModel
    readonly property alias contactShowcaseCollectiblesModel: contactShowcaseModels.adaptedCollectiblesSourceModel
    readonly property alias contactShowcaseSocialLinksModel: contactShowcaseModels.adaptedSocialLinksSourceModel

    readonly property SQUtils.QObject adaptors: SQUtils.QObject {
        ProfileShowcaseModelAdapter {
            id: contactShowcaseModels
            communitiesSourceModel: d.communitiesModuleInst.model
            communitiesShowcaseModel: root.showcaseContactCommunitiesModel
            accountsSourceModel: root.showcaseContactAccountsModel
            collectiblesSourceModel: root.showcaseCollectiblesModel
            collectiblesShowcaseModel: root.showcaseContactCollectiblesModel
            socialLinksSourceModel: root.showcaseContactSocialLinksModel

            isAddressSaved: (address) => {
                return false
            }
            isShowcaseLoading: root.isShowcaseForAContactLoading
        }
    }

    signal resolvedENS(string resolvedPubKey, string resolvedAddress, string uuid)
    signal trustStatusRemoved(string pubKey)
    signal contactRemoved(string displayName, bool theyRemovedUs)

    // Sets showcasePublicKey and updates showcase models with corresponding data
    function requestContactShowcase(publicKey) {
        d.contactsModuleInst.requestProfileShowcase(publicKey)
    }

    // Temporary commented until we provide appropriate flags on the `status-go` side to cover all sections.
//    property var receivedButRejectedContactRequestsModel: contactsModule.receivedButRejectedContactRequestsModel
//    property var sentButRejectedContactRequestsModel: contactsModule.sentButRejectedContactRequestsModel

    function resolveENS(value) {
        d.mainModuleInst.resolveENS(value, "")
    }

    function joinPrivateChat(pubKey) {
        Global.changeAppSectionBySectionType(Constants.appSection.chat)
        d.contactsModuleInst.switchToOrCreateOneToOneChat(pubKey)
    }

    function unblockContact(pubKey) {
        d.contactsModuleInst.unblockContact(pubKey)
    }

    function blockContact(pubKey) {
        d.contactsModuleInst.blockContact(pubKey)
    }

    function removeContact(pubKey) {
        d.contactsModuleInst.removeContact(pubKey)
    }

    function changeContactNickname(pubKey, nickname, displayName, isEdit) {
        d.contactsModuleInst.changeContactNickname(pubKey, nickname)

        let message = ""
        if (nickname === "") { // removed nickname
            message = qsTr("Nickname for %1 removed").arg(displayName)
        } else {
            if (isEdit)
                message = qsTr("Nickname for %1 changed").arg(displayName) // changed nickname
            else
                message = qsTr("Nickname for %1 added").arg(displayName) // added a new nickname
        }
        if (!!message) {
            Global.displaySuccessToastMessage(message)
        }
    }

    function sendContactRequest(pubKey, message) {
        d.contactsModuleInst.sendContactRequest(pubKey, message)
        Global.displaySuccessToastMessage(qsTr("Contact request sent"))
    }

    function acceptContactRequest(pubKey, contactRequestId) {
        d.contactsModuleInst.acceptContactRequest(pubKey, contactRequestId)
    }

    function dismissContactRequest(pubKey, contactRequestId) {
        d.contactsModuleInst.dismissContactRequest(pubKey, contactRequestId)
    }

    function getLatestContactRequestForContactAsJson(pubKey) {
        let resp = d.contactsModuleInst.getLatestContactRequestForContactAsJson(pubKey)
        return JSON.parse(resp)
    }

    function markAsTrusted(pubKey) {
        d.contactsModuleInst.markAsTrusted(pubKey)
    }

    function markUntrustworthy(pubKey) {
        d.contactsModuleInst.markUntrustworthy(pubKey)
    }

    function removeTrustStatus(pubKey) {
        d.contactsModuleInst.removeTrustStatus(pubKey)
    }

    function requestContactInfo(publicKey) {
        d.contactsModuleInst.requestContactInfo(publicKey)
    }

    function getContactPublicKeyByAddress(address) {
        return "" // TODO retrive contact public key from address
    }

    function getLinkToProfile(publicKey) {
        return d.contactsModuleInst.shareUserUrlWithData(publicKey)
    }

    function populateContactDetails(publicKey) {
        return d.contactsModuleInst.populateContactDetails(publicKey)
    }
}
