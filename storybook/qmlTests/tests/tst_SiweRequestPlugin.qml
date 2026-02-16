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
        id: siweRequestPlugin

        SiweRequestPlugin {
            id: siwePlugin

            readonly property SignalSpy connectDAppSpy: SignalSpy { target: siwePlugin; signalName: "connectDApp" }
            readonly property SignalSpy registerSignRequestSpy: SignalSpy { target: siwePlugin; signalName: "registerSignRequest" }
            readonly property SignalSpy unregisterSignRequestSpy: SignalSpy { target: siwePlugin; signalName: "unregisterSignRequest" }
            readonly property SignalSpy siweSuccessfulSpy: SignalSpy { target: siwePlugin; signalName: "siweSuccessful" }
            readonly property SignalSpy siweFailedSpy: SignalSpy { target: siwePlugin; signalName: "siweFailed" }

            sdk: WalletConnectSDKBase {
                id: sdkMock

                projectId: "projectId"

                getActiveSessions: function(callback) {
                    callback({})
                }

                populateAuthPayload: function(id, payload, chains, methods) {
                    sdkMock.populateAuthPayloadResult(id, {}, "")
                }

                formatAuthMessage: function(id, request, iss) {
                    sdkMock.formatAuthMessageResult(id, {}, "")
                }

                acceptSessionAuthenticate: function(id, auths) {
                    sdkMock.acceptSessionAuthenticateResult(id, {}, "")
                }

                rejectSessionAuthenticate: function(id, error) {
                    sdkMock.rejectSessionAuthenticateResult(id, {}, "")
                }

                buildAuthObject: function(id, payload, signedData, account) {
                    sdkMock.buildAuthObjectResult(id, {}, "")
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
            accountsModel:  ListModel {
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

    // function buildSiweAuthPayload() {
    //     return {
    //         "aud":"https://appkit-lab.reown.com",
    //         "chains":["eip155:1","eip155:10","eip155:42161"],
    //         "domain":"appkit-lab.reown.com","iat":"2024-10-18T09:47:39.941Z",
    //         "nonce":"e2f9d65105e06be0b3a86a675cf90c7a28a8c6d9d0fb84c2a1187c15ef27f120",
    //         "resources":["urn:recap:eyJhdHQiOnsiZWlwMTU1Ijp7InJlcXVlc3QvZXRoX3NlbmRUcmFuc2FjdGlvbiI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnbiI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnblR5cGVkRGF0YSI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnblR5cGVkRGF0YV92NCI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9wZXJzb25hbF9zaWduIjpbeyJjaGFpbnMiOlsiZWlwMTU1OjEiLCJlaXAxNTU6MTAiLCJlaXAxNTU6NDIxNjEiXX1dfX19"],
    //         "statement":"Please sign with your account I further authorize the stated URI to perform the following actions on my behalf: (1) 'request': 'eth_sendTransaction', 'eth_sign', 'eth_signTypedData', 'eth_signTypedData_v4', 'personal_sign' for 'eip155'.",
    //         "type":"caip122",
    //         "version":"1"
    //         }
    // }

    // function formattedMessage() {
    //     return "appkit-lab.reown.com wants you to sign in with your Ethereum account:\n0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240\n\nPlease sign with your account I further authorize the stated URI to perform the following actions on my behalf: (1) 'request': 'eth_sendTransaction', 'eth_sign', 'eth_signTypedData', 'eth_signTypedData_v4', 'personal_sign' for 'eip155'.\n\nURI: https://appkit-lab.reown.com\nVersion: 1\nChain ID: 1\nNonce: e2f9d65105e06be0b3a86a675cf90c7a28a8c6d9d0fb84c2a1187c15ef27f120\nIssued At: 2024-10-18T09:47:39.941Z\nResources:\n- urn:recap:eyJhdHQiOnsiZWlwMTU1Ijp7InJlcXVlc3QvZXRoX3NlbmRUcmFuc2FjdGlvbiI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnbiI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnblR5cGVkRGF0YSI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9ldGhfc2lnblR5cGVkRGF0YV92NCI6W3siY2hhaW5zIjpbImVpcDE1NToxIiwiZWlwMTU1OjEwIiwiZWlwMTU1OjQyMTYxIl19XSwicmVxdWVzdC9wZXJzb25hbF9zaWduIjpbeyJjaGFpbnMiOlsiZWlwMTU1OjEiLCJlaXAxNTU6MTAiLCJlaXAxNTU6NDIxNjEiXX1dfX19"
    // }

    TestCase {
        id: siwePlugin
        name: "SiwePlugin"

        property SiweRequestPlugin componentUnderTest: null

        function init() {
            componentUnderTest = createTemporaryObject(siweRequestPlugin, root)
        }

        function test_NewValidRequest() {
            const request = buildSiweRequestMessage()
            const dAppUrl = request.params.requester.metadata.url
            const dAppName = request.params.requester.metadata.name
            const dAppIcon = request.params.requester.metadata.icons[0]
            const key = request.id

            componentUnderTest.sdk.sessionAuthenticateRequest(request)
            compare(componentUnderTest.connectDAppSpy.count, 1)
            compare(componentUnderTest.connectDAppSpy.signalArguments[0][0], [1, 10, 137, 324, 42161, 8453, 84532, 1301, 11155111, 100, 295])
            compare(componentUnderTest.connectDAppSpy.signalArguments[0][1], dAppUrl)
            compare(componentUnderTest.connectDAppSpy.signalArguments[0][2], dAppName)
            compare(componentUnderTest.connectDAppSpy.signalArguments[0][3], dAppIcon)
            compare(componentUnderTest.connectDAppSpy.signalArguments[0][4], key)
        }

        function test_ApproveNewRequest() {
            const request = buildSiweRequestMessage()
            const key = request.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]
            componentUnderTest.sdk.sessionAuthenticateRequest(request)
            componentUnderTest.connectionApproved(request.id, { eip155: { key, chains, accounts, methods }})
            compare(componentUnderTest.registerSignRequestSpy.count, 1)
            const requestObj = componentUnderTest.registerSignRequestSpy.signalArguments[0][0]
            requestObj.execute("pass", "pin")
            componentUnderTest.store.signingResult(request.topic, request.id, "data")
            tryCompare(componentUnderTest.siweSuccessfulSpy, "count", 1)
        }

        function test_RejectNewRequest() {
            const request = buildSiweRequestMessage()
            const key = request.id
            componentUnderTest.sdk.sessionAuthenticateRequest(request)
            componentUnderTest.connectionRejected(request.id)
            compare(componentUnderTest.unregisterSignRequestSpy.count, 1)
            tryCompare(componentUnderTest.siweFailedSpy, "count", 1)
        }

        function test_ApproveRequestExpired() {
            ignoreWarning(new RegExp(/^Error in SiweLifeCycle/))
            const request = buildSiweRequestMessage()
            const key = request.id
            request.params.expiryTimestamp = Date.now() / 1000 - 1
            componentUnderTest.sdk.sessionAuthenticateRequest(request)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
            tryCompare(componentUnderTest.siweFailedSpy, "count", 1)
        }

        function test_ApproveWrongKey() {
            const request = buildSiweRequestMessage()
            const key = request.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]
            componentUnderTest.sdk.sessionAuthenticateRequest(request)
            const ok = componentUnderTest.connectionApproved("wrongKey", { eip155: { key, chains, accounts, methods }})
            compare(ok, false)
        }

        function test_RejectWrongKey() {
            const request = buildSiweRequestMessage()
            const key = request.id
            componentUnderTest.sdk.sessionAuthenticateRequest(request)
            const ok = componentUnderTest.connectionRejected("wrongKey")
            compare(ok, false)
        }

        function test_DoubleRequests() {
            ignoreWarning(new RegExp(/^Error in SiweRequestPlugin/))
            const request = buildSiweRequestMessage()
            const key = request.id
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]

            componentUnderTest.sdk.sessionAuthenticateRequest(request)
            componentUnderTest.sdk.sessionAuthenticateRequest(request)

            componentUnderTest.connectionApproved(request.id, { eip155: { chains, accounts, methods }})
            compare(componentUnderTest.registerSignRequestSpy.count, 1)
        }

        function test_InvalidRequest() {
            ignoreWarning(new RegExp(/^Error in SiweRequestPlugin/))
            const request = {"someRandomData": ""}
            const chains = ["eip155:1", "eip155:10", "eip155:42161"]
            const accounts = ["eip155:1:0x1", "eip155:1:0x2"]
            const methods = ["eth_sendTransaction", "eth_sign", "eth_signTypedData", "eth_signTypedData_v4", "personal_sign"]

            componentUnderTest.sdk.sessionAuthenticateRequest(request)
            compare(componentUnderTest.registerSignRequestSpy.count, 0)
        }
    }
}