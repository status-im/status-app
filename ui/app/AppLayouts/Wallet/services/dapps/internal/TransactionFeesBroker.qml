import QtQuick

import AppLayouts.Wallet.services.dapps.types
import StatusQ.Core.Utils as SQUtils

import shared.stores

// The TransactionFeesBroker is responsible for managing the subscriptions to the estimated time, fees and gas limit for a transaction
// It will bundle the same requests to optimise the backend load and will notify the subscribers when the data is ready
// It can only work with a TransactionFeesSubscriber
SQUtils.QObject {
    id: root

    required property DAppsStore store
    property int interval: 5000

    function subscribe(subscriberObj) {
        if (!(subscriberObj instanceof TransactionFeesSubscriber)) {
            console.error("Invalid subscriber object")
            return
        }

        try {
            const estimatedTimeSub = estimatedTimeSubscription.createObject(subscriberObj, {
                subscriber: subscriberObj
            })
            const feesSub = feesSubscription.createObject(subscriberObj, {
                subscriber: subscriberObj
            })
            const gasLimitSub = gasLimitSubscription.createObject(subscriberObj, {
                subscriber: subscriberObj
            })
            broker.subscribe(estimatedTimeSub)
            broker.subscribe(feesSub)
            broker.subscribe(gasLimitSub)
        } catch (e) {
            console.error("Error subscribing to estimated time: ", e)
        }
    }

    enum SubscriptionType {
        Fees,
        GasLimit,
        EstimatedTime
    }

    SQUtils.SubscriptionBroker {
        id: broker

        onRequest: (topic) => { return d.computeFees(topic) }
    }

    SQUtils.QObject {
        id: d
        
        function computeFees(topic) {
            try {
                const args = JSON.parse(topic)
                switch (args.type) {
                    case TransactionFeesBroker.SubscriptionType.Fees:
                        root.store.requestSuggestedFees(topic, args.chainId)
                        break
                    case TransactionFeesBroker.SubscriptionType.GasLimit:
                        root.store.requestGasEstimate(topic, args.chainId, args.tx)
                        break
                    case TransactionFeesBroker.SubscriptionType.EstimatedTime:
                        root.store.requestEstimatedTime(topic, args.chainId, args.maxFeePerGasHex)
                        break
                }
            } catch (e) {
                console.error("Error computing fees: ", e)
            }
        }
    }

    Component {
        id: feesSubscription
        SQUtils.Subscription {
            required property TransactionFeesSubscriber subscriber
            readonly property var requestArgs: ({
                type: TransactionFeesBroker.SubscriptionType.Fees,
                chainId: subscriber.chainId
            })
            isReady: subscriber.active
            topic: isReady ? JSON.stringify(requestArgs) : ""
            onResponseChanged: {
                if (!response || !response.success)
                    return
                subscriber.setFees(response.suggestedFees)
            }
        }
    }

    Component {
        id: estimatedTimeSubscription
        SQUtils.Subscription {
            required property TransactionFeesSubscriber subscriber
            readonly property var requestArgs: ({
                type: TransactionFeesBroker.SubscriptionType.EstimatedTime,
                chainId: subscriber.chainId,
                maxFeePerGasHex: subscriber.txObject ? (subscriber.txObject.maxFeePerGas || subscriber.txObject.gasPrice || "") :
                                ""
            })
            isReady: subscriber.active
            topic: isReady ? JSON.stringify(requestArgs) : ""
            onResponseChanged: {
                if (!response || !response.success)
                    return
                subscriber.setEstimatedTime(response.estimatedTime)
            }
        }
    }

    Component {
        id: gasLimitSubscription
        SQUtils.Subscription {
            required property TransactionFeesSubscriber subscriber
            readonly property var requestArgs: ({
                type: TransactionFeesBroker.SubscriptionType.GasLimit,
                chainId: subscriber.chainId,
                tx: subscriber.gasEstimateTxObject
            })
            // asked even when the dApp names a gas, we sign the larger; retried until it answers,
            // unless the dApp's gas can be used
            isReady: subscriber.active && !!subscriber.gasEstimateTxObject && !!subscriber.chainId && !subscriber.gasEstimated
            topic: isReady ? JSON.stringify(requestArgs) : ""
            onResponseChanged: {
                if (!response)
                    return
                subscriber.setGasEstimate(response.success ? response.gasEstimate : "", subscriber.txKey(requestArgs.tx))
            }
        }
    }

    Connections {
        id: storeConnections
        target: root.store

        function onEstimatedTimeResponse(topic, timeCategory, success) {
            broker.response(topic, { estimatedTime: timeCategory, success})
        }

        function onSuggestedFeesResponse(topic, suggestedFeesJson, success) {
            broker.response(topic, { suggestedFees: suggestedFeesJson, success: success })
        }

        function onEstimatedGasResponse(topic, gasEstimate, success) {
            broker.response(topic, { gasEstimate, success })
        }
    }
}