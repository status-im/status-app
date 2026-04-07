pragma ComponentBehavior: Bound

import QtQuick

//This is a helper component that is used to batch requests and send them periodically
//It is used to reduce the number of requests sent to the server and notify different subscribers of the same request
//It is used by the Subscription component
QtObject {
    id: root

    signal request(string subscriptionId, string topic)

    signal subscribed(string subscriptionId)
    signal unsubscribed(string subscriptionId)

    function response(subscriptionId: string, responseObj: var): void {
        let resolvedTopic = ""
        Object.keys(d.topics).forEach(function (topic) {
            d.topics[topic].subscriptions.forEach(function(subscrId) {
                if(subscriptionId === subscrId) {
                    resolvedTopic = topic
                    return
                }
            })
        })
        d.onResponse(resolvedTopic, responseObj)
    }
    function subscribe(subscription: var): void {
        d.subscribe(subscription)
    }
    function unsubscribe(subscription: var): void {
        d.unsubscribe(subscription)
    }

    property bool active: true

    readonly property QtObject d: QtObject {
        //Mapping subscriptionId to subscription object
        //subscriptionId is a string and represents the id of the subscription
        //E.g. "subscriptionId": {subscription: subscriptionObject, topic: "topic"}
        //The purpose of this mapping is to keep track of the subscriptions and their topics
        readonly property var managedSubscriptions: ({})

        //Mapping topic to subscriptionIds and request data
        //topic is a string and represents the topic of the subscription
        //E.g. "topic": {nextRequestTimestamp: 0, requestInterval: 1000, subscriptions: ["subscriptionId1", "subscriptionId2"], response: null}
        readonly property var topics: ({})
        property int topicsCount: 0 //helper property to track change events



            



        function subscribe(subscription: var): void {
            if(!(subscription instanceof Subscription)) 
                return
            if(d.managedSubscriptions.hasOwnProperty(subscription.subscriptionId)) 
                return

            registerToManagedSubscriptions(subscription)
            connectToSubscriptionEvents(subscription)
            if(subscription.isReady && subscription.topic)
                registerToTopic(subscription.topic, subscription.subscriptionId)
            root.subscribed(subscription.subscriptionId)
        }

        function unsubscribe(subscriptionId: string): void {
            if(!subscriptionId || !d.managedSubscriptions.hasOwnProperty(subscriptionId)) 
                return

            releaseManagedSubscription(subscriptionId)
            root.unsubscribed(subscriptionId)
        }

        function registerToManagedSubscriptions(subscriptionObject: var): void {
            d.managedSubscriptions[subscriptionObject.subscriptionId] = {
                subscription: subscriptionObject,
                topic: subscriptionObject.topic,
            }
        }

        function releaseManagedSubscription(subscriptionId: string): void {
            if(!subscriptionId || !d.managedSubscriptions.hasOwnProperty(subscriptionId)) return

            const subscriptionInfo = d.managedSubscriptions[subscriptionId]

            unregisterFromTopic(subscriptionInfo.topic, subscriptionId)
            delete d.managedSubscriptions[subscriptionId]
        }

        function connectToSubscriptionEvents(subscription: var): void {
            const subscriptionId = subscription.subscriptionId
            const topic = subscription.topic

            const onTopicChangeHandler = () => {
                if(!subscription.isReady || !d.managedSubscriptions.hasOwnProperty(subscriptionId)) return

                const newTopic = subscription.topic
                const oldTopic = d.managedSubscriptions[subscriptionId].topic

                if(newTopic === oldTopic) return

                d.unregisterFromTopic(oldTopic, subscriptionId)
                d.registerToTopic(newTopic, subscriptionId)
                d.managedSubscriptions[subscriptionId].topic = newTopic
            }

            const onReadyChangeHandler = () => {
                if(!d.managedSubscriptions.hasOwnProperty(subscriptionId)) return

                if(subscription.isReady) {
                    d.registerToTopic(subscription.topic, subscription.subscriptionId)
                } else {
                    const subscriptionTopic = d.managedSubscriptions[subscriptionId].topic
                    d.unregisterFromTopic(subscriptionTopic, subscriptionId)
                }
            }

            const onDestructionHandler = () => {
                if(!d.managedSubscriptions.hasOwnProperty(subscriptionId))
                    return
                
                root.unsubscribed.disconnect(onUnsubscribedHandler) //object is destroyed, no need to listen to the signal anymore
                unsubscribe(subscriptionId)
            }

            const onUnsubscribedHandler = (subscriptionId) => {
                if(subscriptionId !== subscription.subscriptionId)
                    return

                subscription.Component.onDestruction.disconnect(onDestructionHandler)
                subscription.isReadyChanged.disconnect(onReadyChangeHandler)
                subscription.topicChanged.disconnect(onTopicChangeHandler)
            }

            subscription.Component.onDestruction.connect(onDestructionHandler)
            subscription.isReadyChanged.connect(onReadyChangeHandler)
            subscription.topicChanged.connect(onTopicChangeHandler)
            root.unsubscribed.connect(onUnsubscribedHandler)
        }

        function registerToTopic(topic: string, subscriptionId: string): void {
            if(!d.topics.hasOwnProperty(topic)) {
                d.topics[topic] = {
                    subscriptions: [],
                    response: null,
                    requestPending: false
                }
                d.topicsCount++
            }

            const index = d.topics[topic].subscriptions.indexOf(subscriptionId)
            if(index !== -1) {
                console.assert("Duplicate subscription: " + subscriptionId + " " + topic)
                return
            }

            const subscriptionsCount = d.topics[topic].subscriptions.push(subscriptionId)
            if(subscriptionsCount === 1 && root.active) {
                d.request(subscriptionId, topic)
            }
            d.managedSubscriptions[subscriptionId].subscription.response = d.topics[topic].response
        }

        function unregisterFromTopic(topic: string, subscriptionId: string): void {
            if(!d.topics.hasOwnProperty(topic)) return

            const index = d.topics[topic].subscriptions.indexOf(subscriptionId)
            if(index === -1) return

            d.topics[topic].subscriptions.splice(index, 1)
            if(d.topics[topic].subscriptions.length === 0) {
                delete d.topics[topic]
                d.topicsCount--
            }
        }





        function request(subscriptionId: string, topic: string): void {
            if(!d.topics.hasOwnProperty(topic)) return

            d.topics[topic].requestPending = true
            
            root.request(subscriptionId, topic)
        }

        function onResponse(topic: string, responseObj: var): void {
            if(!d.topics.hasOwnProperty(topic)) return

            d.topics[topic].response = responseObj
            d.topics[topic].subscriptions.forEach(function(subscriptionId) {
                d.managedSubscriptions[subscriptionId].subscription.response = responseObj
            })
            d.topics[topic].requestPending = false
        }
    }
}
