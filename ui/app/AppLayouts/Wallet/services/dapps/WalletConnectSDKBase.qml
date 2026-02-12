import QtQuick

/// Abstract base for WC/BC SDK implementations (ConnectorWCSDK, DappsConnectorSDK)
Item {
    required property string projectId
    property bool enabled: true

    signal statusChanged(string message)
    signal sdkInit(bool success, var result)
    signal pairResponse(bool success, string error)
    signal sessionProposal(var sessionProposal)
    signal sessionProposalExpired()
    signal buildApprovedNamespacesResult(string id, var session, string error)
    signal approveSessionResult(string proposalId, var approvedNamespaces, string error)
    signal rejectSessionResult(string proposalId, string error)
    signal sessionRequestExpired(string id)
    signal sessionRequestEvent(var sessionRequest)
    signal sessionRequestUserAnswerResult(string topic, string id, bool accept /* not reject */, string error)
    signal sessionAuthenticateRequest(var sessionData)
    signal populateAuthPayloadResult(string id, var authPayload, string error)
    signal formatAuthMessageResult(string id, var request, string error)
    signal acceptSessionAuthenticateResult(string id, var result, string error)
    signal rejectSessionAuthenticateResult(string id, var result, string error)
    signal buildAuthObjectResult(string id, var authObject, string error)

    signal disconnected(string url, string error)

    property var pair: function(pairLink) {
        console.error("pair not implemented")
    }
    property var getPairings: function(callback) {
        console.error("getPairings not implemented")
    }
    property var getActiveSessions: function(callback) {
        console.error("getActiveSessions not implemented")
    }
    property var disconnect: function(url, clientId) {
        console.error("disconnect not implemented")
    }
    property var disconnectByTopic: function(topic, url) {
        console.error("disconnectByTopic not implemented")
    }
    property var disconnectPairing: function(topic) {
        console.error("disconnectPairing not implemented")
    }

    property var ping: function(topic) {
        console.error("ping not implemented")
    }

    property var buildApprovedNamespaces: function(id, params, supportedNamespaces) {
        console.error("buildApprovedNamespaces not implemented")
    }
    property var approveSession: function(sessionProposal, supportedNamespaces) {
        console.error("approveSession not implemented")
    }

    property var rejectSession: function(id) {
        console.error("rejectSession not implemented")
    }

    property var acceptSessionRequest: function(topic, id, signature) {
        console.error("acceptSessionRequest not implemented")
    }

    property var rejectSessionRequest: function(topic, id, error) {
        console.error("rejectSessionRequest not implemented")
    }

    property var populateAuthPayload: function (id, authPayload, chains, methods) {
        console.error("populateAuthPayload not implemented")
    }

    property var formatAuthMessage: function(id, request, iss) {
        console.error("formatAuthMessage not implemented")
    }

    property var buildAuthObject: function(id, authPayload, signature, iss) {
        console.error("buildAuthObject not implemented")
    }

    property var acceptSessionAuthenticate: function(id, auths) {
        console.error("acceptSessionAuthenticate not implemented")
    }

    property var rejectSessionAuthenticate: function(id, error) {
        console.error("rejectSessionAuthenticate not implemented")
    }

    property var emitSessionEvent: function(topic, event, chainId) {
        console.error("emitSessionEvent not implemented")
    }
}
