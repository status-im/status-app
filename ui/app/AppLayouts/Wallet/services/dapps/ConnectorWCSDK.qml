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
        property var pendingGetActiveSessionsCallback: null

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

        function parseSessionsJson(sessionsJson) {
            const activeSessions = {}
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
            return activeSessions
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

        function onWcSessionDelete(topic, dappUrl) {
            root.disconnected(dappUrl, "")
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

        function onWcPairWalletConnectDone(success, error) {
            root.pairResponse(success, success ? "" : (error || "Pair failed"))
        }

        function onWcGetActiveSessionsDone(sessionsJson, error) {
            const callback = d.pendingGetActiveSessionsCallback
            d.pendingGetActiveSessionsCallback = null
            if (!callback) {
                return
            }

            if (error) {
                callback({})
                return
            }
            callback(d.parseSessionsJson(sessionsJson))
        }

        function onWcApproveSessionDone(proposalId, sessionJson, error) {
            d.sessionRequests.delete(proposalId)
            if (error || !sessionJson) {
                root.approveSessionResult(proposalId, {}, error || "Approval failed")
                return
            }

            try {
                const session = JSON.parse(sessionJson)
                root.approveSessionResult(proposalId, session, "")
            } catch (e) {
                console.error("Failed to parse approve session result", e)
                root.approveSessionResult(proposalId, {}, "Approval failed")
            }
        }

        function onWcRejectSessionDone(proposalId, error) {
            d.sessionRequests.delete(proposalId)
            root.rejectSessionResult(proposalId, error || "")
        }

        function onWcSessionRequestAnswerDone(topic, requestId, accept, error) {
            const reqId = String(requestId)
            if (d.sessionRequests.has(reqId)) {
                d.sessionRequests.delete(reqId)
            }
            root.sessionRequestUserAnswerResult(topic, requestId, accept, error || "")
        }

        function onWcEmitSessionEventDone(topic, name, error) {
            if (error) {
                console.warn("[WC QML] emit session event failed", topic, name, error)
            }
        }

        function onWcDisconnectSessionDone(topic, dappUrl, error) {
            root.disconnected(dappUrl, error || "")
        }
    }

    pair: function(uri) {
        if (!connectorController) {
            console.error("[WC QML] ConnectorWCSDK: connectorController not available")
            root.pairResponse(false, "Connector not available")
            return
        }
        connectorController.pairWalletConnect(uri)
    }

    getActiveSessions: function(callback) {
        if (!connectorController) {
            callback({})
            return
        }
        const previousCallback = d.pendingGetActiveSessionsCallback
        if (previousCallback) {
            previousCallback({})
        }
        const validAt = Math.floor(Date.now() / 1000)
        d.pendingGetActiveSessionsCallback = callback
        connectorController.getWCActiveSessions(validAt)
    }

    disconnect: function(url, clientId) {
        if (connectorController) {
            const success = connectorController.disconnect(url, clientId || "walletconnect")
            root.disconnected(url, success ? "" : "Failed to disconnect")
        }
    }

    disconnectByTopic: function(topic, url) {
        if (connectorController) {
            connectorController.disconnectWCSession(topic, url)
        }
    }

    approveSession: function(requestId, account, selectedChains) {
        if (!connectorController) {
            console.error("[WC QML] ConnectorWCSDK: connectorController not available")
            return
        }
        const pending = d.sessionRequests.get(requestId)
        if (!pending) {
            console.error("Session request not found for approval", requestId)
            return
        }
        const meta = pending.proposal?.params?.proposer?.metadata || {}
        const chains = (selectedChains && selectedChains.length > 0) ? selectedChains : [1]
        connectorController.approveWCSession(
            requestId, account,
            meta.url || "", meta.name || "", (meta.icons && meta.icons[0]) || "", JSON.stringify(chains))
    }

    rejectSession: function(requestId) {
        if (!connectorController) {
            root.rejectSessionResult(requestId, "Connector not available")
            return
        }
        connectorController.rejectWCSession(requestId)
    }

    acceptSessionRequest: function(topic, id, signature) {
        if (!connectorController) {
            root.sessionRequestUserAnswerResult(topic, id, false, "Connector not available")
            return
        }
        const reqId = (typeof id === "string" ? id : String(id))
        connectorController.approveWCSessionRequest(topic, reqId, signature)
    }

    rejectSessionRequest: function(topic, id, error) {
        if (!connectorController) {
            root.sessionRequestUserAnswerResult(topic, id, false, "Connector not available")
            return
        }
        const reqId = (typeof id === "string" ? id : String(id))
        connectorController.rejectWCSessionRequest(topic, reqId)
    }

    getPairings: function(callback) { callback([]) }
    disconnectPairing: function(topic) { }
    buildApprovedNamespaces: function(id, params, supportedNamespaces) { }
    ping: function(topic) { }

    emitSessionEvent: function(topic, event, chainId) {
        if (!connectorController) {
            console.warn("[WC QML] ConnectorWCSDK: connectorController not available for emitSessionEvent")
            return
        }
        connectorController.emitWCSessionEvent(topic, event.name, JSON.stringify(event.data), chainId)
    }
}
