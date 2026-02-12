import QtQuick

import AppLayouts.Wallet.services.dapps
import utils

DAppsModel {
    id: root
    
    required property WalletConnectSDKBase bcSDK
    /// Array of clientIds to exclude from the model (e.g. ["walletconnect"])
    property var excludeClientIds: []

    readonly property int connectorId: Constants.StatusConnect
    readonly property string clientId: ""
    readonly property bool enabled: bcSDK.enabled

    signal connected(string pairingId, string topic, string dAppUrl)
    signal disconnected(string dAppUrl)

    Connections {
        target: root.bcSDK
        enabled: root.enabled

        function onDisconnected(url, err) {
            if (err) {
                console.warn("Error disconnecting dApp:", url, err)
            }

            d.resetModel()
            root.disconnected(url)
        }

        function onApproveSessionResult(proposalId, session, error) {
            if (error) {
                console.warn("Failed to approve session", error)
                return
            }

            const dapp = d.sessionToDApp(session)
            root.append(dapp)
            root.connected(proposalId, dapp.topic, dapp.url)
        }
    }

    QtObject {
        id: d
        function sessionToDApp(session) {
            const dapp = session.peer.metadata
            if (!!dapp.icons && dapp.icons.length > 0) {
                dapp.iconUrl = dapp.icons[0]
            } else {
                dapp.iconUrl = ""
            }
            const accounts = DAppsHelpers.getAccountsInSession(session)
            dapp.accountAddresses = accounts.map(account => ({address: account}))
            dapp.topic = session.topic
            dapp.rawSessions = [session]
            dapp.connectorId = root.connectorId
            dapp.clientId = session.clientId || root.clientId || ""
            return dapp
        }
        function getPersistedDapps() {
            if (!root.enabled) {
                return []
            }
            let dapps = []
            root.bcSDK.getActiveSessions((allSessions) => {
                if (!allSessions) {
                    return
                }

                for (const sessionID in allSessions) {
                    const session = allSessions[sessionID]
                    const sessionClientId = session.clientId || (session.peer && session.peer.metadata && session.peer.metadata.clientId) || ""

                    if (root.excludeClientIds.includes(sessionClientId)) {
                        continue
                    }

                    const dapp = sessionToDApp(session)
                    dapps.push(dapp)
                }
            })
            return dapps
        }

        function resetModel() {
            root.clear()
            const dapps = d.getPersistedDapps()
            for (let i = 0; i < dapps.length; i++) {
                root.append(dapps[i])
            }
        }
    }

    Component.onCompleted: {
        d.resetModel()
    }
}
