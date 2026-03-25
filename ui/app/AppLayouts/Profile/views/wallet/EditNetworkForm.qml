import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Popups

import QtModelsToolkit
import SortFilterProxyModel

import shared.panels
import utils

ColumnLayout {
    id: root

    property var network
    property var rpcProviders
    property var networksModule
    property var networkRPCChanged
    signal evaluateRpcEndPoint(string url, bool isMainUrl)
    signal updateNetworkValues(int chainId, string newMainRpcInput, string newFailoverRpcUrl)

    enum EvaluationState {
        UnTouched,
        Pending,
        Verified,
        InvalidURL,
        PingUnsuccessful,
        SameAsOther,
        NotSameChain,
        Empty,
        RestartRequired
    }

    QtObject {
        id: d

        readonly property SortFilterProxyModel userRpcProvidersModel: SortFilterProxyModel {
            sourceModel: root.rpcProviders
            filters: [
                ValueFilter { roleName: "chainId"; value: root.network.chainId },
                ValueFilter { roleName: "providerType"; value: Constants.rpcProviderTypes.user }
            ]
        }
        readonly property int userRpcProvidersModelCount: d.userRpcProvidersModel.ModelCount.count ?? 0

        property var mainRpcProvider
        readonly property string mainRpcProviderUrl: !!d.mainRpcProvider ? d.mainRpcProvider.url : ""
        property var fallbackRpcProvider
        readonly property string fallbackRpcProviderUrl: !!d.fallbackRpcProvider ? d.fallbackRpcProvider.url : ""

        function fetchProviders() {
            mainRpcProvider = d.userRpcProvidersModelCount > 0 ? ModelUtils.get(d.userRpcProvidersModel, 0) : undefined
            fallbackRpcProvider = d.userRpcProvidersModelCount > 1 ? ModelUtils.get(d.userRpcProvidersModel, 1) : undefined
        }

        onUserRpcProvidersModelCountChanged: d.fetchProviders()    
        Component.onCompleted: d.fetchProviders()

        property int evaluationStatusMainRpc: EditNetworkForm.UnTouched
        property int evaluationStatusFallBackRpc: EditNetworkForm.UnTouched
        property var evaluateRpcEndPoint: Backpressure.debounce(root, 400, function (value, isMainUrl) {
            if(!Utils.isURL(value)) {
                if(isMainUrl)
                    d.evaluationStatusMainRpc = EditNetworkForm.InvalidURL
                else
                    d.evaluationStatusFallBackRpc = EditNetworkForm.InvalidURL
                return
            }
            root.evaluateRpcEndPoint(value, isMainUrl)
        })

        function getUrlStatusText(status, text) {
            switch(status) {
            case EditNetworkForm.Pending:
                return qsTr("Checking RPC...")
            case EditNetworkForm.InvalidURL:
                return qsTr("What is %1? This isn’t a URL 😒").arg(text)
            case EditNetworkForm.PingUnsuccessful:
                return  qsTr("RPC appears to be either offline or this is not a valid JSON RPC endpoint URL")
            case EditNetworkForm.Verified:
                return qsTr("RPC successfully reached")
            case EditNetworkForm.SameAsOther:
                return qsTr("JSON RPC URLs are the same")
            case EditNetworkForm.NotSameChain:
                return qsTr("Chain ID returned from JSON RPC doesn’t match %1").arg(network.chainName)
            case EditNetworkForm.RestartRequired:
                return qsTr("Restart required for changes to take effect")
            default: return ""
            }
        }

        function getErrorMessageColor(status) {
            switch(status) {
            case EditNetworkForm.Pending:
                return Theme.palette.baseColor1
            case EditNetworkForm.SameAsOther:
            case EditNetworkForm.NotSameChain:
            case EditNetworkForm.RestartRequired:
                return  Theme.palette.warningColor1
            case EditNetworkForm.Verified:
                return Theme.palette.successColor1
            default: return Theme.palette.dangerColor1
            }
        }

        function getErrorMessageAlignment(status) {
            switch(status) {
            case EditNetworkForm.Pending:
            case EditNetworkForm.Verified:
            case EditNetworkForm.SameAsOther:
            case EditNetworkForm.NotSameChain:
            case EditNetworkForm.RestartRequired:
                return  Text.AlignLeft
            default: return Text.AlignRight
            }
        }

        function save() {
            if (d.evaluationStatusMainRpc == EditNetworkForm.UnTouched && d.evaluationStatusFallBackRpc == EditNetworkForm.UnTouched) {
                return
            }

            let main = mainRpcInput.text
            let fallback = failoverRpcUrlInput.text
            root.updateNetworkValues(network.chainId, main, fallback)
            root.networkRPCChanged[network.chainId] = true
        }
    }

    Connections {
        target: networksModule
        function onChainIdFetchedForUrl(url, chainId, success, isMainUrl) {
            let status = EditNetworkForm.PingUnsuccessful
            if(success) {
                if (network.chainId !== chainId) {
                    status = EditNetworkForm.NotSameChain
                }
                else if((isMainUrl && url === network.fallbackURL) ||
                        (!isMainUrl && url === network.rpcURL)) {
                  status = EditNetworkForm.SameAsOther
                }
                else
                    status = EditNetworkForm.Verified
            }
            if(isMainUrl)
                d.evaluationStatusMainRpc = status
            else
                d.evaluationStatusFallBackRpc = status
        }
    }

    spacing: 20

    StatusInput {
        Layout.fillWidth: true
        label: qsTr("Network name")
        input.edit.objectName: "editNetworkNameInput"
        text: !!network ? network.chainName : ""
        input.enabled: false
    }

    StatusInput {
        Layout.fillWidth: true
        label: qsTr("Short name")
        input.edit.objectName: "editNetworkShortNameInput"
        text: !!network ? network.shortName : ""
        input.enabled: false
    }

    StatusInput {
        Layout.fillWidth: true
        input.edit.objectName: "editNetworkChainIdInput"
        label: qsTr("Chain ID")
        text: !!network ? network.chainId : ""
        input.enabled: false
    }

    StatusInput {
        Layout.fillWidth: true
        input.edit.objectName: "editNetworkSymbolInput"
        label: qsTr("Native Token Symbol")
        text: !!network ? network.nativeCurrencySymbol : ""
        input.enabled: false
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: childrenRect.height
        StatusInput {
            id: mainRpcInput
            objectName: "mainRpcInputObject"
            input.edit.objectName: "editNetworkMainRpcInput"
            width: parent.width
            label: qsTr("User JSON RPC URL #1")
            text: d.mainRpcProviderUrl
            onTextChanged: {
                if (text === "") {
                    d.evaluationStatusMainRpc = EditNetworkForm.Empty
                    return
                } else {
                    if (d.mainRpcProviderUrl === text) {
                        d.evaluationStatusMainRpc = EditNetworkForm.UnTouched
                        if (root.networkRPCChanged[network.chainId]) {
                            d.evaluationStatusMainRpc = EditNetworkForm.RestartRequired
                        }
                    } else {
                        d.evaluationStatusMainRpc = EditNetworkForm.Pending
                        Qt.callLater(d.evaluateRpcEndPoint, text, true);
                    }
                }
            }
            errorMessageCmp.horizontalAlignment: d.getErrorMessageAlignment(d.evaluationStatusMainRpc)
            errorMessageCmp.visible: d.evaluationStatusMainRpc !== EditNetworkForm.UnTouched

            errorMessageCmp.color: d.getErrorMessageColor(d.evaluationStatusMainRpc)
            errorMessageCmp.text: d.getUrlStatusText(d.evaluationStatusMainRpc, text)
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: childrenRect.height
        StatusInput {
            id: failoverRpcUrlInput
            objectName: "failoverRpcUrlInputObject"
            input.edit.objectName: "editNetworkFailoverRpcUrlInput"
            width: parent.width
            label: qsTr("User JSON RPC URL #2")
            text: d.fallbackRpcProviderUrl
            onTextChanged: {
                if (text === "") {
                    d.evaluationStatusFallBackRpc = EditNetworkForm.Empty
                    return
                }

                if (d.fallbackRpcProviderUrl === text) {
                    d.evaluationStatusFallBackRpc = EditNetworkForm.UnTouched
                    if (root.networkRPCChanged[network.chainId]) {
                        d.evaluationStatusFallBackRpc = EditNetworkForm.RestartRequired
                    }
                } else {
                    d.evaluationStatusFallBackRpc = EditNetworkForm.Pending
                    Qt.callLater(d.evaluateRpcEndPoint, text, false);
                }
            }
            errorMessageCmp.horizontalAlignment: d.getErrorMessageAlignment(d.evaluationStatusFallBackRpc)
            errorMessageCmp.visible: d.evaluationStatusFallBackRpc !== EditNetworkForm.UnTouched
            errorMessageCmp.text: d.getUrlStatusText(d.evaluationStatusFallBackRpc, text)
            errorMessageCmp.color: d.getErrorMessageColor(d.evaluationStatusFallBackRpc)
        }
    }

    StatusInput {
        input.edit.objectName: "editNetworkExplorerInput"
        Layout.fillWidth: true
        label: qsTr("Block Explorer")
        text: !!network ? network.blockExplorerURL : ""
        input.enabled: false
    }

    StatusCheckBox {
        id: warningCheckbox
        objectName: "editNetworkAknowledgmentCheckbox"
        Layout.fillWidth: true
        text: qsTr("I understand that changing network settings can cause unforeseen issues, errors, security risks and potentially even loss of funds.")
        checkState: Qt.Unchecked
        font.pixelSize: Theme.primaryTextFontSize
    }

    Separator {}

    Row {
        Layout.alignment: Qt.AlignRight
        StatusButton {
            objectName: "editNetworkSaveButton"
            text: qsTr("Save Changes")
            enabled: (
                d.evaluationStatusMainRpc === EditNetworkForm.Verified ||
                d.evaluationStatusFallBackRpc === EditNetworkForm.Verified ||
                d.evaluationStatusMainRpc === EditNetworkForm.SameAsOther ||
                d.evaluationStatusFallBackRpc === EditNetworkForm.SameAsOther ||
                d.evaluationStatusMainRpc === EditNetworkForm.Empty ||
                d.evaluationStatusFallBackRpc === EditNetworkForm.Empty ||
                d.evaluationStatusMainRpc === EditNetworkForm.NotSameChain ||
                d.evaluationStatusFallBackRpc === EditNetworkForm.NotSameChain ||
                d.evaluationStatusMainRpc === EditNetworkForm.RestartRequired ||
                d.evaluationStatusFallBackRpc === EditNetworkForm.RestartRequired
                ) && warningCheckbox.checked

            onClicked: {
                Global.openPopup(confirmationDialogComponent)
            }
        }
    }

    Component {
        id: confirmationDialogComponent
        StatusModal {
            headerSettings.title: qsTr("RPC URL change requires app restart")
            contentItem: Item {
                width: parent.width
                implicitHeight: childrenRect.height
                Column {
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter

                    Item {
                        width: parent.width
                        height: 16
                    }

                    StatusBaseText {
                        objectName: "mustBeRestartedText"
                        text: qsTr("For new JSON RPC URLs to take effect, Status must be restarted. Are you ready to do this now?")
                        font.pixelSize: Theme.primaryTextFontSize
                        anchors.left: parent.left
                        anchors.right: parent.right
                        wrapMode: Text.WordWrap
                        color: Theme.palette.directColor1
                    }

                    Item {
                        width: parent.width
                        height: 16
                    }
                }
            }

            rightButtons: [
                StatusFlatButton {
                    id: laterButton
                    objectName: "laterButton"
                    text: qsTr("Save and restart later")
                    type: StatusBaseButton.Type.Normal
                    onClicked: {
                        close()
                        d.save()
                        d.evaluationStatusMainRpc = EditNetworkForm.RestartRequired
                    }
                },
                StatusButton {
                    id: saveButton
                    objectName: "saveButton"
                    type: StatusBaseButton.Type.Normal
                    text: qsTr("Save and restart Status")
                    focus: true
                    Keys.onReturnPressed: function(event) {
                        saveButton.clicked()
                    }
                    onClicked: {
                        close()
                        d.save()
                        Qt.exit(0)
                    }
                }
            ]
        }
    }
}
