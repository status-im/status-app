import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet
import AppLayouts.Wallet.services.dapps
import AppLayouts.Wallet.services.dapps.types
import shared.popups.walletconnect

import SortFilterProxyModel
import utils

import "types"

SQUtils.QObject {
    id: root

    required property DAppsModule dappsModule
    required property string selectedAddress
    required property var accountsModel

    property bool walletConnectFeatureEnabled: true
    property bool connectorFeatureEnabled: true

    // Output properties
    /// Model contaning all dApps available for the currently selected account
    readonly property var dappsModel: d.filteredDappsModel
    /// Model containig the dApps session requests to be resolved by the user
    readonly property SessionRequestsModel sessionRequestsModel: dappsModule.requestsModel
    /// Service can interact with the current address selection
    /// Default value: true
    readonly property bool serviceAvailableToCurrentAddress: !root.selectedAddress ||
                SQUtils.ModelUtils.contains(root.accountsModel, "address", root.selectedAddress, Qt.CaseInsensitive)

    readonly property bool isServiceOnline: dappsModule.isServiceOnline

    // signals
    signal connectDApp(var dappChains, url dappUrl, string dappName, url dappIcon, string connectorIcon, string key)
    // Emitted as a response to DAppsService.approveSession
    // @param key The key of the session proposal
    // @param error The error message
    // @param topic The new topic of the session
    signal approveSessionResult(string key, var error, string topic)
    // Emitted when a new session is requested by a dApp
    signal sessionRequest(string id)
    // Emitted when the services requests to display a toast message
    // @param message The message to display
    // @param type The type of the message. Maps to Constants.ephemeralNotificationType
    signal displayToastMessage(string message, int type)
    // Emitted as a response to DAppsService.validatePairingUri or other DAppsService.pair
    // and DAppsService.approvePair errors
    signal pairingValidated(int validationState)

    // methods
    /// Triggers the signing process for the given session request
    /// @param topic The topic of the session
    /// @param id The id of the session request
    function sign(topic, id) {
        // The authentication triggers the signing process
        // authenticate -> sign -> inform the dApp
        d.sign(topic, id)
    }

    function rejectSign(topic, id, hasError) {
        d.rejectSign(topic, id, hasError)
    }

    function signRequestIsLive(topic, id) {
        d.signRequestIsLive(topic, id)
    }

    /// Validates the pairing URI
    function validatePairingUri(uri) {
        timeoutTimer.start()
        d.validatePairingUri(uri)
    }

    /// Initiates the pairing process with the given URI
    function pair(uri) {
        timeoutTimer.start()
        dappsModule.pair(uri)
    }

    /// Approves or rejects the session proposal
    function approvePairSession(key, approvedChainIds, accountAddress) {
        dappsModule.approvePairSession(key, approvedChainIds, accountAddress)
    }


    /// Rejects the session proposal
    function rejectPairSession(id) {
        dappsModule.rejectPairSession(id)
    }

    /// Disconnects the dApp with the given topic/URL
    /// @param topic The topic (for WC) or URL (for BC)
    /// @param url The URL of the dApp
    /// @param connectorId The connector type (Constants.DAppConnectors.WalletConnect or Constants.DAppConnectors.StatusConnect)
    /// @param clientId The clientId for BC sessions (e.g. "status-desktop/dapp-browser" for browser connections)
    function disconnect(topic, url, connectorId, clientId) {
        dappsModule.disconnect(topic, url, connectorId, clientId || "")
    }

    SQUtils.QObject {
        id: d

        readonly property var filteredDappsModel: SortFilterProxyModel {
            id: dappsFilteredModel
            objectName: "DAppsModelFiltered"
            sourceModel: root.dappsModule.dappsModel
            readonly property string selectedAddress: root.selectedAddress
            readonly property var connectorIcons: Constants.dappImageByType

            proxyRoles: [
                FastExpressionRole {
                    name: "connectorBadge"
                    expression: dappsFilteredModel.connectorIcons[connectorId]
                    expectedRoles: "connectorId"
                }
            ]
            filters: FastExpressionFilter {
                enabled: !!dappsFilteredModel.selectedAddress

                function isAddressIncluded(accountAddressesSubModel, selectedAddress) {
                    if (!accountAddressesSubModel) {
                        return false
                    }
                    const addresses = SQUtils.ModelUtils.modelToFlatArray(accountAddressesSubModel, "address")
                    return addresses.includes(selectedAddress)
                }
                expression: isAddressIncluded(model.accountAddresses, dappsFilteredModel.selectedAddress)

                expectedRoles: "accountAddresses"
            }
        }

        function validatePairingUri(uri) {
            // Check if emoji inside the URI
            if(Constants.regularExpressions.emoji.test(uri)) {
                root.pairingValidated(Pairing.errors.tooCool)
                return
            } else if(!DAppsHelpers.validURI(uri)) {
                root.pairingValidated(Pairing.errors.invalidUri)
                return
            }

            dappsModule.validatePairingUri(uri)
        }

        function signRequestIsLive(topic, id) {
            const request = root.sessionRequestsModel.findRequest(topic, id)
            if (!request) {
                console.error("Session request not found")
                return
            }
            request.setActive()
        }
        
        function sign(topic, id) {
            const request = root.sessionRequestsModel.findRequest(topic, id)
            if (!request) {
                console.error("Session request not found")
                return
            }
            request.accept()
        }

        function rejectSign(topic, id, hasError) {
            const request = root.sessionRequestsModel.findRequest(topic, id)
            if (!request) {
                console.error("Session request not found")
                return
            }
            request.reject(hasError)
        }

        function reportPairErrorState(state) {
            timeoutTimer.stop()
            root.pairingValidated(state)
        }
    }

    Connections {
        target: root.dappsModule
        enabled: root.walletConnectFeatureEnabled || root.connectorFeatureEnabled
        function onPairingValidated(state) {
            timeoutTimer.stop()
            root.pairingValidated(state)
        }

        function onPairingResponse(state) {
            if (state != Pairing.errors.uriOk) {
                d.reportPairErrorState(state)
                return
            }

            timeoutTimer.restart()
        }

        function onConnectDApp(dappChains, dappUrl, dappName, dappIcon, connectorId, key) {
            timeoutTimer.stop()
            const connectorIcon = Constants.dappImageByType[connectorId]
            root.connectDApp(dappChains, dappUrl, dappName, dappIcon, connectorIcon, key)
        }

        function onDappConnected(proposal, topic, url, connectorId) {
            const dappDomain = SQUtils.StringUtils.extractDomainFromLink(url)
            const connectorName = connectorId === Constants.DAppConnectors.WalletConnect ? "WalletConnect" : "Status Connector"
            root.displayToastMessage(qsTr("Connected to %1 via %2").arg(dappDomain).arg(connectorName), Constants.ephemeralNotificationType.success)
            root.approveSessionResult(proposal, null, topic)
        }

        function onDappDisconnected(url) {
            const appDomain = SQUtils.StringUtils.extractDomainFromLink(url)
            root.displayToastMessage(qsTr("Disconnected from %1").arg(appDomain), Constants.ephemeralNotificationType.success)
        }

        function onNewConnectionFailed(key, url, error) {
            timeoutTimer.stop()
            const dappDomain = SQUtils.StringUtils.extractDomainFromLink(url)
            if (error === Pairing.errors.userRejected) {
                root.displayToastMessage(qsTr("Connection request for %1 was rejected").arg(dappDomain), Constants.ephemeralNotificationType.success)
            }
            if (error === Pairing.errors.rejectFailed) {
                root.displayToastMessage(qsTr("Failed to reject connection request for %1").arg(dappDomain), Constants.ephemeralNotificationType.danger)
            }
            d.reportPairErrorState(error)
            root.approveSessionResult(key, error, "")
        }

        function onSignCompleted(topic, id, userAccepted, error) {
            const request = root.sessionRequestsModel.findRequest(topic, id)
            if (!request) {
                console.error("Session request not found")
                return
            }

            const methodStr = SessionRequest.methodToUserString(request.method)
            const appUrl = request.dappUrl
            const appDomain = SQUtils.StringUtils.extractDomainFromLink(appUrl)
            if (!methodStr) {
                console.error("Error finding user string for method", request.method)
                return
            }

            if (error) {
                root.displayToastMessage(qsTr("Fail to %1 from %2").arg(methodStr).arg(appDomain), Constants.ephemeralNotificationType.danger)
                return
            }

            const requestExpired = request.isExpired()
            if (requestExpired) {
                root.displayToastMessage("%1 sign request timed out".arg(appDomain), Constants.ephemeralNotificationType.normal)
                return
            }

            const actionStr = userAccepted ? qsTr("accepted") : qsTr("rejected")
            root.displayToastMessage("%1 %2 %3".arg(appDomain).arg(methodStr).arg(actionStr), Constants.ephemeralNotificationType.success)
        }

        function onSiweCompleted(topic, id, userAccepted, error) {
            if (error) {
                root.displayToastMessage(error, Constants.ephemeralNotificationType.danger)
            }
            root.approveSessionResult(id, error, topic)
        }
    }

    // Timeout for the corner case where the URL was already dismissed and the SDK doesn't respond with an error nor advances with the proposal
    Timer {
        id: timeoutTimer

        interval: 10000 // (10 seconds)
        running: false
        repeat: false

        onTriggered: {
            d.reportPairErrorState(Pairing.errors.unknownError)
        }
    }
}
