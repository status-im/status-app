import QtQuick
import QtTest

import StatusQ.Core.Utils

import AppLayouts.Profile.views.wallet

import Models
import utils

Item {
    id: root
    width: 600
    height: 900

    readonly property string mainRpcUrl: "https://mainnet.mynode.io/1/"
    readonly property string failoverRpcUrl: "https://mainnet.mynode.io/2/"

    ListModel {
        id: rpcProvidersModel
        Component.onCompleted: {
            append([
                {
                    chainId: NetworksModel.mainnetChainId,
                    name: "User Mainnet #1",
                    url: root.mainRpcUrl,
                    isEnabled: true,
                    providerType: Constants.rpcProviderTypes.user
                },
                {
                    chainId: NetworksModel.mainnetChainId,
                    name: "User Mainnet #2",
                    url: root.failoverRpcUrl,
                    isEnabled: true,
                    providerType: Constants.rpcProviderTypes.user
                }
            ])
        }
    }

    QtObject {
        id: networksModuleStub
        signal chainIdFetchedForUrl(string url, int chainId, bool success, bool isMainUrl)
    }

    property var networkRPCChanged: ({})
    property bool autoRespondEnabled: false
    property bool autoRespondSuccess: true
    property int autoRespondChainId: NetworksModel.mainnetChainId
    property var activePopup: null

    Component {
        id: componentUnderTest
        EditNetworkForm {
            width: root.width
            network: ModelUtils.getByKey(NetworksModel.flatNetworks, "chainId", NetworksModel.mainnetChainId)
            rpcProviders: rpcProvidersModel
            networksModule: networksModuleStub
            networkRPCChanged: root.networkRPCChanged
        }
    }

    Connections {
        target: Global
        function onOpenPopupRequested(popupComponent, params) {
            if (root.activePopup)
                root.activePopup.destroy()
            root.activePopup = popupComponent.createObject(root, params || {})
            if (root.activePopup)
                root.activePopup.open()
        }
    }

    SignalSpy {
        id: evaluateSpy
        signalName: "evaluateRpcEndPoint"
    }

    SignalSpy {
        id: updateSpy
        signalName: "updateNetworkValues"
    }

    TestCase {
        name: "EditNetworkView"
        when: windowShown

        property var controlUnderTest: null

        function init() {
            root.networkRPCChanged = ({})
            root.autoRespondEnabled = false
            root.autoRespondSuccess = true
            root.autoRespondChainId = NetworksModel.mainnetChainId
            destroyPopup()
            evaluateSpy.clear()
            updateSpy.clear()
        }

        function cleanup() {
            destroyPopup()
            controlUnderTest = null
        }

        function destroyPopup() {
            if (root.activePopup) {
                root.activePopup.close()
                root.activePopup.destroy()
                root.activePopup = null
            }
        }

        function createForm() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            evaluateSpy.target = controlUnderTest
            updateSpy.target = controlUnderTest
            controlUnderTest.evaluateRpcEndPoint.connect(function(url, isMainUrl) {
                if (root.autoRespondEnabled)
                    networksModuleStub.chainIdFetchedForUrl(url, root.autoRespondChainId,
                                                            root.autoRespondSuccess, isMainUrl)
            })
            waitForRendering(controlUnderTest)
            return controlUnderTest
        }

        function mainRpcInput() { return findChild(controlUnderTest, "mainRpcInputObject") }
        function saveButton() { return findChild(controlUnderTest, "editNetworkSaveButton") }
        function ackCheckbox() { return findChild(controlUnderTest, "editNetworkAknowledgmentCheckbox") }

        function waitForEvaluate() {
            tryCompare(evaluateSpy, "count", 1, 2000)
        }

        function test_initialState() {
            createForm()

            const fields = [
                ["editNetworkNameInput", "Mainnet"],
                ["editNetworkShortNameInput", "eth"],
                ["editNetworkChainIdInput", String(NetworksModel.mainnetChainId)],
                ["editNetworkSymbolInput", "ETH"],
                ["editNetworkExplorerInput", "https://etherscan.io/"]
            ]
            for (let i = 0; i < fields.length; ++i) {
                const edit = findChild(controlUnderTest, fields[i][0])
                verify(!!edit)
                compare(edit.text, fields[i][1])
                verify(!edit.enabled)
            }

            tryCompare(mainRpcInput(), "text", root.mainRpcUrl)
            tryCompare(findChild(controlUnderTest, "failoverRpcUrlInputObject"), "text", root.failoverRpcUrl)

            compare(ackCheckbox().text, qsTr("I understand that changing network settings can cause unforeseen issues, errors, security risks and potentially even loss of funds."))
            verify(!ackCheckbox().checked)
            verify(!saveButton().enabled)
        }

        function test_invalidUrl() {
            createForm()
            mainRpcInput().text = "not-a-url"
            tryCompare(mainRpcInput().errorMessageCmp, "text",
                       qsTr("What is %1? This isn’t a URL 😒").arg("not-a-url"), 2000)
            compare(evaluateSpy.count, 0)
            verify(!saveButton().enabled)
        }

        function test_pingUnsuccessful() {
            createForm()
            root.autoRespondEnabled = true
            root.autoRespondSuccess = false

            mainRpcInput().text = "https://google.com"
            waitForEvaluate()
            tryCompare(mainRpcInput().errorMessageCmp, "text",
                       qsTr("RPC appears to be either offline or this is not a valid JSON RPC endpoint URL"), 2000)
            verify(!saveButton().enabled)
        }

        function test_notSameChain() {
            createForm()
            root.autoRespondEnabled = true
            root.autoRespondChainId = 999

            mainRpcInput().text = "https://example.com/rpc"
            waitForEvaluate()
            tryCompare(mainRpcInput().errorMessageCmp, "text",
                       qsTr("Chain ID returned from JSON RPC doesn’t match %1").arg("Mainnet"), 2000)
        }

        function test_verifiedAckAndSaveLater() {
            createForm()
            root.autoRespondEnabled = true

            const newUrl = "https://new-mainnet.example.com/"
            mainRpcInput().text = newUrl
            waitForEvaluate()
            tryCompare(mainRpcInput().errorMessageCmp, "text", qsTr("RPC successfully reached"), 2000)

            verify(!saveButton().enabled)
            mouseClick(ackCheckbox())
            tryCompare(saveButton(), "enabled", true)

            mouseClick(saveButton())
            tryCompare(root.activePopup, "opened", true)

            mouseClick(findChild(root.activePopup, "laterButton"))
            tryCompare(updateSpy, "count", 1)
            compare(updateSpy.signalArguments[0][0], NetworksModel.mainnetChainId)
            compare(updateSpy.signalArguments[0][1], newUrl)
            compare(updateSpy.signalArguments[0][2], root.failoverRpcUrl)
        }
    }
}
