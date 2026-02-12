import QtQuick

import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types

import shared.stores
import utils

import "types"

/// WalletConnect SDK implementation using the connector service (Go relay client).
/// Replaces the WebEngine-based WalletConnectSDK for pairing and session management.
WalletConnectSDKBase {
    id: root

    required property var connectorController
    /// Required roles: chainId
    required property var networksModel
    /// Required roles: address
    required property var accountsModel

    projectId: ""
    readonly property bool sdkReady: true  // Connector-based, no async init

    QtObject {
        id: d
        readonly property var sessionRequests: new Map()

        function buildSessionFromWCSession(wcSession) {
            try {
                const session = typeof wcSession === "string" ? JSON.parse(wcSession) : wcSession
                const dapp = session.peer?.metadata || {}
                return {
                    peer: { metadata: dapp },
                    namespaces: session.namespaces || {},
                    pairingTopic: session.pairingTopic || "",
                    topic: session.topic || session.dappUrl || ""
                }
            } catch (e) {
                console.error("Failed to parse WC session", e)
                return null
            }
        }

        function buildSessionProposal(requestId, proposalJson) {
            try {
                const params = typeof proposalJson === "string" ? JSON.parse(proposalJson) : proposalJson
                return {
                    id: requestId,
                    params: params
                }
            } catch (e) {
                console.error("Failed to parse WC proposal", e)
                return null
            }
        }

        function buildSessionFromProposal(proposal, account, chains) {
            const meta = proposal?.params?.proposer?.metadata || {}
            const url = meta.url || ""
            const name = meta.name || ""
            const icon = (meta.icons && meta.icons[0]) || ""
            const eipAccount = account ? `eip155:${account}` : ""
            const eipChains = chains ? chains.map((c) => `eip155:${c}`) : []
            return {
                peer: { metadata: { description: "-", icons: [icon], name, url } },
                namespaces: { eip155: { accounts: [eipAccount], chains: eipChains } },
                pairingTopic: proposal.id?.toString() || "",
                topic: url
            }
        }
    }

    Connections {
        target: root.connectorController
        enabled: root.enabled && !!root.connectorController

        function onWcSessionProposal(requestId, uri, proposal) {
            const proposalObj = d.buildSessionProposal(requestId, proposal)
            if (!proposalObj) {
                console.error("[WC QML] ConnectorWCSDK.onWcSessionProposal buildSessionProposal failed")
                return
            }
            d.sessionRequests.set(requestId, { proposal: proposalObj, uri })
            root.sessionProposal(proposalObj)
        }

        function onWcSessionRequest(topic, requestId, requestJson) {
            try {
                const params = typeof requestJson === "string" ? JSON.parse(requestJson) : requestJson
                const reqId = typeof requestId === "string" ? requestId : String(requestId)
                const event = {
                    id: requestId,
                    params: params,
                    topic: topic,
                    verifyContext: {}
                }
                d.sessionRequests.set(reqId, event)
                root.sessionRequestEvent(event)
            } catch (e) {
                console.error("[WC QML] ConnectorWCSDK.onWcSessionRequest failed to parse", e)
                if (connectorController) {
                    const reqId = typeof requestId === "string" ? requestId : String(requestId)
                    connectorController.rejectWCSessionRequest(topic, reqId)
                }
            }
        }
    }

    pair: function(uri) {
        if (!connectorController) {
            console.error("[WC QML] ConnectorWCSDK: connectorController not available")
            root.pairResponse(false, "Connector not available")
            return
        }
        const success = connectorController.pairWalletConnect(uri)
        root.pairResponse(success, success ? "" : "Pair failed")
    }

    getActiveSessions: function(callback) {
        if (!connectorController) {
            callback({})
            return
        }
        const validAt = Math.floor(Date.now() / 1000)
        const sessionsJson = connectorController.getWCActiveSessions(validAt)
        let activeSessions = {}
        try {
            const sessions = JSON.parse(sessionsJson || "[]")
            for (let i = 0; i < sessions.length; i++) {
                const s = sessions[i]
                const session = d.buildSessionFromWCSession(s.sessionJson || s)
                if (session && session.topic) {
                    activeSessions[session.topic] = session
                }
            }
        } catch (e) {
            console.error("Failed to parse WC sessions", e)
        }
        callback(activeSessions)
    }

    disconnectSession: function(topic) {
        if (connectorController) {
            const success = connectorController.disconnectWCSession(topic)
            root.sessionDelete(topic, success ? "" : "Failed to disconnect session")
        }
    }

    approveSession: function(requestId, account, selectedChains) {
        const pending = d.sessionRequests.get(requestId)
        if (!pending) {
            console.error("Session request not found for approval", requestId)
            return
        }
        const meta = pending.proposal?.params?.proposer?.metadata || {}
        const chainId = (selectedChains && selectedChains.length > 0) ? selectedChains[0] : 1
        const sessionJson = connectorController.approveWCSession(
            requestId, account, chainId,
            meta.url || "", meta.name || "", (meta.icons && meta.icons[0]) || "")
        if (sessionJson) {
            try {
                const session = JSON.parse(sessionJson)
                root.approveSessionResult(requestId, session, "")
            } catch (e) {
                console.error("Failed to parse approve session result", e)
                root.approveSessionResult(requestId, {}, "Approval failed")
            }
        } else {
            root.approveSessionResult(requestId, {}, "Approval failed")
        }
        d.sessionRequests.delete(requestId)
    }

    rejectSession: function(requestId) {
        if (connectorController) {
            connectorController.rejectWCSession(requestId)
        }
        d.sessionRequests.delete(requestId)
        root.rejectSessionResult(requestId, "")
    }

    acceptSessionRequest: function(topic, id, signature) {
        if (!connectorController) {
            root.sessionRequestUserAnswerResult(topic, id, false, "Connector not available")
            return
        }
        const ok = connectorController.approveWCSessionRequest(topic, (typeof id === "string" ? id : String(id)), signature)
        root.sessionRequestUserAnswerResult(topic, id, ok, ok ? "" : "Failed to send signature")
        d.sessionRequests.delete(String(id))
    }

    rejectSessionRequest: function(topic, id, error) {
        if (!connectorController) {
            root.sessionRequestUserAnswerResult(topic, id, false, "Connector not available")
            return
        }
        const ok = connectorController.rejectWCSessionRequest(topic, (typeof id === "string" ? id : String(id)))
        root.sessionRequestUserAnswerResult(topic, id, false, ok ? (error || "") : "Failed to reject")
        d.sessionRequests.delete(String(id))
    }

    getPairings: function(callback) { callback([]) }
    disconnectPairing: function(topic) { }
    buildApprovedNamespaces: function(id, params, supportedNamespaces) { }
    ping: function(topic) { }
}
