import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components

import StatusQ
import SortFilterProxyModel
import AppLayouts.Wallet.controls
import shared.popups.walletconnect
import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types

import shared.stores
import utils

import "types"

/// Act as another layer of abstraction to the WalletConnectSDKBase
/// Converts the store requests into WalletConnect standard requests
WalletConnectSDKBase {
    id: root
    
    required property BrowserConnectStore store
    /// Required roles: chainId
    required property var networksModel
    /// Array of clientIds to exclude from getActiveSessions (e.g. ["walletconnect"])
    property var excludeClientIds: []
    /// Required roles: address
    required property var accountsModel

    projectId: ""

    Connections {
        target: root.store
        enabled: root.enabled

        function onSendTransaction(requestId, dappInfoString) {
            try {
                var dappInfo = JSON.parse(dappInfoString)
                var txArgsParams = JSON.parse(dappInfo.txArgs)
                let event = d.buildTransactionRequest(requestId, dappInfo.url, dappInfo.chainId, txArgsParams)
                d.sessionRequests.set(requestId, event)

                root.sessionRequestEvent(event)
            } catch (e) {
                d.sessionRequests.delete(requestId)
                root.store.rejectTransaction("", requestId, "Failed to parse dappInfo for session request")
                console.error("Failed to parse dappInfo for session request", e)
            }
        }

        function onSign(requestId, dappInfoString) {
            try {
                const dappInfo = JSON.parse(dappInfoString)
                const mainNet = SQUtils.ModelUtils.getByKey(root.networksModel, "layer", 1)
                if (!mainNet) {
                    root.store.rejectSign(requestId)
                    console.error("Mainnet not found - sign failed")
                    return
                }

                const event = d.buildSignRequest(requestId, dappInfo.url, mainNet.chainId, dappInfo.challenge, dappInfo.address, dappInfo.method)
                d.sessionRequests.set(requestId, event)
                root.sessionRequestEvent(event)
            } catch (e) {
                d.sessionRequests.delete(requestId)
                root.store.rejectSign("", requestId)
                console.error("Failed to parse dappInfo for session request", e)
            }
        }

        function onConnectRequested(requestId, dappInfoString) {
            try {
                var dappInfo = JSON.parse(dappInfoString)
                dappInfo.proposal = d.buildSessionProposal(requestId, dappInfo.url, dappInfo.name, dappInfo.icon, SessionRequest.getSupportedMethods())
                d.sessionRequests.set(requestId, dappInfo)
                root.sessionProposal(dappInfo.proposal)
            } catch (e) {
                console.error("Failed to parse dappInfo for connection request", e)
            }
        }

        function onDisconnected(dappInfoString) {
            try {
                let dappItem = JSON.parse(dappInfoString)
                root.disconnected(dappItem.url, false)
            } catch (e) {
                console.error("Failed to parse dappInfo for disconnection", e)
            }
        }

        function onApproveTransactionResponse(topic, requestId, error) {
            try {
                const errorStr = error ? "Faled to approve trasnsaction" : ""
                root.sessionRequestUserAnswerResult(topic, requestId, true, errorStr)
            } catch (e) {
                console.error("Failed to approve transaction response", e)
            }
        }

        function onRejectTransactionResponse(topic, requestId, error) {
            try {
                const errorStr = error ? "Faled to reject trasnsaction" : ""
                root.sessionRequestUserAnswerResult(topic, requestId, false, errorStr)
            } catch (e) {
                console.error("Failed to reject transaction response", e)
            }
        }

        function onApproveSignResponse(topic, requestId, error) {
            try {
                const errorStr = error ? "Faled to approve sign" : ""
                root.sessionRequestUserAnswerResult(topic, requestId, true, errorStr)
            } catch (e) {
                console.error("Failed to approve sign response", e)
            }
        }

        function onRejectSignResponse(topic, requestId, error) {
            try {
                const errorStr = error ? "Faled to reject sign" : ""
                root.sessionRequestUserAnswerResult(topic, requestId, false, errorStr)
            } catch (e) {
                console.error("Failed to reject sign response", e)
            }
        }
    }

    approveSession: function(requestId, account, selectedChains) {
        try {
            if (!d.sessionRequests.has(requestId)) {
                console.error("Session request not found")
                return
            }
            const dappInfo = d.sessionRequests.get(requestId)
            root.store.approveConnection(requestId, account, JSON.stringify(selectedChains))
            const newSession = d.buildSession(dappInfo.url, dappInfo.name, dappInfo.icon, requestId, account, selectedChains, dappInfo.clientId)
            root.approveSessionResult(requestId, newSession, "")
            d.sessionRequests.delete(requestId)
        } catch (e) {
            console.error("Failed to approve session", e)
        }
    }

    rejectSession: function(requestId) {
        try {
            root.store.rejectConnection(requestId)
            root.rejectSessionResult(requestId, "")
            d.sessionRequests.delete(requestId)
        } catch (e) {
            console.error("Failed to reject session", e)
        }
    }

    acceptSessionRequest: function(topic, requestId, signature) {
        if (!d.sessionRequests.has(requestId)) {
            root.sessionRequestUserAnswerResult(topic, requestId, false, "Unknown request method")
            console.error("Session request not found")
            return
        }
        const event = d.sessionRequests.get(requestId)
        if (event.params.request.method === SessionRequest.methods.sendTransaction.name) {
            root.store.approveTransaction(topic, requestId, signature)
        } else if (event.params.request.method === SessionRequest.methods.personalSign.name ||
                   event.params.request.method === SessionRequest.methods.signTypedData_v4.name) {
            root.store.approveSign(topic, requestId, signature)
        } else {
            root.sessionRequestUserAnswerResult(topic, requestId, false, "Unknown request method")
            console.error("Unknown request method", event.params.request.method)
        }
    }

    rejectSessionRequest: function(topic, requestId, error) {
        if (!d.sessionRequests.has(requestId)) {
                root.sessionRequestUserAnswerResult(topic, requestId, false, "Unknown request method")
            console.error("Session request not found")
            return
        }
        const event = d.sessionRequests.get(requestId)
        if (event.params.request.method === SessionRequest.methods.sendTransaction.name) {
            root.store.rejectTransaction(topic, requestId, error)
        } else if (event.params.request.method === SessionRequest.methods.personalSign.name ||
                   event.params.request.method === SessionRequest.methods.signTypedData_v4.name) {
            root.store.rejectSign(topic, requestId)
        } else {
            root.sessionRequestUserAnswerResult(topic, requestId, false, "Unknown request method")
            console.error("Unknown request method", event.params.request.method)
        }
    }

    disconnect: function(topic, clientId) {
        root.store.disconnect(topic, clientId || "")
    }

    getActiveSessions: function(callback) {
        try {
            const dappsStr = root.store.getDApps()
            const dapps = JSON.parse(dappsStr)
            let activeSessions = {}
            for (let i = 0; i < dapps.length; i++) {
                const dapp = dapps[i]

                if (root.excludeClientIds.includes(dapp.clientId)) {
                    continue
                }

                activeSessions[dapp.url] = d.buildSession(dapp.url, dapp.name, dapp.iconUrl, "", dapp.sharedAccount, [dapp.chainId], dapp.clientId)
            }
            callback(activeSessions)
        } catch (e) {
            console.error("Failed to get active sessions", e)
            callback([])
        }
    }

    // We don't expect requests for these. They are here only to spot errors
    pair: function(pairLink) { console.error("ConnectorSDK.pair: not implemented") }
    getPairings: function(callback) { console.error("ConnectorSDK.getPairings: not implemented") }
    disconnectPairing: function(topic) { console.error("ConnectorSDK.disconnectPairing: not implemented") }
    buildApprovedNamespaces: function(params, supportedNamespaces) { console.error("ConnectorSDK.buildApprovedNamespaces: not implemented") }

    QtObject {
        id: d
        readonly property var sessionRequests: new Map()
        function buildSession(dappUrl, dappName, dappIcon, proposalId, account, chains, clientId) {
            let sessionTemplate = (dappUrl, dappName, dappIcon, proposalId, eipAccount, eipChains, clientId) => {
                const session = {
                    peer: {
                        metadata: {
                            description: "-",
                            icons: [
                                dappIcon
                            ],
                            name: dappName,
                            url: dappUrl
                        }
                    },
                    namespaces: {
                        eip155: {
                            accounts: [eipAccount],
                            chains: eipChains
                        }
                    },
                    pairingTopic: proposalId,
                    topic: dappUrl
                }
                if (clientId !== undefined && clientId !== null) {
                    session.clientId = clientId
                }
                return session
            }

            const eipAccount = account ? `eip155:${account}` : ""
            const eipChains = chains ? chains.map((chain) => `eip155:${chain}`) : []

            return sessionTemplate(dappUrl, dappName, dappIcon, proposalId, eipAccount, eipChains, clientId)
        }

        function buildTransactionRequest(requestId, topic, chainId, txArgs) {
            var paramsObj = {}
            if (txArgs.gasPrice) {
                paramsObj.gasPrice = txArgs.gasPrice
            }
            if (txArgs.gas) {
                paramsObj.gasLimit = txArgs.gas
            }
            if (txArgs.maxFeePerGas) {
                paramsObj.maxFeePerGas = txArgs.maxFeePerGas
            }
            if (txArgs.maxPriorityFeePerGas) {
                paramsObj.maxPriorityFeePerGas = txArgs.maxPriorityFeePerGas
            }
            if (txArgs.nonce) {
                paramsObj.nonce = txArgs.nonce
            }
            if (!!txArgs.data && txArgs.data !== "0x") {
                paramsObj.data = txArgs.data
            }
            if (txArgs.to) {
                paramsObj.to = txArgs.to
            }
            if (txArgs.from) {
                paramsObj.from = txArgs.from
            }
            paramsObj.value = txArgs.value

            return {
                id: requestId,
                topic,
                params: {
                    chainId: `eip155:${chainId}`,
                    request: {
                        method: SessionRequest.methods.sendTransaction.name,
                        params: [
                            paramsObj
                        ]
                    }
                }
            }
        }
        
        function buildSignRequest(requestId, topic, chainId, challenge, address, method) {
            let params = []
            if (method == SessionRequest.methods.personalSign.name) {
                params = [challenge, address]
            } else if (method == SessionRequest.methods.signTypedData_v4.name) {
                params = [address, challenge]
            } else {
                console.error("Unknown sign method", method)
                return
            }

            return {
                id: requestId,
                topic,
                params: {
                    chainId: `eip155:${chainId}`,
                    request: {
                        method,
                        params
                    }
                }
            }
        }

        function buildSessionProposal(id, url, name, icon, methods) {
            const supportedNamespaces = DAppsHelpers.buildSupportedNamespacesFromModels(root.networksModel, root.accountsModel, methods)
            const proposal =  {
                id,
                params: {
                    optionalNamespaces: {},
                    proposer: {
                        metadata: {
                            description: "-",
                            icons: [
                                icon
                            ],
                            name,
                            url
                        }
                    },
                    requiredNamespaces: JSON.parse(supportedNamespaces)
                }
            }
            return proposal
        }
    }
}
