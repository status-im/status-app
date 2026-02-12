import QtQuick

import StatusQ.Core.Utils

QObject {
    id: root
    objectName: "DAppsModel"
    // RoleNames
    // name: string
    // url: string
    // iconUrl: string
    // topic: string
    // connectorId: int
    // connectorBadge: string
    // clientId: string
    // accountAddressses: [{address: string}]
    // chains: string
    // rawSessions: [{session: object}]
    readonly property ListModel model: ListModel {}

    // Appending a new DApp to the model
    // Required properties: url, topic, connectorId, accountAddresses
    // Optional properties: name, iconUrl, connectorBadge, clientId, chains, rawSessions
    function append(dapp) {
        try {
            let {name, url, iconUrl, topic, accountAddresses, connectorId, connectorBadge, clientId, rawSessions } = dapp
            if (!url || !topic || connectorId === undefined || !accountAddresses) {
                console.warn("DAppsModel - Failed to append dapp, missing required fields", JSON.stringify(dapp))
                return
            }
            
            url = url.trim()
            if (!url) {
                console.warn("DAppsModel - Failed to append dapp, URL is empty after trim")
                return
            }

            name = name || ""
            iconUrl = iconUrl || ""
            connectorBadge = connectorBadge || ""
            clientId = clientId || ""
            accountAddresses = accountAddresses || []
            rawSessions = rawSessions || []

            root.model.append({
                name,
                url,
                iconUrl,
                topic,
                connectorId,
                connectorBadge,
                clientId,
                accountAddresses,
                rawSessions
            })
        } catch (e) {
            console.warn("DAppsModel - Failed to append dapp", e)
        }
    }

    function remove(topic) {
        const { index } = findDapp(topic)
        if (index < 0) {
            console.warn("DAppsModel - Failed to remove dapp, not found", topic)
            return
        }
        root.model.remove(index)
    }

    function clear() {
        root.model.clear()
    }

    function getByTopic(topic) {
        const dappTemplate = (dapp) => {
            return {
                name: dapp.name,
                url: dapp.url,
                iconUrl: dapp.iconUrl,
                topic: dapp.topic,
                connectorId: dapp.connectorId,
                connectorBadge: dapp.connectorBadge || "",
                clientId: dapp.clientId || "",
                accountAddresses: dapp.accountAddresses,
                rawSessions: dapp.rawSessions
            }
        }

        const { dapp } = findDapp(topic)
        if (!dapp) {
            return null
        }
        return dappTemplate(dapp)
    }

    function findDapp(topic) {
        for (let i = 0; i < root.model.count; i++) {
            if (root.model.get(i).topic === topic) {
                return { dapp: root.model.get(i), index: i, sessionIndex: 0 }
            }
        }
        return { dapp: null, index: -1, sessionIndex: -1 }
    }
}