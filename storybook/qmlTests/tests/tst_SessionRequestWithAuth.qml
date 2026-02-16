import QtQuick

import QtTest

import AppLayouts.Wallet.services.dapps.types

import shared.stores

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: sessionRequestComponent

        SessionRequestWithAuth {
            id: sessionRequest
            readonly property SignalSpy executeSpy: SignalSpy { target: sessionRequest; signalName: "execute" }
            readonly property SignalSpy rejectedSpy: SignalSpy { target: sessionRequest; signalName: "rejected" }
            readonly property SignalSpy authFailedSpy: SignalSpy { target: sessionRequest; signalName: "authFailed" }

            // SessionRequestResolved required properties
            // Not of interest for this test
            event: "event"
            topic: "topic"
            requestId: "id"
            method: "method"
            accountAddress: "address"
            chainId: "chainID"
            sourceId: 0
            data: "data"
            preparedData: "preparedData"
            dappUrl: "dappUrl"
            dappIcon: "dappIcon"
            dappName: "dappName"
            store: DAppsStore {
                controller: QtObject {}
                signal userAuthenticated(string topic, string id, string password, string pin)
                signal userAuthenticationFailed(string topic, string id)

                property var authenticateUserCalls: []
                function authenticateUser(topic, id, address) {
                    authenticateUserCalls.push({topic, id, address})
                }
            }
        }
    }

    TestCase {
        id: sessionRequestTest
        name: "SessionRequestWithAuth"
        // Ensure mocked GroupedAccountsAssetsModel is properly initialized
        when: windowShown

        property SessionRequestWithAuth componentUnderTest: null

        function init() {
            componentUnderTest = createTemporaryObject(sessionRequestComponent, root)
        }

        function test_acceptAndAuthenticated() {
            componentUnderTest.accept()
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 0)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 1)

            componentUnderTest.store.userAuthenticated("topic", "id", "password", "pin")
            
            compare(componentUnderTest.executeSpy.count, 1)
            compare(componentUnderTest.rejectedSpy.count, 0)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 1)
        }

        function test_AcceptAndAuthFails() {
            componentUnderTest.accept()
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 0)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 1)

            componentUnderTest.store.userAuthenticationFailed("topic", "id")
            
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.authFailedSpy.count, 1)
            compare(componentUnderTest.store.authenticateUserCalls.length, 1)
        }

        function test_AcceptRequestExpired() {
            ignoreWarning("Error: request expired")
            componentUnderTest.expirationTimestamp = Date.now() / 1000 - 1
            componentUnderTest.accept()
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 1)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 0)
        }

        function test_AcceptAndReject() {
            componentUnderTest.accept()
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 0)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 1)

            componentUnderTest.reject(false)
            
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 1)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 1)
        }

        function test_AcceptAndExpiresAfterAuth() {
            ignoreWarning("Error: request expired")
            componentUnderTest.accept()
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 0)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 1)

            componentUnderTest.expirationTimestamp = Date.now() / 1000 - 1
            componentUnderTest.store.userAuthenticated("topic", "id", "password", "pin")
            
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 1)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 1)
        }

        function test_Reject() {
            componentUnderTest.reject(false)
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 1)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 0)
        }

        function test_RejectExpiredRequest() {
            componentUnderTest.expirationTimestamp = Date.now() / 1000 - 1
            componentUnderTest.reject(false)
            compare(componentUnderTest.executeSpy.count, 0)
            compare(componentUnderTest.rejectedSpy.count, 1)
            compare(componentUnderTest.authFailedSpy.count, 0)
            compare(componentUnderTest.store.authenticateUserCalls.length, 0)
        }
    }
}