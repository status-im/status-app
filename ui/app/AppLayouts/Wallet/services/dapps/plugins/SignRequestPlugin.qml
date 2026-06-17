import QtQuick
import QtQml

import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types

import StatusQ
import StatusQ.Core.Utils as SQUtils

import shared.stores
import utils

import "../internal"

/// Plugin that listens for session requests and manages the lifecycle of the request.
SQUtils.QObject {
    id: root

    required property WalletConnectSDKBase sdk
    required property DAppsStore store
    /// Expected to have the following roles:
    /// - topic
    /// - name
    /// - url
    /// - iconUrl
    /// - rawSessions
    required property var dappsModel
    /// Expected to have the following roles:
    /// - tokensKey
    /// - balances
    required property var groupedAccountAssetsModel
    /// Expected to have the following roles:
    /// - layer
    /// - chainId
    required property var networksModel
    /// Expected to have the following roles:
    /// - address
    required property var accountsModel
    // SessionRequestsModel where the requests are stored
    // This component will append and remove requests from this model
    required property SessionRequestsModel requests
    // The fees broker that provides the updated fees
    property TransactionFeesBroker feesBroker: TransactionFeesBroker {
        id: feesBroker
        store: root.store
    }
    // Symbol of the currency used to perform crypto -> fiat conversions
    required property string fiatSymbol
    // Function to transform the eth value to fiat
    property var getFiatValue: (maxFeesEthStr, tokenKey) => console.error("getFiatValue not implemented")

    // Signals
    /// Signal emitted when a session request is accepted
    signal accepted(string topic, string id, string data)
    /// Signal emitted when a session request is rejected
    signal rejected(string topic, string id, bool hasError)
    /// Signal emitted when a session request is completed
    /// Completed mean that we have the ACK from the SDK
    signal signCompleted(string topic, string id, bool userAccepted, string error)

    function requestReceived(event, dappName, dappUrl, dappIcon, connectorId) {
        d.onSessionRequestEvent(event, dappName, dappUrl, dappIcon, connectorId)
    }

    function requestResolved(topic, id) {
        const request = root.requests.findRequest(topic, id)
        if (!request) {
            console.error("Error finding request for topic", topic, "id", id)
            return
        }
        root.requests.removeRequest(topic, id)
        request.destroy()
    }

    function requestExpired(sessionId) {
        d.onSessionRequestExpired(sessionId)
    }

    onRejected: (topic, id, hasError) => {
        root.sdk.rejectSessionRequest(topic, id, hasError)
    }

    onAccepted: (topic, id, data) => {
        root.sdk.acceptSessionRequest(topic, id, data)
    }

    Component {
        id: sessionRequestComponent

        SessionRequestWithAuth {
            id: request
            store: root.store
            estimatedTimeCategory: feesSubscriber.estimatedTimeResponse
            feesInfo: feesSubscriber.feesInfo
            haveEnoughFunds: d.hasEnoughBalance(request.chainId, request.accountAddress, request.value, request.nativeTokenGroupKey)
            haveEnoughFees: haveEnoughFunds && d.hasEnoughBalance(request.chainId, request.accountAddress, request.nativeTokenMaxFees, request.nativeTokenGroupKey)
            nativeTokenGroupKey: Utils.getNativeTokenGroupKey(request.chainId)
            nativeTokenMaxFees: feesSubscriber.maxEthFee ? SQUtils.AmountsArithmetic.div(feesSubscriber.maxEthFee, SQUtils.AmountsArithmetic.fromNumber(1, 9)) : null
            fiatSymbol: root.fiatSymbol
            fiatMaxFees: nativeTokenMaxFees ? SQUtils.AmountsArithmetic.fromString(root.getFiatValue(nativeTokenMaxFees.toString(), Utils.getNativeTokenKey(request.chainId))) : null
            function signedHandler(topic, id, data) {
                if (topic != request.topic || id != request.requestId) {
                    return
                }
                root.store.signingResult.disconnect(request.signedHandler)

                let hasErrors = (data == "")
                if (!hasErrors) {
                    root.accepted(topic, id, data)
                } else {
                    request.reject(true)
                }
            }

            onActiveChanged: {
                if (active) {
                    feesBroker.subscribe(feesSubscriber)
                }
            }

            onAccepted: {
                active = false
            }

            onExpired: {
                active = false
            }

            onRejected: (hasError) => {
                active = false
                root.rejected(request.topic, request.requestId, hasError)
            }

            onExecute: () => {
                root.store.signingResult.connect(request.signedHandler)
                let executed = false
                try {
                    executed = d.executeSessionRequest(request, request.feesInfo)
                } catch (e) {
                    console.error("Error executing session request", e)
                }

                if (!executed) {
                    root.rejected(request.topic, request.requestId, true /*hasError*/)
                    root.store.signingResult.disconnect(request.signedHandler)
                }
                active = false
            }

            TransactionFeesSubscriber {
                id: feesSubscriber
                key: request.requestId
                chainId: request.chainId
                txObject: SessionRequest.getTxObject(request.method, request.data)
                active: request.active && !!txObject
                selectedFeesMode: Constants.FeesMode.Medium
                hexToDec: root.store.hexToDec
            }
        }
    }

    Connections {
        target: root.sdk

        function onSessionRequestEvent(sessionRequest) {
            const { id, topic } = sessionRequest
            const dapp = SQUtils.ModelUtils.getFirstModelEntryIf(root.dappsModel, (dapp) => {
                if (dapp.topic === topic) {
                    return true
                }
                return !!SQUtils.ModelUtils.getFirstModelEntryIf(dapp.rawSessions, (session) => {
                    if (session.topic === topic) {
                        return true
                    }
                })
            })

            if (!dapp) {
                console.warn("Error finding dapp for topic", topic, "id", id)
                root.sdk.rejectSessionRequest(topic, id, true)
                return
            }

            root.requestReceived(sessionRequest, dapp.name, dapp.url, dapp.iconUrl, dapp.connectorId)
        }

        function onSessionRequestExpired(sessionId) {
            root.requestExpired(sessionId)
        }

        function onSessionRequestUserAnswerResult(topic, id, accept, error) {
            let request = root.requests.findRequest(topic, id)

            if (request === null) {
                console.error("Error finding event for topic", topic, "id", id)
                return
            }
            Qt.callLater(() => root.requestResolved(topic, id))

            if (error) {
                root.signCompleted(topic, id, accept, error)
                const action = accept ? "accepting" : "rejecting"
                console.error(`Error ${action} session request for topic: ${topic}, id: ${id}, accept: ${accept}, error: ${error}`)
                return
            }

            root.signCompleted(topic, id, accept, "")
        }
    }

    QtObject {
        id: d

        function onSessionRequestEvent(event, dappName, dappUrl, dappIcon, connectorId) {
            try {
                const res = d.resolve(event, dappName, dappUrl, dappIcon, connectorId)
                if (res.conde === SessionRequest.Ignored) {
                    return
                }
                if (res.code !== SessionRequest.NoError) {
                    root.rejected(event.topic, event.id, true)
                    return
                }
                root.requests.enqueue(res.obj)
            } catch (e) {
                console.error("Error processing session request event", e, e.stack)
                root.rejected(event.topic, event.id, true)
            }
        }

        function onSessionRequestExpired(sessionId) {
            // Expired event coming from WC
            // Handling as a failsafe in case the event is not processed by the SDK
            let request = root.requests.findById(sessionId)
            if (request === null) {
                console.error("Error finding event for session id", sessionId)
                return
            }

            if (request.isExpired()) {
                return //nothing to do. The request is already expired
            }

            request.setExpired()
        }
        // returns {
        //   obj: obj or nil
        //   code: SessionRequest.ErrorCode
        // }
        function resolve(event, dappName, dappUrl, dappIcon, connectorId) {
            const {request, error} = SessionRequestResolver.resolveEvent(event, root.accountsModel, root.networksModel, root.store.hexToDec)
            if (error !== SessionRequest.NoError) {
                return { obj: null, code: error }
            }
            if (!request) {
                return { obj: null, code: SessionRequest.RuntimeError }
            }

            let obj = sessionRequestComponent.createObject(null, {
                event: request.event,
                topic: request.topic,
                requestId: request.requestId,
                method: request.method,
                accountAddress: request.account,
                chainId: request.chainId,
                data: request.data,
                preparedData: JSON.stringify(request.preparedData),
                expirationTimestamp: request.expiryTimestamp,
                dappName,
                dappUrl,
                dappIcon,
                sourceId: connectorId,
                value: request.value
            })
            if (obj === null) {
                console.error("Error creating SessionRequestResolved for event")
                return { obj: null, code: SessionRequest.RuntimeError }
            }

            return {
                obj: obj,
                code: SessionRequest.NoError
            }
        }

        function hasEnoughBalance(chainId, accountAddress, requiredBalance, tokenGroupKey) {
            if (!requiredBalance) {
                return true
            }
            if (!accountAddress || !chainId) {
                console.error("No account or chain provided to check funds", accountAddress, chainId)
                return true
            }

            const token = SQUtils.ModelUtils.getByKey(root.groupedAccountAssetsModel, "key", tokenGroupKey)
            const balance = getBalance(chainId, accountAddress, token)

            if (!balance) {
                console.error("Error fetching balance for account", accountAddress, "on chain", chainId)
                return true
            }

            const BigOps = SQUtils.AmountsArithmetic
            const haveEnoughFunds = BigOps.cmp(balance, requiredBalance) >= 0
            return haveEnoughFunds
        }

        function getBalance(chainId, address, token) {
            if (!token || !token.balances) {
                console.error("Error token balances lookup", token)
                return null
            }
            const BigOps = SQUtils.AmountsArithmetic
            const accEth = SQUtils.ModelUtils.getFirstModelEntryIf(token.balances, (balance) => {
                return balance.account.toLowerCase() === address.toLowerCase() && balance.chainId == chainId
            })
            if (!accEth) {
                console.error("Error balance lookup for account ", address, " on chain ", chainId)
                return null
            }

            const accountFundsWei = BigOps.fromString(accEth.balance)
            return BigOps.div(accountFundsWei, BigOps.fromNumber(1, 18))
        }

        function executeSessionRequest(request, payload) {
            if (!SessionRequest.getSupportedMethods().includes(request.method)) {
                console.error("Unsupported method to execute: ", request.method)
                return false
            }

            if (request.method === SessionRequest.methods.sign.name) {
                root.store.signMessageUnsafe(request.topic,
                                        request.requestId,
                                        request.accountAddress,
                                        SessionRequest.methods.personalSign.getMessageFromData(request.data))
            } else if (request.method === SessionRequest.methods.personalSign.name) {
                root.store.signMessage(request.topic,
                                  request.requestId,
                                  request.accountAddress,
                                  SessionRequest.methods.personalSign.getMessageFromData(request.data))
            } else if (request.method === SessionRequest.methods.signTypedData_v4.name ||
                       request.method === SessionRequest.methods.signTypedData.name)
            {
                let legacy = request.method === SessionRequest.methods.signTypedData.name
                root.store.safeSignTypedData(request.topic,
                                        request.requestId,
                                        request.accountAddress,
                                        SessionRequest.methods.signTypedData.getMessageFromData(request.data),
                                        request.chainId,
                                        legacy)
            } else if (SessionRequest.isTransactionMethod(request.method)) {
                const txObj = prepareTxForStatusGo(SessionRequest.getTxObject(request.method, request.data), payload)
                if (request.method === SessionRequest.methods.signTransaction.name) {
                    root.store.signTransaction(request.topic,
                                          request.requestId,
                                          request.accountAddress,
                                          request.chainId,
                                          txObj)
                } else if (request.method === SessionRequest.methods.sendTransaction.name) {
                    root.store.sendTransaction(
                                request.topic,
                                request.requestId,
                                request.accountAddress,
                                request.chainId,
                                txObj)
                }
            }

            return true
        }

        function prepareTxForStatusGo(txObj, feesInfo) {
            if (!!feesInfo) {
                let hexFeesJson = root.store.convertFeesInfoToHex(JSON.stringify(feesInfo))
                if (!!hexFeesJson) {
                    let feesInfo = JSON.parse(hexFeesJson)
                    if (feesInfo.maxFeePerGas) {
                        txObj.maxFeePerGas = feesInfo.maxFeePerGas
                    }
                    if (feesInfo.maxPriorityFeePerGas) {
                        txObj.maxPriorityFeePerGas = feesInfo.maxPriorityFeePerGas
                    }
                }
                delete txObj.gasLimit
                delete txObj.gasPrice
                delete txObj.gas
                delete txObj.type
            }
            // Remove nonce from txObj to be auto-filled by the wallet
            delete txObj.nonce
            return txObj
        }
    }
}
