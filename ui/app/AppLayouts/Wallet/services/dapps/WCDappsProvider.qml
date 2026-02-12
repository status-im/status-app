import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.services.dapps

import shared.stores

import utils

DAppsModel {
    id: root

    // Input
    required property WalletConnectSDKBase sdk
    required property DAppsStore store
    required property var supportedAccountsModel

    readonly property int connectorId: Constants.WalletConnect

    readonly property bool enabled: sdk.enabled

    signal disconnected(string topic, string dAppUrl)
    signal connected(string proposalId, string topic, string dAppUrl)

    Connections {
        target: root.sdk
        enabled: root.enabled

        function onSessionDelete(topic, err) {
            const dapp = root.getByTopic(topic)
            if (!dapp) {
                console.warn("DApp not found for topic - cannot delete session", topic)
                return
            }

            // Disconnect already handled by connector via ConnectorWCSDK.disconnectSession
            d.updateDappsModel()
            root.disconnected(topic, dapp.url)
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

            // Session already persisted by connector via ConnectorWCSDK.approveSession
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

                    const dAppsMap = {}
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
                        const existingDApp = dAppsMap[dapp.url]
                        if (existingDApp) {
                            // In Qt5.15.2 this is the way to make a "union" of two arrays
                            const combinedAddresses = new Set(existingDApp.accountAddresses.concat(accounts));
                            existingDApp.accountAddresses = Array.from(combinedAddresses);
                            existingDApp.rawSessions = [...existingDApp.rawSessions, session]
                        } else {
                            dapp.accountAddresses = accounts
                            dapp.topic = sessionID
                            dapp.rawSessions = [session]
                            dAppsMap[dapp.url] = dapp
                        }
                    }

                    root.clear();
                    for (const uri in dAppsMap) {
                        const dAppEntry = dAppsMap[uri];
                        dAppEntry.accountAddresses = dAppEntry.accountAddresses.filter(account => (!!account)).map(account => ({address: account}));
                        dAppEntry.connectorId = root.connectorId;
                        root.append(dAppEntry);
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
