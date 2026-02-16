import QtQuick

import QtTest

import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.plugins

import shared.stores

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: siweLifeCycleComponent
        SiweLifeCycle {
            id: siweLifeCycle
            readonly property SignalSpy startedSpy: SignalSpy { target: siweLifeCycle; signalName: "started" }
            readonly property SignalSpy finishedSpy: SignalSpy { target: siweLifeCycle; signalName: "finished" }
            readonly property SignalSpy requestSessionApprovalSpy: SignalSpy { target: siweLifeCycle; signalName: "requestSessionApproval" }
            readonly property SignalSpy registerSignRequestSpy: SignalSpy { target: siweLifeCycle; signalName: "registerSignRequest" }
            readonly property SignalSpy unregisterSignRequestSpy: SignalSpy { target: siweLifeCycle; signalName: "unregisterSignRequest" }

            sdk: WalletConnectSDKBase {
                id: sdkMock

                projectId: "projectId"

                property var getActiveSessionCalls: []
                getActiveSessions: function(callback) {
                    getActiveSessionCalls.push(callback)
                }

                property var populateAuthPayloadCalls: []
                populateAuthPayload: function(id, payload, chains, methods) {
                    populateAuthPayloadCalls.push({id, payload, chains, methods})
                }

                property var formatAuthMessageCalls: []
                formatAuthMessage: function(id, request, iss) {
                    formatAuthMessageCalls.push({id, request, iss})
                }

                property var acceptSessionAuthenticateCalls: []
                acceptSessionAuthenticate: function(id, auths) {
                    acceptSessionAuthenticateCalls.push({id, auths})
                }

                property var rejectSessionAuthenticateCalls: []
                rejectSessionAuthenticate: function(id, error) {
                    rejectSessionAuthenticateCalls.push({id, error})
                }

                property var buildAuthObjectCalls: []
                buildAuthObject: function(id, payload, signedData, account) {
                    buildAuthObjectCalls.push({id, payload, signedData, account})
                }
            }
            store: DAppsStore {
                controller: QtObject {}
                id: dappsStoreMock
                signal userAuthenticated(string topic, string id, string password, string pin)
                signal userAuthenticationFailed(string topic, string id)
                signal signingResult(string topic, string id, string data)

                property var authenticateUserCalls: []
                function authenticateUser(topic, id, address) {
                    authenticateUserCalls.push({topic, id, address})
                }

                property var signMessageCalls: []
                function signMessage(topic, id, address, data, password, pin) {
                    signMessageCalls.push({topic, id, address, data, password, pin})
                }
            }
            request: buildSiweRequestMessage()
            accountsModel: ListModel {
                ListElement { address: "0x1" }
                ListElement { address: "0x2" }
            }
            networksModel: ListModel {
                ListElement { chainId: 1 }
                ListElement { chainId: 2 }
            }
        }
    }

    function buildSiweRequestMessage() {
        const timestamp = Date.now() / 1000 + 1000
        return {
            "id":1729244859941412,
            "params": {
                "authPayload": {
                    "aud":"https://appkit-lab.reown.com",
                    "chains":["eip155:1","eip155:10","eip155:137","eip155:324","eip155:42161","eip155:8453","eip155:84532","eip155:1301","eip155:11155111","eip155:100","eip155:295"],
                    "domain":"appkit-lab.reown.com",
                    "iat":"2024-10-18T09:47:39.941Z",
                    "nonce":"e2f9d65105e06be0b3a86a675cf90c7a28a8c6d9d0fb84c2a1187c15ef27f120",
                    "resources":["urn:recap:eyJhdHQiOnsiZWlwMTU1Ijp7InJlcXVlc3QvZXRoX2FjY291bnRzIjpbe31dLCJyZXF1ZXN0L2V0aF9yZXF1ZXN0QWNjb3VudHMiOlt7fV0sInJlcXVlc3QvZXRoX3NlbmRSYXdUcmFuc2FjdGlvbiI6W3t9XSwicmVxdWVzdC9ldGhfc2VuZFRyYW5zYWN0aW9uIjpbe31dLCJyZXF1ZXN0L2V0aF9zaWduIjpbe31dLCJyZXF1ZXN0L2V0aF9zaWduVHJhbnNhY3Rpb24iOlt7fV0sInJlcXVlc3QvZXRoX3NpZ25UeXBlZERhdGEiOlt7fV0sInJlcXVlc3QvZXRoX3NpZ25UeXBlZERhdGFfdjMiOlt7fV0sInJlcXVlc3QvZXRoX3NpZ25UeXBlZERhdGFfdjQiOlt7fV0sInJlcXVlc3QvcGVyc29uYWxfc2lnbiI6W3t9XSwicmVxdWVzdC93YWxsZXRfYWRkRXRoZXJldW1DaGFpbiI6W3t9XSwicmVxdWVzdC93YWxsZXRfZ2V0Q2FsbHNTdGF0dXMiOlt7fV0sInJlcXVlc3Qvd2FsbGV0X2dldENhcGFiaWxpdGllcyI6W3t9XSwicmVxdWVzdC93YWxsZXRfZ2V0UGVybWlzc2lvbnMiOlt7fV0sInJlcXVlc3Qvd2FsbGV0X2dyYW50UGVybWlzc2lvbnMiOlt7fV0sInJlcXVlc3Qvd2FsbGV0X3JlZ2lzdGVyT25ib2FyZGluZyI6W3t9XSwicmVxdWVzdC93YWxsZXRfcmVxdWVzdFBlcm1pc3Npb25zIjpbe31dLCJyZXF1ZXN0L3dhbGxldF9zY2FuUVJDb2RlIjpbe31dLCJyZXF1ZXN0L3dhbGxldF9zZW5kQ2FsbHMiOlt7fV0sInJlcXVlc3Qvd2FsbGV0X3N3aXRjaEV0aGVyZXVtQ2hhaW4iOlt7fV0sInJlcXVlc3Qvd2FsbGV0X3dhdGNoQXNzZXQiOlt7fV19fX0"],
                    "statement":"Please sign with your account",
                    "type":"caip122",
                    "version":"1"
                },
                "expiryTimestamp": timestamp,
                "requester": {
                    "metadata": {
                        "description":"Explore the AppKit Lab to test the latest AppKit features.",
                        "icons":["https://appkit-lab.reown.com/favicon.svg"],
                        "name":"AppKit Lab",
                        "url":"https://appkit-lab.reown.com"
                    },
                    "publicKey":"205aeb6376a2d79e8b0fa02aa8123473a7822a30ea3dc9d7be9b3de4e31e9f2b"
                }
            },
            "topic":"c525f017208ca3b4ad53928c16bab48d03af42c6cd47608c5fd73703bf5700bb",
            "verifyContext": {
                "verified": {
                    "isScam":null,
                    "origin":"https://appkit-lab.reown.com",
                    "validation":"VALID",
                    "verifyUrl":"https://verify.walletconnect.org"
                }
            }
        }
    }

    function buildSiweAuthPayload() {
        return {
            "aud":"https://appkit-lab.reown.com",
            "chains":["eip155:1","eip155:10","eip155:42161"],
            "domain":"appkit-lab.reown.com","iat":"2024-10-18T09:47:39.941Z",
            "nonce":"e2f9d65105e06be0b3a86a675cf90c7a28a8c6d9d0fb84c2a1187c15ef27f120",
            "resources":["urn:recap:eyJhdHQiOnsiZWlwMTU1Ijp7InJlcXVlc3QvZXRoX3NlbmRUcmFuc2FjdGlvbiI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnbiI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnblR5cGVkRGF0YSI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnblR5cGVkRGF0YV92NCI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9wZXJzb25hbF9zaWduIjpbeyJjaGFpbnMiOlsiZWlwMTU1OjEiLCJlaXAxNTU6MTAiLCJlaXAxNTU6NDIxNjEiXX1dfX19"],
            "statement":"Please sign with your account I further authorize the stated URI to perform the following actions on my behalf: (1) 'request': 'eth_sendTransaction', 'eth_sign', 'eth_signTypedData', 'eth_signTypedData_v4', 'personal_sign' for 'eip155'.",
            "type":"caip122",
            "version":"1"
            }
    }

    function formattedMessage() {
        return "appkit-lab.reown.com wants you to sign in with your Ethereum account:\n0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240\n\nPlease sign with your account I further authorize the stated URI to perform the following actions on my behalf: (1) 'request': 'eth_sendTransaction', 'eth_sign', 'eth_signTypedData', 'eth_signTypedData_v4', 'personal_sign' for 'eip155'.\n\nURI: https://appkit-lab.reown.com\nVersion: 1\nChain ID: 1\nNonce: e2f9d65105e06be0b3a86a675cf90c7a28a8c6d9d0fb84c2a1187c15ef27f120\nIssued At: 2024-10-18T09:47:39.941Z\nResources:\n- urn:recap:eyJhdHQiOnsiZWlwMTU1Ijp7InJlcXVlc3QvZXRoX3NlbmRUcmFuc2FjdGlvbiI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnbiI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnblR5cGVkRGF0YSI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnblR5cGVkRGF0YV92NCI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9wZXJzb25hbF9zaWduIjpbeyJjaGFpbnMiOlsiZWlwMTU1OjEiLCJlaXAxNTU6MTAiLCJlaXAxNTU6NDIxNjEiXX1dfX19"
    }

    TestCase {
        id: siweLifeCycleTest
        name: "SiweLifeCycle"

        property SiweLifeCycle componentUnderTest: null

        function init() {
            componentUnderTest = createTemporaryObject(siweLifeCycleComponent, root)
        }

        function test_EndToEndSuccessful() {
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)
            compare(componentUnderTest.requestSessionApprovalSpy.count, 0)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 0)

            // Step 1: Get the active sessions from the SDK
            compare(componentUnderTest.sdk.getActiveSessionCalls.length, 1)
            componentUnderTest.sdk.getActiveSessionCalls[0]({})

            // Step 2: Request chains and accounts approval
            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 0)

            const key = requestEvent.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]
            componentUnderTest.sessionApproved(key, { eip155: {
                chains,
                accounts,
                methods
            }})
            
            // Step 3: Populate the auth payload
            compare(componentUnderTest.sdk.populateAuthPayloadCalls.length, 1)
            verify(componentUnderTest.sdk.populateAuthPayloadCalls[0].id == key)
            compare(componentUnderTest.sdk.populateAuthPayloadCalls[0].payload, requestEvent.params.authPayload)
            compare(componentUnderTest.sdk.populateAuthPayloadCalls[0].chains, chains)
            compare(componentUnderTest.sdk.populateAuthPayloadCalls[0].methods, methods)
            // No extra event is sent
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)
            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 0)

            // Step 4: Format the auth message
            const authPayload = buildSiweAuthPayload()
            componentUnderTest.sdk.populateAuthPayloadResult(key, authPayload, "")
            compare(componentUnderTest.sdk.formatAuthMessageCalls.length, 1)
            verify(componentUnderTest.sdk.formatAuthMessageCalls[0].id == key)
            compare(componentUnderTest.sdk.formatAuthMessageCalls[0].request, authPayload)
            compare(componentUnderTest.sdk.formatAuthMessageCalls[0].iss, "eip155:1:0x1")
            // No extra event is sent
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)
            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 0)

            // Step 5: Accept the session authentication and sign the message
            componentUnderTest.sdk.formatAuthMessageResult(key, formattedMessage(), "")
            compare(componentUnderTest.registerSignRequestSpy.count, 1)
            // No extra event is sent
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)
            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 0)

            const request = componentUnderTest.registerSignRequestSpy.signalArguments[0][0]
            verify(!!request)
            request.execute("password", "pin")
            compare(componentUnderTest.store.signMessageCalls.length, 1)
            componentUnderTest.store.signingResult(requestEvent.topic, requestEvent.id, "signedData")

            // Step 6: Build the response
            compare(componentUnderTest.sdk.buildAuthObjectCalls.length, 1)
            verify(componentUnderTest.sdk.buildAuthObjectCalls[0].id == key)
            compare(componentUnderTest.sdk.buildAuthObjectCalls[0].payload, authPayload)
            compare(componentUnderTest.sdk.buildAuthObjectCalls[0].signedData, "signedData")
            compare(componentUnderTest.sdk.buildAuthObjectCalls[0].account, "eip155:1:0x1")
            
            componentUnderTest.sdk.buildAuthObjectResult(key, "authObject", "")

            // Step 7: Accept the session authentication
            compare(componentUnderTest.sdk.acceptSessionAuthenticateCalls.length, 1)
            verify(componentUnderTest.sdk.acceptSessionAuthenticateCalls[0].id == key)
            compare(componentUnderTest.sdk.acceptSessionAuthenticateCalls[0].auths, ["authObject"])
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)

            // Step 8: Finish the process
            componentUnderTest.sdk.acceptSessionAuthenticateResult(key, "", "")
            compare(componentUnderTest.finishedSpy.count, 1)
        }

        function test_StartExpired() {
            ignoreWarning(new RegExp(/^Error in SiweLifeCycle/))
            const expiredRequest = buildSiweRequestMessage()
            expiredRequest.params.expiryTimestamp = Date.now() / 1000 - 1
            componentUnderTest.request = expiredRequest

            componentUnderTest.start()
            compare(componentUnderTest.startedSpy.count, 0)
            compare(componentUnderTest.finishedSpy.count, 1)
            compare(componentUnderTest.requestSessionApprovalSpy.count, 0)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 1)
            compare(componentUnderTest.sdk.getActiveSessionCalls.length, 0)
            compare(componentUnderTest.sdk.populateAuthPayloadCalls.length, 0)
            compare(componentUnderTest.sdk.formatAuthMessageCalls.length, 0)
            compare(componentUnderTest.sdk.buildAuthObjectCalls.length, 0)
            compare(componentUnderTest.sdk.acceptSessionAuthenticateCalls.length, 0)
        }

        function test_StartWithExistingSession() {
            ignoreWarning(new RegExp(/^Error in SiweLifeCycle/))
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)
            compare(componentUnderTest.requestSessionApprovalSpy.count, 0)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 0)

            // Step 1: Get the active sessions from the SDK
            // return an existing session with the same topic
            compare(componentUnderTest.sdk.getActiveSessionCalls.length, 1)
            componentUnderTest.sdk.getActiveSessionCalls[0]({ [requestEvent.topic]: { }})
            compare(componentUnderTest.finishedSpy.count, 1)
        }

        function test_StartWithInvalidSession() {
            // regex to check if the warning starts with "Error in SiweLifeCycle"
            ignoreWarning(new RegExp(/^Error in SiweLifeCycle/))
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)
            compare(componentUnderTest.requestSessionApprovalSpy.count, 0)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 0)

            // Step 1: Get the active sessions from the SDK
            // return an existing session with the same topic
            compare(componentUnderTest.sdk.getActiveSessionCalls.length, 1)
            componentUnderTest.sdk.getActiveSessionCalls[0]("invalidresponse")
            compare(componentUnderTest.finishedSpy.count, 1)
        }

        function test_StartWithInvalidRequest() {
            // regex to check if the warning starts with "Error in SiweLifeCycle"
            ignoreWarning(new RegExp(/^Error in SiweLifeCycle/))
            componentUnderTest.request = {}
            componentUnderTest.start()
            compare(componentUnderTest.startedSpy.count, 0)
            compare(componentUnderTest.finishedSpy.count, 1)
            compare(componentUnderTest.requestSessionApprovalSpy.count, 0)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 1)
            compare(componentUnderTest.sdk.getActiveSessionCalls.length, 0)
        }

        function test_RejectedSessionApproval() {
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            componentUnderTest.sdk.getActiveSessionCalls[0]({})

            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)

            const key = requestEvent.id
            componentUnderTest.sessionRejected(key)
            compare(componentUnderTest.finishedSpy.count, 1)
        }

        function test_RejectSign() {
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            componentUnderTest.sdk.getActiveSessionCalls[0]({})

            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)

            const key = requestEvent.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]
            componentUnderTest.sessionApproved(key, { eip155: {
                chains,
                accounts,
                methods
            }})
            componentUnderTest.sdk.populateAuthPayloadResult(key, buildSiweAuthPayload(), "")
            componentUnderTest.sdk.formatAuthMessageResult(key, formattedMessage(), "")
            const request = componentUnderTest.registerSignRequestSpy.signalArguments[0][0]
            request.reject(false)
            compare(componentUnderTest.finishedSpy.count, 1)
        }

        function test_AuthenticationFails() {
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            componentUnderTest.sdk.getActiveSessionCalls[0]({})

            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)

            const key = requestEvent.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]
            componentUnderTest.sessionApproved(key, { eip155: {
                chains,
                accounts,
                methods
            }})
            componentUnderTest.sdk.populateAuthPayloadResult(key, buildSiweAuthPayload(), "")
            componentUnderTest.sdk.formatAuthMessageResult(key, formattedMessage(), "")
            const request = componentUnderTest.registerSignRequestSpy.signalArguments[0][0]
            request.reject(false)
            componentUnderTest.store.userAuthenticationFailed(requestEvent.topic, requestEvent.id)
            compare(componentUnderTest.finishedSpy.count, 1)
        }

        function test_InvalidPopulatedAuthPayload() {
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            componentUnderTest.sdk.getActiveSessionCalls[0]({})

            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)

            const key = requestEvent.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]
            componentUnderTest.sessionApproved(key, { eip155: {
                chains,
                accounts,
                methods
            }})
            componentUnderTest.sdk.populateAuthPayloadResult(key, undefined, "")
            compare(componentUnderTest.finishedSpy.count, 1)
        }

        function test_invalidFormatAuthMessage() {
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            componentUnderTest.sdk.getActiveSessionCalls[0]({})

            compare(componentUnderTest.requestSessionApprovalSpy.count, 1)
            compare(componentUnderTest.startedSpy.count, 1)
            compare(componentUnderTest.finishedSpy.count, 0)

            const key = requestEvent.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]
            componentUnderTest.sessionApproved(key, { eip155: {
                chains,
                accounts,
                methods
            }})
            componentUnderTest.sdk.populateAuthPayloadResult(key, buildSiweAuthPayload(), "")
            componentUnderTest.sdk.formatAuthMessageResult(key, undefined, "")
            compare(componentUnderTest.finishedSpy.count, 1)
        }

        function test_CallsWithDifferentId() {
            const requestEvent = componentUnderTest.request
            componentUnderTest.start()
            componentUnderTest.sdk.getActiveSessionCalls[0]({})
            const key = requestEvent.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]
            // wrong key
            componentUnderTest.sessionApproved(key + 1, { eip155: {
                chains,
                accounts,
                methods
            }})
            compare(componentUnderTest.sdk.populateAuthPayloadCalls.length, 0)
            //correct key
            componentUnderTest.sessionApproved(key, { eip155: {
                chains,
                accounts,
                methods
            }})
            compare(componentUnderTest.sdk.populateAuthPayloadCalls.length, 1)

            // wrong key
            componentUnderTest.sdk.populateAuthPayloadResult(key + 1, buildSiweAuthPayload(), "")
            compare(componentUnderTest.sdk.formatAuthMessageCalls.length, 0)
            // correct key
            componentUnderTest.sdk.populateAuthPayloadResult(key, buildSiweAuthPayload(), "")
            compare(componentUnderTest.sdk.formatAuthMessageCalls.length, 1)

            // wrong key
            componentUnderTest.sdk.formatAuthMessageResult(key + 1, formattedMessage(), "")
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            // correct key
            componentUnderTest.sdk.formatAuthMessageResult(key, formattedMessage(), "")
            compare(componentUnderTest.registerSignRequestSpy.count, 1)

            const request = componentUnderTest.registerSignRequestSpy.signalArguments[0][0]
            request.execute("password", "pin")

            // wrong key
            componentUnderTest.store.signingResult(requestEvent.topic, requestEvent.id + 1, "signedData")
            compare(componentUnderTest.sdk.buildAuthObjectCalls.length, 0)
            // correct key
            componentUnderTest.store.signingResult(requestEvent.topic, requestEvent.id, "signedData")
            compare(componentUnderTest.sdk.buildAuthObjectCalls.length, 1)

            // wrong key
            componentUnderTest.sdk.buildAuthObjectResult(key + 1, "authObject", "")
            compare(componentUnderTest.sdk.acceptSessionAuthenticateCalls.length, 0)
            // correct key
            componentUnderTest.sdk.buildAuthObjectResult(key, "authObject", "")
            compare(componentUnderTest.sdk.acceptSessionAuthenticateCalls.length, 1)

            // wrong key
            componentUnderTest.sdk.acceptSessionAuthenticateResult(key + 1, "", "")
            compare(componentUnderTest.finishedSpy.count, 0)
            // correct key
            componentUnderTest.sdk.acceptSessionAuthenticateResult(key, "", "")
            compare(componentUnderTest.finishedSpy.count, 1)
        }
    }
}