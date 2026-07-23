import QtQuick
import QtQml.Models

import utils

QtObject {
    id: root

    property var communitiesModuleInst: communitiesModule
    property var mainModuleInst: mainModule

    readonly property var curatedCommunitiesModel: root.communitiesModuleInst.curatedCommunities
    readonly property bool curatedCommunitiesLoading: root.communitiesModuleInst.curatedCommunitiesLoading

    property var discordFileList: root.communitiesModuleInst.discordFileList
    property var discordCategoriesModel: root.communitiesModuleInst.discordCategories
    property var discordChannelsModel: root.communitiesModuleInst.discordChannels
    property int discordOldestMessageTimestamp: root.communitiesModuleInst.discordOldestMessageTimestamp
    property bool discordDataExtractionInProgress: root.communitiesModuleInst.discordDataExtractionInProgress
    property int discordImportErrorsCount: root.communitiesModuleInst.discordImportErrorsCount
    property int discordImportWarningsCount: root.communitiesModuleInst.discordImportWarningsCount
    property int discordImportProgress: root.communitiesModuleInst.discordImportProgress
    property bool discordImportInProgress: root.communitiesModuleInst.discordImportInProgress
    property bool discordImportCancelled: root.communitiesModuleInst.discordImportCancelled
    property bool discordImportProgressStopped: root.communitiesModuleInst.discordImportProgressStopped
    property int discordImportProgressTotalChunksCount: root.communitiesModuleInst.discordImportProgressTotalChunksCount
    property int discordImportProgressCurrentChunk: root.communitiesModuleInst.discordImportProgressCurrentChunk
    property string discordImportCommunityId: root.communitiesModuleInst.discordImportCommunityId
    property string discordImportCommunityName: root.communitiesModuleInst.discordImportCommunityName
    property string discordImportChannelId: root.communitiesModuleInst.discordImportChannelId
    property string discordImportChannelName: root.communitiesModuleInst.discordImportChannelName
    property url discordImportCommunityImage: root.communitiesModuleInst.discordImportCommunityImage
    property bool discordImportHasCommunityImage: root.communitiesModuleInst.discordImportHasCommunityImage
    property var discordImportTasks: root.communitiesModuleInst.discordImportTasks
    property bool downloadingCommunityHistoryArchives: root.communitiesModuleInst.downloadingCommunityHistoryArchives
    property var advancedModule: profileSectionModule.advancedModule

    readonly property bool testEnvironment: localAppSettings.testEnvironment ?? false

    property string communityTags: communitiesModuleInst.tags

    // State used by the global deep-link loading overlay while a missing community
    // is being fetched from the network.
    readonly property int communityFetchStateIdle: 0
    readonly property int communityFetchStateFetching: 1
    readonly property int communityFetchStateFailed: 2
    readonly property int communityFetchState: d.communityFetchState
    readonly property bool communityFetchInProgress: d.communityFetchInProgress
    readonly property bool communityFetchFailed: d.communityFetchFailed
    readonly property string communityFetchId: d.communityFetchId
    readonly property string communityFetchChannelUuid: d.communityFetchChannelUuid
    // Guards against stale backend signals from previous fetch attempts.
    readonly property int communityFetchRequestId: d.communityFetchRequestId
    // Backend-provided timeout shown by the countdown UI.
    readonly property int communityFetchTimeoutSeconds: d.communityFetchTimeoutSeconds
    readonly property string communityFetchErrorMessage: d.communityFetchErrorMessage

    readonly property QtObject _d: QtObject {
        id: d
        readonly property var profileSectionModuleInst: profileSectionModule

        property int communityFetchState: root.communityFetchStateIdle
        readonly property bool communityFetchInProgress: communityFetchState === root.communityFetchStateFetching
        readonly property bool communityFetchFailed: communityFetchState === root.communityFetchStateFailed
        property string communityFetchId: ""
        property string communityFetchChannelUuid: ""
        property int communityFetchRequestId: -1
        property int communityFetchTimeoutSeconds: 0
        property string communityFetchErrorMessage: ""
    }
    readonly property var communitiesProfileModule: d.profileSectionModuleInst.communitiesModule // TODO: Must be private or directly removed (no direct access to modules externally)

    signal importingCommunityStateChanged(string communityId, int state, string errorMsg)

    signal communityInfoRequestCompleted(string communityId, string errorMsg)

    readonly property Connections _signingRequestConnections: Connections {
        target: root.communitiesModuleInst
        function onSigningRequested(keyUid, txHash, path, address) {
            Global.openSigningPopup(Constants.signingReason.communitiesSignSharedAddresses, keyUid, txHash, path, address)
        }
    }

    readonly property Connections _signingResultConnections: Connections {
        target: Global
        function onSigningResult(reason, signature, keyUid, path, address) {
            if (reason !== Constants.signingReason.communitiesSignSharedAddresses)
                return
            root.communitiesModuleInst.onSigningResult(signature, address)
        }
    }

    function createCommunity(args = {
                                name: "",
                                description: "",
                                introMessage: "",
                                outroMessage: "",
                                color: "",
                                tags: "",
                                image: {
                                    src: "",
                                    AX: 0,
                                    AY: 0,
                                    BX: 0,
                                    BY: 0,
                                },
                                options: {
                                    historyArchiveSupportEnabled: false,
                                    checkedMembership: false,
                                    pinMessagesAllowedForMembers: false,
                                    encrypted: false,
                                },
                                bannerJsonStr: ""
                             }) {
        return communitiesModuleInst.createCommunity(
                    args.name, args.description, args.introMessage, args.outroMessage, args.options.checkedMembership,
                    args.color, args.tags,
                    args.image.src, args.image.AX, args.image.AY, args.image.BX, args.image.BY,
                    args.options.historyArchiveSupportEnabled, args.options.pinMessagesAllowedForMembers,
                    args.bannerJsonStr, args.options.encrypted);
    }

    function getCommunityPublicKeyFromPrivateKey(privateKey) {
        return root.communitiesModuleInst.getCommunityPublicKeyFromPrivateKey(privateKey);
    }

    function requestCommunityInfo(communityPubKey, importing = false) {
        if (importing)
            root.mainModuleInst.setCommunityIdToSpectate(communityPubKey)
        root.communitiesModuleInst.requestCommunityInfo(communityPubKey, importing)
    }

    function cancelPendingCommunityFetch() {
        if(!root.mainModuleInst)
            return
        root.mainModuleInst.cancelPendingCommunityFetch()
    }

    function timeoutPendingCommunityFetch() {
        if(!root.mainModuleInst)
            return
        root.mainModuleInst.timeoutPendingCommunityFetch()
    }

    function retryCommunityFetch() {
        if(!root.mainModuleInst || !d.communityFetchId)
            return
        root.mainModuleInst.retryCommunityFetch(d.communityFetchId, d.communityFetchChannelUuid)
    }

    function clearCommunityFetchState() {
        d.communityFetchState = root.communityFetchStateIdle
        d.communityFetchErrorMessage = ""
        d.communityFetchId = ""
        d.communityFetchChannelUuid = ""
        d.communityFetchRequestId = -1
        d.communityFetchTimeoutSeconds = 0
    }

    function clearCommunityFetchFailure() {
        root.clearCommunityFetchState()
    }

    property var communitiesList: communitiesModuleInst.model

    function getCommunityDetails(communityPubKey) {
        try {
            const communityJson = root.communitiesList.getSectionByIdJson(communityPubKey)
            if (!!communityJson)
                return JSON.parse(communityJson)
        } catch (e) {
            console.error("Error parsing community", e)
        }
        return null
    }

    function getCommunityDetailsAsJson(communityId) {
        const jsonObj = root.communitiesModuleInst.getCommunityDetails(communityId)
        try {
            return JSON.parse(jsonObj)
        }
        catch (e) {
            console.warn("error parsing community by id: ", communityId, " error: ", e.message)
            return {}
        }
    }

    function setActiveCommunity(communityId) {
        root.mainModuleInst.setActiveSectionById(communityId);
    }

    function navigateToCommunity(communityId) {
        root.communitiesModuleInst.navigateToCommunity(communityId)
    }

    function removeFileListItem(filePath) {
        root.communitiesModuleInst.removeFileListItem(filePath)
    }

    function setFileListItems(filePaths) {
        root.communitiesModuleInst.setFileListItems(filePaths)
    }

    function clearFileList() {
        root.communitiesModuleInst.clearFileList()
    }

    function requestExtractChannelsAndCategories() {
        root.communitiesModuleInst.requestExtractDiscordChannelsAndCategories()
    }

    function clearDiscordCategoriesAndChannels() {
        root.communitiesModuleInst.clearDiscordCategoriesAndChannels()
    }

    function toggleDiscordCategory(id, selected) {
        root.communitiesModuleInst.toggleDiscordCategory(id, selected)
    }

    function toggleDiscordChannel(id, selected) {
        root.communitiesModuleInst.toggleDiscordChannel(id, selected)
    }

    function toggleOneDiscordChannel(id) {
        root.communitiesModuleInst.toggleOneDiscordChannel(id)
    }

    function requestCancelDiscordCommunityImport(id) {
        root.communitiesModuleInst.requestCancelDiscordCommunityImport(id)
    }

    function requestCancelDiscordChannelImport(id) {
        root.communitiesModuleInst.requestCancelDiscordChannelImport(id)
    }

    function resetImport() {
        root.communitiesModuleInst.resetImport()
    }

    function removeImportedDiscordChannel() {
        root.communitiesModuleInst.removeImportedDiscordChannel()
    }

    function resetDiscordImport() {
        root.communitiesModuleInst.resetDiscordImport(false)
    }

    function requestImportDiscordCommunity(args = {
                                name: "",
                                description: "",
                                introMessage: "",
                                outroMessage: "",
                                color: "",
                                tags: "",
                                image: {
                                    src: "",
                                    AX: 0,
                                    AY: 0,
                                    BX: 0,
                                    BY: 0,
                                },
                                options: {
                                    historyArchiveSupportEnabled: false,
                                    checkedMembership: false,
                                    pinMessagesAllowedForMembers: false,
                                }
                             }, from = 0) {
        return communitiesModuleInst.requestImportDiscordCommunity(
                    args.name, args.description, args.introMessage, args.outroMessage, args.options.checkedMembership,
                    args.color, args.tags,
                    args.image.src, args.image.AX, args.image.AY, args.image.BX, args.image.BY,
                    args.options.historyArchiveSupportEnabled, args.options.pinMessagesAllowedForMembers, from);
    }

    function requestImportDiscordChannel(args = {
                                         communityId: "",
                                         discordChannelId: "",
                                         name: "",
                                         description: "",
                                         color: "",
                                         emoji: "",
                                         options: {
                                             // TODO
                                         }
                                      }, from = 0) {
        communitiesModuleInst.requestImportDiscordChannel(args.name, args.discordChannelId, args.communityId,
                                                        args.description, args.color, args.emoji, from)
    }

    function isDisplayNameDupeOfCommunityMember(displayName) {
        if (displayName === "")
            return false

        return communitiesModuleInst.isDisplayNameDupeOfCommunityMember(displayName)
    }

    function leaveCommunity(communityId) {
        d.profileSectionModuleInst.communitiesModule.leaveCommunity(communityId)
    }

    function setCommunityMuted(communityId, mutedType) {
        d.profileSectionModuleInst.communitiesModule.setCommunityMuted(communityId, mutedType)
    }

    readonly property Connections connections: Connections {
        target: communitiesModuleInst
        function onImportingCommunityStateChanged(communityId, state, errorMsg) {
            root.importingCommunityStateChanged(communityId, state, errorMsg)
        }

        function onCommunityInfoRequestCompleted(communityId, erorrMsg) {
            root.communityInfoRequestCompleted(communityId, erorrMsg)
        }
    }

    readonly property Connections mainModuleConnections: Connections {
        target: root.mainModuleInst

        function onCommunityFetchStarted(communityId, channelUuid, requestId, timeoutSeconds) {
            d.communityFetchState = root.communityFetchStateFetching
            d.communityFetchId = communityId
            d.communityFetchChannelUuid = channelUuid
            d.communityFetchRequestId = requestId
            d.communityFetchTimeoutSeconds = timeoutSeconds
            d.communityFetchErrorMessage = ""
        }

        function onCommunityFetchCompleted(communityId, requestId) {
            if (requestId !== d.communityFetchRequestId)
                return
            root.clearCommunityFetchState()
        }

        function onCommunityFetchFailed(communityId, requestId, errorMsg) {
            if (requestId !== d.communityFetchRequestId)
                return
            d.communityFetchState = root.communityFetchStateFailed
            d.communityFetchId = communityId
            d.communityFetchErrorMessage = errorMsg
        }

        function onCommunityFetchCancelled(communityId, requestId) {
            if (requestId !== d.communityFetchRequestId)
                return
            root.clearCommunityFetchState()
        }
    }
}
