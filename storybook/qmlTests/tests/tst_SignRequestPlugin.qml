import QtQuick
import QtTest

import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.plugins
import AppLayouts.Wallet.services.dapps.types

import shared.stores
import utils

Item {
    id: root

    Component {
        id: signRequestPluginComponent
        SignRequestPlugin {
            id: plugin
            property SignalSpy acceptedSpy: SignalSpy { target: plugin; signalName: "accepted" }
            property SignalSpy rejectedSpy: SignalSpy { target: plugin; signalName: "rejected" }
            property SignalSpy signCompletedSpy: SignalSpy { target: plugin; signalName: "signCompleted" }

            sdk: WalletConnectSDKBase {
                id: sdk
                enabled: true
                projectId: ""
                property bool sdkReady: true

                property var getActiveSessionsCallbacks: []
                getActiveSessions: function(callback) {
                    getActiveSessionsCallbacks.push({callback})
                }

                property var acceptSessionRequestCalls: []
                acceptSessionRequest: function(topic, id, signature) {
                    acceptSessionRequestCalls.push({topic, id, signature})
                }

                property var rejectSessionRequestCalls: []
                rejectSessionRequest: function(topic, id, error) {
                    rejectSessionRequestCalls.push({topic, id, error})
                }
            }
            store: DAppsStore {
                controller: QtObject {}
                id: dappsStore

                signal userAuthenticated(string topic, string id, string password, string pin, string payload)
                signal userAuthenticationFailed(string topic, string id)
                signal signingResult(string topic, string id, string data)

                signal estimatedTimeResponse(string topic, int timeCategory, bool success)
                signal suggestedFeesResponse(string topic, var suggestedFeesJsonObj, bool success)
                signal estimatedGasResponse(string topic, string gasEstimate, bool success)

                function hexToDec(hex) {
                    return parseInt(hex, 16)
                }

                function getEstimatedTime() {
                    return Constants.TransactionEstimatedTime.LessThanThreeMins
                }

                function convertFeesInfoToHex(feesInfo) {
                    return null
                }

                property var mockedSuggestedFees: ({
                    gasPrice: 2.0,
                    baseFee: 5.0,
                    maxPriorityFeePerGas: 2.0,
                    maxFeePerGasL: 1.0,
                    maxFeePerGasM: 1.1,
                    maxFeePerGasH: 1.2,
                    l1GasFee: 0.0,
                    eip1559Enabled: true
                })
                function getSuggestedFees() {
                    return mockedSuggestedFees
                }

                property var authenticateUserCalls: []
                function authenticateUser(topic, id, address) {
                    authenticateUserCalls.push({topic, id, address})
                }

                property var signMessageCalls: []
                function signMessage(topic, id, address, message, password, pin) {
                    signMessageCalls.push({topic, id, address, password, pin})
                }

                property var signMessageUnsafeCalls: []
                function signMessageUnsafe(topic, id, address, data, password, pin) {
                    signMessageUnsafeCalls.push({topic, id, address, data, password, pin})
                }

                property var safeSignTypedDataCalls: []
                function safeSignTypedData(topic, id, address, message, chainId, legacy, password, pin) {
                    safeSignTypedDataCalls.push({topic, id, address, message, chainId, legacy, password, pin})
                }

                property var signTransactionCalls: []
                function signTransaction(topic, id, address, chainId, txObj, password, pin) {
                    signTransactionCalls.push({topic, id, address, chainId, txObj, password, pin})
                }

                property var sendTransactionCalls: []
                function sendTransaction(topic, id, address, chainID, txObj, password, pin) {
                    sendTransactionCalls.push({topic, id, address, chainID, txObj, password, pin})
                }
            }
            dappsModel: ListModel {
                id: dappsModel
            }
            groupedAccountAssetsModel: ListModel {
                id: groupedAccountAssetsModel
            }
            networksModel: ListModel {
                id: networksModel
                ListElement {
                    chainId: 1
                    layer: 1
                }
            }
            accountsModel: ListModel {
                id: accountsModel
                ListElement {
                    address: "0x123"
                }
            }
            requests: SessionRequestsModel {}
            fiatSymbol: "USD"
            getFiatValue: (balance, cryptoSymbol) => {
                return parseFloat(balance)
            }
        }
    }

    TestCase {
        id: signRequestPluginTest

        property SignRequestPlugin componentUnderTest: null

        function populateDAppData(topic) {
            const dapp = {
                topic,
                name: "Example",
                url: "https://example.com",
                iconUrl: "https://example.com/icon.png",
                connectorId: 0,
                accountAddresses: [{address: "0x123"}],
                rawSessions: [{session: {topic}}]
            }
            componentUnderTest.dappsModel.append(dapp)
        }

        function executeRequest(signEvent) {
            populateDAppData(signEvent.topic)
            componentUnderTest.sdk.sessionRequestEvent(signEvent)
            // Execute the request
            const request = componentUnderTest.requests.get(0)
            request.requestItem.execute("passowrd", "pin")

            componentUnderTest.store.signingResult(signEvent.topic, signEvent.id, "result")
            compare(componentUnderTest.sdk.acceptSessionRequestCalls.length, 1, "Accept session request should be called")
            compare(componentUnderTest.sdk.acceptSessionRequestCalls[0].signature, "result", "Accept session request should be called with the correct signature")
            compare(componentUnderTest.sdk.acceptSessionRequestCalls[0].topic.toString(), signEvent.topic.toString(), "Accept session request should be called with the correct topic")
            compare(componentUnderTest.sdk.acceptSessionRequestCalls[0].id.toString(), signEvent.id.toString(), "Accept session request should be called with the correct id")

            compare(componentUnderTest.acceptedSpy.count, 1, "Accepted signal should be emitted") 
        }

        function init() {
            componentUnderTest = createTemporaryObject(signRequestPluginComponent, root)
        }

        function test_signMessage() {
            const signEvent = {"id":1730896110928724,"params":{"chainId":"eip155:1","request":{"method":"personal_sign","params":["0x4578616d706c652060706572736f6e616c5f7369676e60206d657373616765","0x123","Example password"]}},"topic":"43a74a4c6c71e3ab67ef80283dc43f392445642c8dce3dabe63f89ab83cfcfc3","verifyContext":{"verified":{"origin":"https://metamask.github.io/test-dapp/","validation":"UNKNOWN","verifyUrl":"https://verify.walletconnect.org"}}}
            // Case 1: DApp not found
            ignoreWarning(`Error finding dapp for topic ${signEvent.topic} id ${signEvent.id}`)
            componentUnderTest.sdk.sessionRequestEvent(signEvent)
            compare(componentUnderTest.sdk.rejectSessionRequestCalls.length, 1, "Reject session request should not be called")

            // Case 2: DApp found
            executeRequest(signEvent)
            compare(componentUnderTest.store.signMessageCalls.length, 1, "Sign message should be called")
            componentUnderTest.sdk.sessionRequestUserAnswerResult(signEvent.topic, signEvent.id, true, null)

            const requestItem = componentUnderTest.requests.get(0).requestItem
            compare(requestItem.requestId, signEvent.id.toString(), "Request id should be set")
            compare(requestItem.topic, signEvent.topic.toString(), "Topic should be set")
            compare(requestItem.method, signEvent.params.request.method, "Method should be set")
            compare(requestItem.accountAddress, signEvent.params.request.params[1], "Account address should be set")
            compare(requestItem.chainId, signEvent.params.chainId.split(':').pop().trim(), "Chain id should be set")
            compare(requestItem.sourceId, componentUnderTest.dappsModel.get(0).connectorId, "Source id should be set")

            compare(componentUnderTest.signCompletedSpy.count, 1, "Sign completed signal should be emitted")
        }

        function test_signMessageUnsafe() {
            const signEvent = {"id":1730896224189361,"params":{"chainId":"eip155:1","request":{"method":"eth_sign","params":["0x123","0x123"]}},"topic":"43a74a4c6c71e3ab67ef80283dc43f392445642c8dce3dabe63f89ab83cfcfc3","verifyContext":{"verified":{"origin":"https://metamask.github.io/test-dapp/","validation":"UNKNOWN","verifyUrl":"https://verify.walletconnect.org"}}}

            executeRequest(signEvent)

            compare(componentUnderTest.store.signMessageUnsafeCalls.length, 1, "Sign message unsafe should be called")
            componentUnderTest.sdk.sessionRequestUserAnswerResult(signEvent.topic, signEvent.id, true, null)

            compare(componentUnderTest.signCompletedSpy.count, 1, "Sign completed signal should be emitted")
        }

        function test_safeSignTypedData() {
            const signEvent = {"id":1730896495619543,"params":{"chainId":"eip155:1","request":{"method":"eth_signTypedData_v4","params":["0x123","{\"domain\":{\"chainId\":\"1\",\"name\":\"Ether Mail\",\"verifyingContract\":\"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC\",\"version\":\"1\"},\"message\":{\"contents\":\"Hello, Bob!\",\"from\":{\"name\":\"Cow\",\"wallets\":[\"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826\",\"0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF\"]},\"to\":[{\"name\":\"Bob\",\"wallets\":[\"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB\",\"0xB0BdaBea57B0BDABeA57b0bdABEA57b0BDabEa57\",\"0xB0B0b0b0b0b0B000000000000000000000000000\"]}],\"attachment\":\"0x\"},\"primaryType\":\"Mail\",\"types\":{\"EIP712Domain\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"version\",\"type\":\"string\"},{\"name\":\"chainId\",\"type\":\"uint256\"},{\"name\":\"verifyingContract\",\"type\":\"address\"}],\"Group\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"members\",\"type\":\"Person[]\"}],\"Mail\":[{\"name\":\"from\",\"type\":\"Person\"},{\"name\":\"to\",\"type\":\"Person[]\"},{\"name\":\"contents\",\"type\":\"string\"},{\"name\":\"attachment\",\"type\":\"bytes\"}],\"Person\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"wallets\",\"type\":\"address[]\"}]}}"]}},"topic":"43a74a4c6c71e3ab67ef80283dc43f392445642c8dce3dabe63f89ab83cfcfc3","verifyContext":{"verified":{"origin":"https://metamask.github.io/test-dapp/","validation":"UNKNOWN","verifyUrl":"https://verify.walletconnect.org"}}}

            executeRequest(signEvent)

            compare(componentUnderTest.store.safeSignTypedDataCalls.length, 1, "Safe sign typed data should be called")
            componentUnderTest.sdk.sessionRequestUserAnswerResult(signEvent.topic, signEvent.id, true, null)

            compare(componentUnderTest.signCompletedSpy.count, 1, "Sign completed signal should be emitted")
        }

        function test_sendTransaction() {
            const signEvent = {"id":1730899979094571,"params":{"chainId":"eip155:1","request":{"method":"eth_sendTransaction","params":[{"from":"0x123","gasLimit":"0x5028","maxFeePerGas":"0x2540be400","maxPriorityFeePerGas":"0x3b9aca00","to":"0x0c54FcCd2e384b4BB6f2E405Bf5Cbc15a017AaFb","value":"0x0"}]}},"topic":"147fa9ddffcf9d782b5e002eb36b041e43a1db2bad79a598da6926105ce6680f","verifyContext":{"verified":{"origin":"https://metamask.github.io/test-dapp/","validation":"UNKNOWN","verifyUrl":"https://verify.walletconnect.org"}}}
            
            executeRequest(signEvent)

            compare(componentUnderTest.store.sendTransactionCalls.length, 1, "Send transaction should be called")
            componentUnderTest.sdk.sessionRequestUserAnswerResult(signEvent.topic, signEvent.id, true, null)

            compare(componentUnderTest.signCompletedSpy.count, 1, "Sign completed signal should be emitted")
        }

        function reject_sign() {
            const signEvent = {"id":1730896495619543,"params":{"chainId":"eip155:1","request":{"method":"eth_signTypedData_v4","params":["0x123","{\"domain\":{\"chainId\":\"1\",\"name\":\"Ether Mail\",\"verifyingContract\":\"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC\",\"version\":\"1\"},\"message\":{\"contents\":\"Hello, Bob!\",\"from\":{\"name\":\"Cow\",\"wallets\":[\"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826\",\"0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF\"]},\"to\":[{\"name\":\"Bob\",\"wallets\":[\"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB\",\"0xB0BdaBea57B0BDABeA57b0bdABEA57b0BDabEa57\",\"0xB0B0b0b0b0b0B000000000000000000000000000\"]}],\"attachment\":\"0x\"},\"primaryType\":\"Mail\",\"types\":{\"EIP712Domain\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"version\",\"type\":\"string\"},{\"name\":\"chainId\",\"type\":\"uint256\"},{\"name\":\"verifyingContract\",\"type\":\"address\"}],\"Group\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"members\",\"type\":\"Person[]\"}],\"Mail\":[{\"name\":\"from\",\"type\":\"Person\"},{\"name\":\"to\",\"type\":\"Person[]\"},{\"name\":\"contents\",\"type\":\"string\"},{\"name\":\"attachment\",\"type\":\"bytes\"}],\"Person\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"wallets\",\"type\":\"address[]\"}]}}"]}},"topic":"43a74a4c6c71e3ab67ef80283dc43f392445642c8dce3dabe63f89ab83cfcfc3","verifyContext":{"verified":{"origin":"https://metamask.github.io/test-dapp/","validation":"UNKNOWN","verifyUrl":"https://verify.walletconnect.org"}}}
            populateDAppData(signEvent.topic)
            componentUnderTest.sdk.sessionRequestEvent(signEvent)
            // Execute the request
            const request = componentUnderTest.requests.get(0)
            request.requestItem.rejected(false)

            compare(componentUnderTest.sdk.rejectSessionRequestCalls.length, 1, "Reject session request should be called")
            compare(componentUnderTest.rejectedSpy.count, 1, "Rejected signal should be emitted")
            compare(componentUnderTest.signCompletedSpy.count, 0, "Sign completed signal should not be emitted")
        }

        function test_authFailed() {
            const signEvent = {"id":1730896495619543,"params":{"chainId":"eip155:1","request":{"method":"eth_signTypedData_v4","params":["0x123","{\"domain\":{\"chainId\":\"1\",\"name\":\"Ether Mail\",\"verifyingContract\":\"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC\",\"version\":\"1\"},\"message\":{\"contents\":\"Hello, Bob!\",\"from\":{\"name\":\"Cow\",\"wallets\":[\"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826\",\"0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF\"]},\"to\":[{\"name\":\"Bob\",\"wallets\":[\"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB\",\"0xB0BdaBea57B0BDABeA57b0bdABEA57b0BDabEa57\",\"0xB0B0b0b0b0b0B000000000000000000000000000\"]}],\"attachment\":\"0x\"},\"primaryType\":\"Mail\",\"types\":{\"EIP712Domain\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"version\",\"type\":\"string\"},{\"name\":\"chainId\",\"type\":\"uint256\"},{\"name\":\"verifyingContract\",\"type\":\"address\"}],\"Group\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"members\",\"type\":\"Person[]\"}],\"Mail\":[{\"name\":\"from\",\"type\":\"Person\"},{\"name\":\"to\",\"type\":\"Person[]\"},{\"name\":\"contents\",\"type\":\"string\"},{\"name\":\"attachment\",\"type\":\"bytes\"}],\"Person\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"wallets\",\"type\":\"address[]\"}]}}"]}},"topic":"43a74a4c6c71e3ab67ef80283dc43f392445642c8dce3dabe63f89ab83cfcfc3","verifyContext":{"verified":{"origin":"https://metamask.github.io/test-dapp/","validation":"UNKNOWN","verifyUrl":"https://verify.walletconnect.org"}}}
            populateDAppData(signEvent.topic)
            componentUnderTest.sdk.sessionRequestEvent(signEvent)
            // Execute the request
            const request = componentUnderTest.requests.get(0)

            request.requestItem.authFailed()
            compare(componentUnderTest.sdk.rejectSessionRequestCalls.length, 1, "Reject session request should be called")
            compare(componentUnderTest.rejectedSpy.count, 1, "Rejected signal should be emitted")
            compare(componentUnderTest.signCompletedSpy.count, 0, "Sign completed signal should not be emitted")
        }

        function test_signMessageFails() {
            const signEvent = {"id":1730896495619543,"params":{"chainId":"eip155:1","request":{"method":"eth_signTypedData_v4","params":["0x123","{\"domain\":{\"chainId\":\"1\",\"name\":\"Ether Mail\",\"verifyingContract\":\"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC\",\"version\":\"1\"},\"message\":{\"contents\":\"Hello, Bob!\",\"from\":{\"name\":\"Cow\",\"wallets\":[\"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826\",\"0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF\"]},\"to\":[{\"name\":\"Bob\",\"wallets\":[\"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB\",\"0xB0BdaBea57B0BDABeA57b0bdABEA57b0BDabEa57\",\"0xB0B0b0b0b0b0B000000000000000000000000000\"]}],\"attachment\":\"0x\"},\"primaryType\":\"Mail\",\"types\":{\"EIP712Domain\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"version\",\"type\":\"string\"},{\"name\":\"chainId\",\"type\":\"uint256\"},{\"name\":\"verifyingContract\",\"type\":\"address\"}],\"Group\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"members\",\"type\":\"Person[]\"}],\"Mail\":[{\"name\":\"from\",\"type\":\"Person\"},{\"name\":\"to\",\"type\":\"Person[]\"},{\"name\":\"contents\",\"type\":\"string\"},{\"name\":\"attachment\",\"type\":\"bytes\"}],\"Person\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"wallets\",\"type\":\"address[]\"}]}}"]}},"topic":"43a74a4c6c71e3ab67ef80283dc43f392445642c8dce3dabe63f89ab83cfcfc3","verifyContext":{"verified":{"origin":"https://metamask.github.io/test-dapp/","validation":"UNKNOWN","verifyUrl":"https://verify.walletconnect.org"}}}
            
            populateDAppData(signEvent.topic)
            componentUnderTest.sdk.sessionRequestEvent(signEvent)
            // Execute the request
            const request = componentUnderTest.requests.get(0)
            request.requestItem.execute("passowrd", "pin")

            componentUnderTest.store.signingResult(signEvent.topic, signEvent.id, "")
            compare(componentUnderTest.sdk.rejectSessionRequestCalls.length, 1, "Reject session request should be called")
            compare(componentUnderTest.rejectedSpy.count, 1, "Rejected signal should be emitted")
            compare(componentUnderTest.signCompletedSpy.count, 0, "Sign completed signal should not be emitted")
        }
    }
}