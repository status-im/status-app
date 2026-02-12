import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types

import shared.stores
import utils

import QtModelsToolkit

// Plugin providing the connection handling for dApps
// Features provided:
// 1. connect
// 2. disconnect
// 3. active connections model
SQUtils.QObject {
    id: root

    required property WalletConnectSDKBase wcSDK
    required property WalletConnectSDKBase bcSDK
    required property DAppsStore dappsStore
    // Required roles: address
    required property var accountsModel
    // Required roles: chainId
    required property var networksModel

    // Output model with the following roles:
    // - name: string (optional)
    // - url: string (required)
    // - iconUrl: string (optional)
    // - topic: string (required)
    // - connectorId: int (required)
    // - accountAddressses: [{address: string}] (required)
    // - chains: string (optional)
    // - rawSessions: [{session: object}] (optional)
    readonly property ConcatModel dappsModel: dappsModel
    
    // Output signal when a dApp is disconnected
    signal disconnected(string topic, string dAppUrl, int connectorId)
    // Output signal when a new connection is proposed
    signal connected(string proposalId, string topic, string dAppUrl, int connectorId)
    // Output signal when a new connection is proposed by the SDK
    signal newConnectionProposed(string key, var chains, string dAppUrl, string dAppName, string dAppIcon, int connectorId)
    // Output signal when a new connection is failed
    signal newConnectionFailed(string key, string dappUrl, int errorCode)

    // Request to disconnect a dApp identified by the topic
    function disconnect(topic) {
        d.disconnect(topic)
    }

    // Request to connect a dApp identified by the proposal key
    // chains: array of chainIds
    // accountAddress: string
    function connect(key, chains, accoutAddress) {
        d.connect(key, chains, accoutAddress)
    }

    // Request to reject a dApp connection request identified by the proposal key
    function reject(key) {
        d.reject(key)
    }

    function getProposalMethods(key) {
        const proposal = d.activeProposals.get(key.toString())
        if (!proposal) {
            return []
        }
        return DAppsHelpers.extractMethodsFromProposal(proposal.context)
    }

    function getProposalChains(key) {
        const proposal = d.activeProposals.get(key.toString())
        if (!proposal) {
            return []
        }
        return DAppsHelpers.extractChainsFromProposal(proposal.context)
    }

    function getDAppUrl(key) {
        const proposal = d.activeProposals.get(key.toString())
        if (!proposal) {
            return ""
        }
        return ((((proposal.context || {}).params || {}).proposer || {}).metadata || {}).url || ""
    }

    function getConnectorId(key) {
        const proposal = d.activeProposals.get(key.toString())
        if (!proposal) {
            return -1
        }
        return proposal.connectorId
    }

    WCDappsProvider {
        id: dappsProvider
        sdk: root.wcSDK
        store: root.dappsStore
        supportedAccountsModel: root.accountsModel
        onConnected: (proposalId, topic, dappUrl) => {
            root.connected(proposalId, topic, dappUrl, Constants.DAppConnectors.WalletConnect)
        }
        onDisconnected: (topic, dappUrl) => {
            root.disconnected(topic, dappUrl, Constants.DAppConnectors.WalletConnect)
        }
    }

    BCDappsProvider {
        id: connectorDAppsProvider
        bcSDK: root.bcSDK
        onConnected: (pairingId, topic, dappUrl) => {
            root.connected(pairingId, topic, dappUrl, Constants.DAppConnectors.StatusConnect)
        }
        onDisconnected: (topic, dappUrl) => {
            root.disconnected(topic, dappUrl, Constants.DAppConnectors.StatusConnect)
        }
    }

    ConcatModel {
        id: dappsModel
        markerRoleName: "source"

        sources: [
            SourceModel {
                model: dappsProvider.model
                markerRoleValue: "walletConnect"
            },
            SourceModel {
                model: connectorDAppsProvider.model
                markerRoleValue: "statusConnect"
            }
        ]
    }

    // These two objects don't share a common interface because Qt5.15.2 would freeze for some reason
    QtObject {
        id: bcConnectionPromise
        function resolve(context, key, approvedChainIds, accountAddress) {
            root.bcSDK.approveSession(key, accountAddress, approvedChainIds)
        }
        function reject(context, key) {
            root.bcSDK.rejectSession(key)
        }
    }

    // Connector-style flow: approveSession(key, account, chains)
    QtObject {
        id: wcConnectionPromise
        function resolve(context, key, approvedChainIds, accountAddress) {
            root.wcSDK.approveSession(key, accountAddress, approvedChainIds)
        }
        function reject(context, key) {
            root.wcSDK.rejectSession(key)
        }
    }

    // Flow for BrowserConnect
    // 1. onSessionProposal -> new connection proposal received
    // 3. onApproveSessionResult -> session approve result
    // 4. onRejectSessionResult -> session reject result
    Connections {
        target: root.bcSDK

        function onSessionProposal(sessionProposal) {
            const key = sessionProposal.id
            const namespaces = sessionProposal.params.requiredNamespaces
            const { chains, _ } = DAppsHelpers.extractChainsAndAccountsFromApprovedNamespaces(namespaces)
            d.activeProposals.set(key.toString(), { context: sessionProposal, promise: bcConnectionPromise, connectorId: Constants.DAppConnectors.StatusConnect })
            root.newConnectionProposed(
                key,
                chains,
                sessionProposal.params.proposer.metadata.url,
                sessionProposal.params.proposer.metadata.name,
                sessionProposal.params.proposer.metadata.icons[0],
                Constants.DAppConnectors.StatusConnect
            )
        }

        function onApproveSessionResult(proposalId, session, err) {
            if (!d.activeProposals.has(proposalId.toString())) {
                console.error("No active proposal found for key: " + proposalId)
                return
            }
            const dappUrl = d.activeProposals.get(proposalId.toString()).context.params.proposer.metadata.url
            d.activeProposals.delete(proposalId.toString())
            if (err) {
                root.newConnectionFailed(proposalId, dappUrl, Pairing.errors.unknownError)
                return
            }
        }

        function onRejectSessionResult(proposalId, err) {
            if (!d.activeProposals.has(proposalId.toString())) {
                console.error("No active proposal found for key: " + proposalId)
                return
            }
            const dappUrl = d.activeProposals.get(proposalId.toString()).context.params.proposer.metadata.url
            d.activeProposals.delete(proposalId.toString())
            if (err) {
                root.newConnectionFailed(proposalId, dappUrl, Pairing.errors.rejectFailed)
                return
            }
            root.newConnectionFailed(proposalId, dappUrl, Pairing.errors.userRejected)
        }
    }

    // Flow for WalletConnect (ConnectorWCSDK)
    // 1. onSessionProposal -> new connection proposal received -> newConnectionProposed
    // 2. onApproveSessionResult -> session approve result
    // 3. onRejectSessionResult -> session reject result
    Connections {
        target: root.wcSDK

        function onSessionProposal(sessionProposal) {
            const key = sessionProposal.id
            const proposal = sessionProposal.params ? sessionProposal : { params: sessionProposal }
            const meta = (proposal.params && proposal.params.proposer && proposal.params.proposer.metadata) ? proposal.params.proposer.metadata : {}
            const chains = DAppsHelpers.extractChainsFromProposal(proposal)
            const dAppUrl = meta.url || ""
            const dAppName = meta.name || ""
            const dAppIcons = meta.icons || []
            const dAppIcon = dAppIcons.length > 0 ? dAppIcons[0] : ""

            d.activeProposals.set(key.toString(), { context: sessionProposal, promise: wcConnectionPromise, connectorId: Constants.DAppConnectors.WalletConnect })
            root.newConnectionProposed(key, chains, dAppUrl, dAppName, dAppIcon, Constants.DAppConnectors.WalletConnect)
        }

        function onApproveSessionResult(proposalId, session, err) {
            if (!d.activeProposals.has(proposalId.toString())) {
                console.error("No active proposal found for key: " + proposalId)
                return
            }
            const dappUrl = d.activeProposals.get(proposalId.toString())
                                            .context.params.proposer.metadata.url
            d.activeProposals.delete(proposalId.toString())
            d.acceptedSessionProposal = null
            d.acceptedNamespaces = null
            if (err) {
                root.newConnectionFailed(proposalId, dappUrl, Pairing.errors.unknownError)
                return
            }
        }

        function onRejectSessionResult(proposalId, err) {
            if (!d.activeProposals.has(proposalId.toString())) {
                console.error("No active proposal found for key: " + proposalId)
                return
            }
            const dappUrl = d.activeProposals.get(proposalId.toString())
                                        .context.params.proposer.metadata.url
            d.activeProposals.delete(proposalId.toString())
            if (err) {
                root.newConnectionFailed(proposalId, dappUrl, Pairing.errors.rejectFailed)
                return
            }
            root.newConnectionFailed(proposalId, dappUrl, Pairing.errors.userRejected)
        }
    }

    QtObject {
        id: d

        property var activeProposals: new Map()
        property var acceptedSessionProposal: null
        property var acceptedNamespaces: null

        function disconnect(connectionId) {
            const dApp = d.getDAppByTopic(connectionId)
            if (!dApp) {
                console.error("Disconnecting dApp: dApp not found")
                return
            }
            if (dApp.connectorId === undefined) {
                console.error("Disconnecting dApp: connectorId not found")
                return
            }

            const sdk = dApp.connectorId === Constants.DAppConnectors.WalletConnect ? root.wcSDK : root.bcSDK
            sdkDisconnect(dApp, sdk)
        }

        // Disconnect all sessions for a dApp
        function sdkDisconnect(dapp, sdk) {
            SQUtils.ModelUtils.forEach(dapp.rawSessions, (session) => {
                sdk.disconnectSession(session.topic)
            })
        }

        function reject(key) {
           if (!d.activeProposals.has(key.toString())) {
                console.error("Rejecting dApp: dApp not found")
                return
            }

            const proposal = d.activeProposals.get(key.toString())
            proposal.promise.reject(proposal.context, key)
        }

        function connect(key, chains, accoutAddress) {
            if (!d.activeProposals.has(key.toString())) {
                console.error("Connecting dApp: dApp not found", key)
                return
            }

            const proposal = d.activeProposals.get(key.toString())
            proposal.promise.resolve(proposal.context, key, chains, accoutAddress)
        }

        function getDAppByTopic(topic) {
            return SQUtils.ModelUtils.getFirstModelEntryIf(dappsModel, (modelItem) => {
                if (modelItem.topic == topic) {
                    return true
                }
                if (!modelItem.rawSessions) {
                    return false
                }
                for (let i = 0; i < modelItem.rawSessions.ModelCount.count; i++) {
                    if (modelItem.rawSessions.get(i).topic == topic) {
                        return true
                    }
                }
            })
        }

        //Special case for chain agnostic dapps
        //WC considers the approved namespace as valid, but there's no chainId or account established
        //Usually this request is declared by using `eip155:0`, but we don't support this chainID, resulting in empty `chains` and `accounts`
        //The established connection will use for all user approved chains and accounts
        //This fix is applied to all valid namespaces that don't have a chainId or account
        function applyChainAgnosticFix(approvedNamespaces) {
            try {
                const an = approvedNamespaces.eip155
                const chainAgnosticRequest = (!an.chains || an.chains.length === 0) && (!an.accounts || an.accounts.length === 0)
                if (!chainAgnosticRequest) {
                    return approvedNamespaces
                }

                // If the `d.acceptedNamespaces` is set it means the user already confirmed the chain and account
                if (!!d.acceptedNamespaces) {
                    approvedNamespaces.eip155.chains = d.acceptedNamespaces.eip155.chains
                    approvedNamespaces.eip155.accounts = d.acceptedNamespaces.eip155.accounts
                    return approvedNamespaces
                }

                // Show to the user all possible chains
                const supportedNamespacesStr = DAppsHelpers.buildSupportedNamespacesFromModels(
                    root.networksModel, root.accountsModel, SessionRequest.getSupportedMethods())
                const supportedNamespaces = JSON.parse(supportedNamespacesStr)

                approvedNamespaces.eip155.chains = supportedNamespaces.eip155.chains
                approvedNamespaces.eip155.accounts = supportedNamespaces.eip155.accounts
            } catch (e) {
                console.warn("WC Error applying chain agnostic fix", e)
            }

            return approvedNamespaces
        }
    }
}
