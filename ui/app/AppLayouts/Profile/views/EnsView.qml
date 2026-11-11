import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme

import QtModelsToolkit

import utils
import shared
import shared.stores as SharedStores

import AppLayouts.Wallet.stores
import AppLayouts.Profile.stores

Item {
    id: ensView

    property EnsUsernamesStore ensUsernamesStore
    property WalletAssetsStore walletAssetsStore

    property SharedStores.NetworkConnectionStore networkConnectionStore

    property int profileContentWidth
    property bool showSearchScreen: false
    property string addedUsername: ""
    property string selectedUsername: ""
    property int selectedChainId: -1

    signal next(output: string)
    signal back()
    signal done(ensUsername: string)
    signal connect(ensUsername: string)
    signal changePubKey(ensUsername: string)
    signal goToWelcome();
    signal goToList();

    signal connectUsernameRequested(string ensName, string ownerAddress)
    signal registerUsernameRequested(string ensName, int chainId)
    signal releaseUsernameRequested(string ensName, string senderAddress, int chainId)

    QtObject {
        id: d

        readonly property string registerENS: "RegisterENS"
        readonly property string setPubKey: "SetPubKey"
        readonly property string releaseENS: "ReleaseENS"

        property string currentState

        // Deferred like a state machine transition: the view emitting the signal is destroyed on enter
        function transition(targetState: string) {
            if (targetState !== "")
                Qt.callLater(d.enter, targetState)
        }

        function enter(targetState: string) {
            d.currentState = targetState
            switch (targetState) {
            case "welcome": loader.sourceComponent = welcome; break
            case "search": loader.sourceComponent = search; break
            case "added":
                loader.sourceComponent = added
                loader.item.ensUsername = ensView.addedUsername
                break
            case "list": loader.sourceComponent = list; break
            case "details": loader.sourceComponent = details; break
            case "tAndC": loader.sourceComponent = termsAndConditions; break
            case "ensRegistered": loader.sourceComponent = ensRegistered; break
            case "ensReleased": loader.sourceComponent = ensReleased; break
            case "ensConnected": loader.sourceComponent = ensConnected; break
            }
        }
    }

    Component.onCompleted: d.enter(ensView.ensUsernamesStore.ensUsernamesModel.count > 0 ? "list" : "welcome")

    onNext: output => {
        switch (d.currentState) {
        case "welcome": d.transition("search"); break
        case "search": d.transition(output === "available" ? "tAndC" : ""); break
        case "list":
            if (output === "search")
                d.transition("search")
            else if (output === "details")
                d.transition("details")
            break
        case "added":
        case "ensRegistered":
        case "ensReleased":
        case "ensConnected":
            d.transition("list")
            break
        }
    }

    onBack: {
        if (["search", "details", "tAndC"].includes(d.currentState))
            d.transition("list")
    }

    onDone: {
        switch (d.currentState) {
        case "search": d.transition("ensConnected"); break
        case "details": d.transition("ensReleased"); break
        case "tAndC": d.transition("ensRegistered"); break
        }
    }

    onGoToList: {
        if (["welcome", "search", "added", "list", "details", "tAndC"].includes(d.currentState))
            d.transition("list")
    }

    onGoToWelcome: {
        if (["search", "added", "list", "details", "tAndC"].includes(d.currentState))
            d.transition("welcome")
    }

    Loader {
        id: loader
        anchors.fill: parent
    }

    Component {
        id: welcome
        EnsWelcomeView {
            username: ensView.ensUsernamesStore.username
            onStartBtnClicked: next(null)
            profileContentWidth: ensView.profileContentWidth
            startButtonEnabled: ensView.networkConnectionStore.ensNetworkAvailable
            tooltipText: ensView.networkConnectionStore.ensNetworkUnavailableText
        }
    }

    Component {
        id: search
        EnsSearchView {
            ensUsernamesStore: ensView.ensUsernamesStore
            profileContentWidth: ensView.profileContentWidth

            onBackBtnClicked: back()

            onContinueClicked: (output, username) => {
                if(output === "connected"){
                    connect(username)
                } else {
                    selectedUsername = username;
                    next(output);
                }
            }

            onConnectUsername: (username, ownerAddress) => {
                ensView.selectedUsername = username
                ensView.connectUsernameRequested(ensView.selectedUsername, ownerAddress)
            }

            Connections {
                target: ensView.ensUsernamesStore.ensUsernamesModule
                function onTransactionWasSent(trxType: string, chainId: int, txHash: string, username: string, error: string) {
                    if (!!error || trxType !== d.setPubKey) {
                        return
                    }
                    done(ensView.selectedUsername)
                }
            }
        }
    }

    Component {
        id: termsAndConditions
        EnsTermsAndConditionsView {
            username: selectedUsername

            registrarAddress: ensView.ensUsernamesStore.ensRegisteredAddress
            ensRegistryAddress: ensView.ensUsernamesStore.getEnsRegistry()
            etherscanAddressLink: ensView.ensUsernamesStore.getEtherscanAddressLink()

            walletAddress: ensView.ensUsernamesStore.getWalletDefaultAddress()
            pubkey: ensView.ensUsernamesStore.pubkey

            sntBalance: {
                const token = statusTokenEntry.item
                if (!token || !token.decimals)
                    return 0
                return sntAggregator.value / (10 ** token.decimals)
            }

            onBackBtnClicked: back()

            onRegisterUsername: {
                const chainId = ensView.ensUsernamesStore.getChainForBuyingEnsName()

                ensView.registerUsernameRequested(ensView.selectedUsername, chainId)
            }

            Connections {
                target: ensView.ensUsernamesStore.ensUsernamesModule
                function onTransactionWasSent(trxType: string, chainId: int, txHash: string, username: string, error: string) {
                    if (!!error || trxType !== d.registerENS) {
                        return
                    }
                    done(ensView.selectedUsername)
                }
            }

            ModelEntry {
                id: statusTokenEntry
                sourceModel: ensView.walletAssetsStore.groupedAccountAssetsModel
                key: "key"
                value: ensView.ensUsernamesStore.getStatusTokenGroupKey()
            }

            SumAggregator {
                id: sntAggregator
                model: {
                    const token = statusTokenEntry.item
                    return !!token && !!token.balances ? token.balances : null
                }
                roleName: "balance"
            }
        }
    }

    Component {
        id: added
        EnsAddedView {
            onOkBtnClicked: next(null)
        }
    }

    Component {
        id: ensRegistered
        EnsRegisteredView {
            ensUsername: selectedUsername
            onOkBtnClicked: next(null)
        }
    }

    Component {
        id: ensReleased
        EnsReleasedView {
            ensUsername: selectedUsername
            onOkBtnClicked: next(null)
        }
    }

    Component {
        id: ensConnected
        EnsConnectedView {
            ensUsername: selectedUsername
            onOkBtnClicked: next(null)
        }
    }

    Component {
        id: list
        EnsListView {
            profileContentWidth: ensView.profileContentWidth

            model: ensView.ensUsernamesStore.currentChainEnsUsernamesModel
            preferredUsername: ensView.ensUsernamesStore.preferredUsername
            pubkey: ensView.ensUsernamesStore.pubkey
            icon: ensView.ensUsernamesStore.icon
            hasConfirmedEnsUsernames: ensView.ensUsernamesStore.ensUsernamesModel.count > 0
                                      || ensView.ensUsernamesStore.numOfPendingEnsUsernames() > 0

            onAddBtnClicked: next("search")
            onSelectEns: (username, chainId) => {


                selectedUsername = username
                selectedChainId = chainId
                next("details")

                ensView.ensUsernamesStore.ensDetails(chainId, username)
            }
            onPreferredUsernameSelected: (ensUsername) => ensView.ensUsernamesStore.setPrefferedEnsUsername(ensUsername)
        }
    }

    Component {
        id: details
        EnsDetailsView {
            id: ensDetailsView

            username: selectedUsername
            onBackBtnClicked: back()

            onReleaseUsernameRequested: (senderAddress) => {
                const name = RootStore.getNameForWalletAddress(senderAddress)
                if (name === "") {
                    Global.openPopup(noAccountPopupComponent)
                    return
                }
                ensView.releaseUsernameRequested(ensView.selectedUsername, senderAddress,
                                                 ensView.selectedChainId)
            }

            onRemoveEnsUsernameRequested: (chainId, username) => {
                ensView.ensUsernamesStore.removeEnsUsername(chainId, username)
                back()
            }

            Connections {
                target: ensView.ensUsernamesStore.ensUsernamesModule

                function onTransactionWasSent(trxType: string, chainId: int, txHash: string, username: string, error: string) {
                    if (!!error || trxType !== d.releaseENS) {
                        return
                    }
                    done(ensView.selectedUsername)
                }

                function onDetailsObtained(chainId: int, ensName: string, address: string, pubkey: string, isStatus: bool, expirationTime: int) {
                    if(username !== (isStatus ? ensName + ".stateofus.eth" : ensName))
                        return

                    ensDetailsView.setDetails(chainId, ensName, address, pubkey, isStatus, expirationTime,
                                             ensView.ensUsernamesStore.preferredUsername === username)
                }

                function onLoading(isLoading: bool) {
                    ensDetailsView.isLoading = isLoading
                }
            }
        }
    }

    Component {
        id: noAccountPopupComponent
        StatusDialog {
            title: qsTr("Release username")

            StatusBaseText {
                anchors.fill: parent
                text: qsTr("The account this username was bought with is no longer among active accounts.\nPlease add it and try again.")
                wrapMode: Text.Wrap
            }

            standardButtons: Dialog.Ok
        }
    }

    onConnect: ensUsername => {
        ensView.addedUsername = ensUsername
        if (d.currentState === "search")
            d.transition("added")
    }
}
