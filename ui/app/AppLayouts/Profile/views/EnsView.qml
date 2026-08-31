import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.StateMachine as DSM

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme

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
    }

    DSM.StateMachine {
        id: stateMachine
        initialState: ensView.ensUsernamesStore.ensUsernamesModel.count > 0 ? listState : welcomeState
        running: true

        DSM.State {
            id: welcomeState
            onEntered: loader.sourceComponent = welcome

            DSM.SignalTransition {
                targetState: searchState
                signal: next
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
        }

        DSM.State {
            id: searchState
            onEntered: loader.sourceComponent = search
            DSM.SignalTransition {
                targetState: tAndCState
                signal: next
                guard: output === "available"
            }
            DSM.SignalTransition {
                targetState: addedState
                signal: connect
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
            DSM.SignalTransition {
                targetState: ensConnectedState
                signal: done
            }
            DSM.SignalTransition {
                targetState: listState
                signal: back
            }
        }

        DSM.State {
            id: addedState
            onEntered: {
                loader.sourceComponent = added;
                loader.item.ensUsername = addedUsername;
            }
            DSM.SignalTransition {
                targetState: listState
                signal: next
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
        }

        DSM.State {
            id: listState
            onEntered: {
                loader.sourceComponent = list;
            }
            DSM.SignalTransition {
                targetState: searchState
                signal: next
                guard: output === "search"
            }
            DSM.SignalTransition {
                targetState: detailsState
                signal: next
                guard: output === "details"
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
        }

        DSM.State {
            id: detailsState
            onEntered: {
                loader.sourceComponent = details;
            }
            DSM.SignalTransition {
                targetState: listState
                signal: back
            }
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
            DSM.SignalTransition {
                targetState: ensReleasedState
                signal: done
            }
        }

        DSM.State {
            id: tAndCState
            onEntered:loader.sourceComponent = termsAndConditions
            DSM.SignalTransition {
                targetState: listState
                signal: goToList
            }
            DSM.SignalTransition {
                targetState: welcomeState
                signal: goToWelcome
            }
            DSM.SignalTransition {
                targetState: listState
                signal: back
            }
            DSM.SignalTransition {
                targetState: listState
                signal: back
            }
            DSM.SignalTransition {
                targetState: ensRegisteredState
                signal: done
            }
        }

        DSM.State {
            id: ensRegisteredState
            onEntered:loader.sourceComponent = ensRegistered
            DSM.SignalTransition {
                targetState: listState
                signal: next
            }
        }

        DSM.State {
            id: ensReleasedState
            onEntered:loader.sourceComponent = ensReleased
            DSM.SignalTransition {
                targetState: listState
                signal: next
            }
        }

        DSM.State {
            id: ensConnectedState
            onEntered:loader.sourceComponent = ensConnected
            DSM.SignalTransition {
                targetState: listState
                signal: next
            }
        }
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
            ensUsernamesStore: ensView.ensUsernamesStore
            username: selectedUsername
            assetsModel: ensView.walletAssetsStore.groupedAccountAssetsModel

            onBackBtnClicked: back()

            onRegisterUsername: {
                const chainId = root.ensUsernamesStore.getChainForBuyingEnsName()

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
                ensView.ensUsernamesStore.ensDetails(chainId, username)
                selectedUsername = username
                selectedChainId = chainId
                next("details")
            }
            onPreferredUsernameSelected: (ensUsername) => ensView.ensUsernamesStore.setPrefferedEnsUsername(ensUsername)
        }
    }

    Component {
        id: details
        EnsDetailsView {
            ensUsernamesStore: ensView.ensUsernamesStore
            username: selectedUsername
            chainId: selectedChainId

            onBackBtnClicked: back()

            onReleaseUsernameRequested: (senderAddress) => {
                const name = RootStore.getNameForWalletAddress(senderAddress)
                if (name === "") {
                    Global.openPopup(noAccountPopupComponent)
                    return
                }
                ensView.releaseUsernameRequested(ensView.selectedUsername, senderAddress, ensView.selectedChainId)
            }

            Connections {
                target: ensView.ensUsernamesStore.ensUsernamesModule
                function onTransactionWasSent(trxType: string, chainId: int, txHash: string, username: string, error: string) {
                    if (!!error || trxType !== d.releaseENS) {
                        return
                    }
                    done(ensView.selectedUsername)
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
            }

            standardButtons: Dialog.Ok
        }
    }

    Connections {
        target: ensView
        function onConnect(ensUsername: string) {
            addedUsername = ensUsername;
        }
    }
}
