import QtQuick

import StatusQ.Core.Utils as SQUtils
import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types

import shared.stores
import utils

SQUtils.QObject {
    id: root

    // The SIWE lifecycle is a state machine that handles the lifecycle of a SIWE request
    // Steps:
    // 1. Make sure we have session approvals from the user
    // 2. Populate the auth payload
    // 3. Format the auth message
    // 4. Present the formatted auth message to the user
    // 5. Sign the auth message
    required property WalletConnectSDKBase sdk
    // Store object expected with sign and autheticate methods and signals
    required property DAppsStore store
    // JSON object received from WC
    // We're interested in the following properties:
    // {
    //     topic,
    //     params: {
    //         requester: {
    //             metadata: {
    //                 name,
    //                 url,
    //                 icons: [url]
    //             }
    //         },
    //         authPayload: {
    //             chains: [chainIds]
    //         },
    //         expiryTimestamp
    //     },
    //     id
    // }
    required property var request
    // Account model with the following roles:
    // - address
    required property var accountsModel
    // Networks model with the following roles:
    // - chainId
    required property var networksModel

    // Signals the starting of the lifecycle
    signal started()
    // Signals the end of the lifecycle
    signal finished(string error)
    // Request session approval from the user
    // This request should provide the approved chains, accounts and methods the dApp can use
    signal requestSessionApproval(var chains, string dAppUrl, string dAppName, string dAppIcon, var key)
    // Register a SessionRequestResolved object to be presented to the user for signing
    signal registerSignRequest(var request)
    // Unregister the SessionRequestResolved object
    signal unregisterSignRequest(var id)

    onFinished: {
        if (!request.requestId) {
            return
        }
        sdkConnections.enabled = false
        root.unregisterSignRequest(request.requestId)
    }

    function start() {
        d.start()
    }

    // Session approved provides the approved namespaces containing the chains, accounts and methods
    function sessionApproved(key, approvedNamespaces) {
        if (root.request.id != key) {
            return false
        }
        d.sessionApproved(key, approvedNamespaces)
    }

    // Session rejected by the user
    function sessionRejected(key) {
        if (root.request.id != key) {
            return
        }

        root.finished("Session rejected")
    } 

    Connections {
        id: sdkConnections
        target: root.sdk
        enabled: false

        //Third step: format auth message
        function onPopulateAuthPayloadResult(id, authPayload, error) {
            try {
                if (root.request.id != id) {
                    return
                }

                if (error || !authPayload) {
                    root.finished(error)
                    return
                }
                const iss = request.approvedNamespaces.eip155.accounts[0]
                request.authPayload = authPayload
                sdk.formatAuthMessage(id, authPayload, iss)
            } catch (e) {
                console.warn("Error in SiweLifeCycle::onPopulateAuthPayloadResult", e)
                root.finished(e)
            }
        }

        //Fourth step: present formatted auth message to user
        function onFormatAuthMessageResult(id, authData, error) {
            try {
                if (root.request.id != id) {
                    return
                }

                if (error || !authData) {
                    root.finished(error)
                    return
                }
                request.preparedData = authData
                root.registerSignRequest(request)
            } catch (e) {
                console.warn("Error in SiweLifeCycle::onFormatAuthMessageResult", e)
                root.finished(e)
            }
        }

        function onAcceptSessionAuthenticateResult(id, result, error) {
            if (root.request.id != id) {
                return
            }

            if (error || !result) {
                root.finished(error)
                return
            }

            root.finished("")
        }
    }

    // Request object to be used for signing
    // The data on this object is filled step by step with the sdk callbacks
    // After user has signed the data, the request is sent to the sdk for further processing
    SessionRequestWithAuth {
        id: request

        property var approvedNamespaces
        property var authPayload
        property var extractedChainsAndAccounts: approvedNamespaces ?
                                        DAppsHelpers.extractChainsAndAccountsFromApprovedNamespaces(approvedNamespaces) :
                                        { chains: [], accounts: [] }

        sourceId: Constants.DAppConnectors.WalletConnect
        store: root.store

        dappUrl: root.request.params.requester.metadata.url
        dappName: root.request.params.requester.metadata.name
        dappIcon: root.request.params.requester.metadata.icons && root.request.params.requester.metadata.icons.length > 0 ?
                        root.request.params.requester.metadata.icons[0] : ""

        requestId: root.request.id
        accountAddress: extractedChainsAndAccounts.accounts[0] ?? ""
        chainId: extractedChainsAndAccounts.chains[0] ?? ""
        method: SessionRequest.methods.personalSign.name
        event: root.request
        topic: root.request.topic
        data: ""
        preparedData: ""
        expirationTimestamp: root.request.params.expiryTimestamp

        function onBuildAuthenticationObjectResult(id, authObject, error) {
            if (id != request.requestId) {
                return
            }

            try {
                if (error) {
                    root.finished(error)
                    return
                }

                sdk.buildAuthObjectResult.disconnect(request.onBuildAuthenticationObjectResult)
                if (error) {
                    request.reject(true)
                }
                sdk.acceptSessionAuthenticate(id, [authObject])
            } catch (e) {
                console.warn("Error in SiweLifeCycle::onBuildAuthenticationObjectResult", e)
                root.finished(e)
            }
        }

        function signedHandler(topic, id, data) {
            if (topic != request.topic || id != request.requestId) {
                return
            }

            try {
                root.store.signingResult.disconnect(request.signedHandler)
                let hasErrors = (data == "")
                if (hasErrors) {
                    request.reject(true)
                }

                sdk.buildAuthObjectResult.connect(request.onBuildAuthenticationObjectResult)
                sdk.buildAuthObject(id, request.authPayload, data, request.approvedNamespaces.eip155.accounts[0])
            } catch (e) {
                console.warn("Error in SiweLifeCycle::signedHandler", e)
                root.finished(e)
            }
        }

        onRejected: (hasError) => {
            try {
                sdk.rejectSessionAuthenticate(request.requestId, hasError)
                root.finished("Signing rejected")
            } catch (e) {
                console.warn("Error in SiweLifeCycle::onRejected", e)
                root.finished(e)
            }
        }

        onExecute: () => {
            try {
                root.store.signingResult.connect(request.signedHandler)
                root.store.signMessage(request.topic, request.requestId, request.accountAddress, request.preparedData)
            } catch (e) {
                console.warn("Error in SiweLifeCycle::onExecute", e)
                root.finished(e)
            }
        }
    }

    QtObject {
        id: d

        function start() {
            if (request.isExpired()) {
                console.warn("Error in SiweLifeCycle", "Request expired")
                root.finished("Request expired")
                return
            }

            if (!root.request.id || !root.request.topic) {
                console.warn("Error in SiweLifeCycle", "Invalid request")
                root.finished("Invalid request")
                return
            }
            sdkConnections.enabled = true
            root.started()
            // First step: make sure we have session approvals
            sdk.getActiveSessions((allSessionsAllProfiles) => {
                try {
                    const sessions = DAppsHelpers.filterActiveSessionsForKnownAccounts(allSessionsAllProfiles, root.accountsModel)
                    for (const topic in sessions) {
                        if (topic == root.request.pairingTopic || topic == root.request.topic) {
                            //TODO: In theory it's possible for a dApp to request SIWE after establishing a session
                            // This is how MetaMask handles it, but for WC connections it's not clear yet if it's possible
                            console.warn("Session already exists for request", root.request.id)
                            root.finished("")
                            return
                        }
                    }

                    const key = root.request.id
                    const chains = root.request.params.authPayload.chains.map(DAppsHelpers.chainIdFromEip155)
                    const dAppUrl = root.request.params.requester.metadata.url
                    const dAppName = root.request.params.requester.metadata.name
                    const dAppIcons = root.request.params.requester.metadata.icons
                    const dAppIcon = dAppIcons && dAppIcons.length > 0 ? dAppIcons[0] : ""

                    root.requestSessionApproval(chains, dAppUrl, dAppName, dAppIcon, key)
                } catch (e) {
                    console.warn("Error in SiweLifeCycle", e)
                    root.finished(e)
                }
            })
        }

        //Second step: populate auth payload
        function sessionApproved(key, approvedNamespaces) {
            try {
                request.approvedNamespaces = approvedNamespaces
                const supportedChains = approvedNamespaces.eip155.chains
                const supportedMethods = approvedNamespaces.eip155.methods
                sdk.populateAuthPayload(request.requestId, root.request.params.authPayload, supportedChains, supportedMethods)
                return true
            } catch (e) {
                console.warn("Error in SiweLifeCycle::sessionApproved", e)
                root.finished(e)
            }
            return false
        }
    }
}
