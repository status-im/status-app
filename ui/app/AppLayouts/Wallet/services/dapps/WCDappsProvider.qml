import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.services.dapps

import shared.stores

import utils

DAppsModel {
    id: root

    required property WalletConnectSDKBase sdk
    required property DAppsStore store
    required property var supportedAccountsModel

    readonly property int connectorId: Constants.WalletConnect
    readonly property string clientId: "walletconnect"

    readonly property bool enabled: sdk.enabled

    signal disconnected(string dAppUrl)
    signal connected(string proposalId, string topic, string dAppUrl)

    Connections {
        target: root.sdk
        enabled: root.enabled

        function onDisconnected(url, err) {
            if (err) {
                console.warn("Error disconnecting dApp:", url, err)
            }

            d.updateDappsModel()
            root.disconnected(url)
        }
        function onSdkInit(success, result) {
            if (!success) {
                return
            }
            d.updateDappsModel()
        }
        function onApproveSessionResult(proposalId, session, error) {
            if (error) {
                return
            }

            d.updateDappsModel()
            root.connected(proposalId, session.topic, session.peer.metadata.url)
        }

        function onAcceptSessionAuthenticateResult(id, result, error) {
            if (error) {
                return
            }
            d.updateDappsModel()
            root.connected(id, result.topic, result.session.peer.metadata.url)
        }
    }

    Component.onCompleted: {
        if (!enabled) {
            return
        }
        // Just in case the SDK is already initialized
        d.updateDappsModel()
    }

    onEnabledChanged: {
        if (enabled) {
            d.updateDappsModel()
        } else {
            d.dappsModel.clear()
        }
    }

    SQUtils.QObject {
        id: d

        function updateDappsModel()
        {
            function refreshFromConnector() {
                sdk.getActiveSessions((allSessionsAllProfiles) => {
                    if (!allSessionsAllProfiles) {
                        console.warn("Failed to get active sessions")
                        return
                    }

                    root.clear();
                    
                    const sessions = DAppsHelpers.filterActiveSessionsForKnownAccounts(allSessionsAllProfiles, root.supportedAccountsModel)
                    for (const sessionID in sessions) {
                        const session = sessions[sessionID]
                        const dapp = session.peer.metadata
                        if (!!dapp.icons && dapp.icons.length > 0) {
                            dapp.iconUrl = dapp.icons[0]
                        } else {
                            dapp.iconUrl = ""
                        }
                        const accounts = DAppsHelpers.getAccountsInSession(session)
                        dapp.accountAddresses = accounts.filter(account => (!!account)).map(account => ({address: account}))
                        dapp.topic = sessionID
                        dapp.rawSessions = [session]
                        dapp.connectorId = root.connectorId
                        dapp.clientId = root.clientId
                        root.append(dapp)
                    }
                });
            }

            if (root.sdk.sdkReady) {
                refreshFromConnector()
            } else {
                function onSdkReady() {
                    if (root.sdk.sdkReady) {
                        root.sdk.sdkReadyChanged.disconnect(onSdkReady)
                        refreshFromConnector()
                    }
                }
                root.sdk.sdkReadyChanged.connect(onSdkReady)
            }
        }
    }
}
