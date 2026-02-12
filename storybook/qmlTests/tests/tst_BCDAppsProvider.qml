import QtQuick
import QtTest

import AppLayouts.Wallet.services.dapps

Item {
    id: root

    Component {
        id: bcDAppsProviderComponent
        BCDappsProvider {
            id: bcDAppsProvider
            readonly property SignalSpy connectedSpy: SignalSpy { target: bcDAppsProvider; signalName: "connected" }
            readonly property SignalSpy disconnectedSpy: SignalSpy { target: bcDAppsProvider; signalName: "disconnected" }
            bcSDK: WalletConnectSDKBase {
                enabled: true
                projectId: ""
                property var activeSessions: {}
                getActiveSessions: function(callback) {
                    callback(activeSessions)
                }
            }
        }
    }

    function buildSession(dappUrl, dappName, dappIcon, proposalId, account, chains) {
        let sessionTemplate = (dappUrl, dappName, dappIcon, proposalId, eipAccount, eipChains) => {
            return {
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
            };
        }

        const eipAccount = account ? `eip155:${account}` : ""
        const eipChains = chains ? chains.map((chain) => `eip155:${chain}`) : []

        return sessionTemplate(dappUrl, dappName, dappIcon, proposalId, eipAccount, eipChains)
    }

    TestCase {
        id: bcDAppsProviderTest

        property BCDappsProvider componentUnderTest: null
        function init() {
            componentUnderTest = createTemporaryObject(bcDAppsProviderComponent, root)
        }

        function test_addRemoveSession() {
            const newSession = buildSession("https://example.com", "Example", "https://example.com/icon.png", "123", "0x123", ["1"])
            componentUnderTest.bcSDK.approveSessionResult("requestID", newSession, null)

            compare(componentUnderTest.connectedSpy.count, 1, "Connected signal should be emitted once")
            compare(componentUnderTest.connectedSpy.signalArguments[0][0], "requestID", "Connected signal should have correct proposalId")
            compare(componentUnderTest.connectedSpy.signalArguments[0][1], "https://example.com", "Connected signal should have correct topic")
            compare(componentUnderTest.connectedSpy.signalArguments[0][2], "https://example.com", "Connected signal should have correct dAppUrl")

            const dapp = componentUnderTest.getByTopic("https://example.com")
            verify(!!dapp, "DApp should be found")
            compare(dapp.name, "Example", "DApp should have correct name")
            compare(dapp.url, "https://example.com", "DApp should have correct url")
            compare(dapp.iconUrl, "https://example.com/icon.png", "DApp should have correct iconUrl")
            compare(dapp.topic, "https://example.com", "DApp should have correct topic")
            compare(dapp.connectorId, componentUnderTest.connectorId, "DApp should have correct connectorId")
            compare(dapp.accountAddresses.count, 1, "DApp should have correct accountAddresses count")
            compare(dapp.accountAddresses.get(0).address, "0x123", "DApp should have correct accountAddresses address")
            compare(dapp.rawSessions.count, 1, "DApp should have correct rawSessions count")

            componentUnderTest.bcSDK.disconnected("https://example.com", "")
            compare(componentUnderTest.disconnectedSpy.count, 1, "Disconnected signal should be emitted once")
            compare(componentUnderTest.disconnectedSpy.signalArguments[0][0], "https://example.com", "Disconnected signal should have correct dAppUrl")
        }

        function test_disabledSDK() {
            componentUnderTest.bcSDK.enabled = false
            componentUnderTest.bcSDK.approveSessionResult("requestID", buildSession("https://example.com", "Example", "https://example.com/icon.png", "123", "0x123", ["1"]), "")
            compare(componentUnderTest.connectedSpy.count, 0, "Connected signal should not be emitted")
            componentUnderTest.bcSDK.disconnected("https://example.com", "")
            compare(componentUnderTest.disconnectedSpy.count, 0, "Disconnected signal should not be emitted")
        }
    }
}